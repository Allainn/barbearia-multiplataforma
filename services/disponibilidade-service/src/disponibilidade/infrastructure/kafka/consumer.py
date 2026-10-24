import json
import logging
import os
import threading
import time

from opentelemetry import trace
from opentelemetry.propagate import extract
from sqlalchemy.exc import OperationalError
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)
_tracer = trace.get_tracer("disponibilidade-service.kafka")

GROUP_ID = "disponibilidade-service"
TOPICS = ["agendamento.criado", "agendamento.cancelado"]


@retry(
    retry=retry_if_exception_type(OperationalError),
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=4),
    reraise=True,
)
def _aplicar_com_retry(handler, evento: dict) -> None:
    """
    Retry só em OperationalError (conexão Postgres morta/indisponível) -- o
    pool_pre_ping do engine já resolve a maioria dos casos sozinho, isso cobre
    o Postgres ainda estar de pé subindo no exato momento em que a mensagem
    chega (ex: docker compose recém recriou o container). Se mesmo assim
    falhar, o laço em _consume não commita e volta o offset para reler a
    mensagem -- o commit é manual, só depois de aplicar o evento.
    """
    handler(evento)


def _consume(bootstrap_servers: str, handlers: dict) -> None:
    from kafka import KafkaConsumer, TopicPartition  # type: ignore[import-untyped]
    from kafka.errors import KafkaError  # type: ignore[import-untyped]

    # Sem value_deserializer: um JSON inválido lançaria a exceção dentro do
    # iterador e derrubaria a thread. O parse fica dentro do try abaixo.
    # O compose só sobe o serviço depois do kafka-init, mas num restart com o
    # Kafka fora o construtor falha e a thread morreria calada, com o /health
    # ainda ok. Por isso o laço. KafkaError cobre o NoBrokersAvailable do
    # kafka-python 2.x e o KafkaTimeoutError (depois de 30 s) do 3.x.
    while True:
        try:
            consumer = KafkaConsumer(
                *TOPICS,
                bootstrap_servers=bootstrap_servers,
                group_id=GROUP_ID,
                auto_offset_reset="earliest",
                # O auto-commit grava o offset a cada 5 s sem esperar o
                # processamento; o commit fica no fim do laço abaixo.
                enable_auto_commit=False,
            )
            break
        except KafkaError:
            logger.warning("Kafka indisponível em %s; nova tentativa em 5 s", bootstrap_servers)
            time.sleep(5)
    logger.info(
        "Kafka consumer started. Listening on topics %s at %s",
        TOPICS,
        bootstrap_servers,
    )

    for message in consumer:
        # Extrai W3C trace context dos headers para ligar ao trace do producer
        headers_dict = {k: v.decode("utf-8") for k, v in (message.headers or [])}
        ctx = extract(headers_dict)

        with _tracer.start_as_current_span(
            f"kafka consume {message.topic}",
            context=ctx,
            kind=trace.SpanKind.CONSUMER,
            attributes={
                "messaging.system": "kafka",
                "messaging.destination": message.topic,
                "messaging.destination_kind": "topic",
                "messaging.operation": "receive",
                "messaging.kafka.consumer_group": GROUP_ID,
                "messaging.kafka.partition": message.partition,
                "messaging.kafka.offset": message.offset,
            },
        ):
            try:
                evento = json.loads(message.value.decode("utf-8"))
                _aplicar_com_retry(handlers[message.topic], evento)
                logger.info(
                    "Evento %s (%s) aplicado ao read model",
                    evento.get("evento_id"),
                    message.topic,
                )
            except OperationalError:
                # Postgres fora mesmo depois dos retries: não commita e volta
                # o offset para ler esta mensagem de novo. O laço continua
                # chamando o poll, então o consumer não sai do grupo.
                logger.exception(
                    "Postgres indisponível; %s[%d]@%d será reprocessada em 5 s",
                    message.topic,
                    message.partition,
                    message.offset,
                )
                try:
                    consumer.seek(TopicPartition(message.topic, message.partition), message.offset)
                except ValueError:
                    # A partição saiu deste consumer num rebalance; quem a
                    # recebeu relê a partir do último commit.
                    logger.warning("Partição %s[%d] não é mais deste consumer", message.topic, message.partition)
                time.sleep(5)
                continue
            except Exception:
                # JSON inválido ou campo faltando: tentar de novo não resolve.
                # Sem DLQ (ADR-0006), a mensagem é logada e descartada.
                logger.exception(
                    "Error processing Kafka message from topic %s: %s",
                    message.topic,
                    message.value,
                )
            try:
                consumer.commit()
            except KafkaError:
                # Rebalance no meio do caminho: o offset não commitado volta a
                # ser lido, e aplicar o mesmo evento de novo não muda nada.
                logger.warning("Commit do offset falhou; a mensagem pode ser relida", exc_info=True)


def start_event_consumer(handlers: dict) -> None:
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "")
    if not bootstrap_servers:
        logger.info(
            "KAFKA_BOOTSTRAP_SERVERS not set — Kafka consumer will not start."
        )
        return

    thread = threading.Thread(
        target=_consume,
        args=(bootstrap_servers, handlers),
        daemon=True,
        name="kafka-consumer-disponibilidade",
    )
    thread.start()
    logger.info("Kafka consumer thread started.")
