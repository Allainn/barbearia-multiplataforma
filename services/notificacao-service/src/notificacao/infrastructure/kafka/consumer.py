import json
import logging
import os
import threading

from opentelemetry import trace
from opentelemetry.propagate import extract
from sqlalchemy.exc import OperationalError
from tenacity import retry, retry_if_exception_type, stop_after_attempt, wait_exponential

logger = logging.getLogger(__name__)
_tracer = trace.get_tracer("notificacao-service.kafka")

GROUP_ID = "notificacao-service"
TOPICS = ["agendamento.criado", "agendamento.cancelado"]


@retry(
    retry=retry_if_exception_type(OperationalError),
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=4),
    reraise=True,
)
def _notify_with_retry(notifier, tipo: str, evento: dict) -> None:
    """
    Retry só em OperationalError (conexão Postgres morta/indisponível) -- o
    pool_pre_ping do engine já resolve a maioria dos casos sozinho, isso cobre
    o Postgres ainda estar de pé subindo no exato momento em que a mensagem
    chega (ex: docker compose recém recriou o container). Sem isso, a exceção
    cai no except mais abaixo, a mensagem é só logada e perdida -- o commit
    de offset do kafka-python é automático (a cada 5s), não espera sucesso.
    """
    notifier.notify(tipo=tipo, evento=evento)


def _consume(bootstrap_servers: str, notifier) -> None:
    from kafka import KafkaConsumer  # type: ignore[import-untyped]

    # Sem value_deserializer: um JSON inválido lançaria a exceção dentro do
    # iterador e derrubaria a thread. O parse fica dentro do try abaixo.
    consumer = KafkaConsumer(
        *TOPICS,
        bootstrap_servers=bootstrap_servers,
        group_id=GROUP_ID,
        auto_offset_reset="earliest",
    )
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
                _notify_with_retry(notifier, tipo=message.topic, evento=evento)
            except Exception:
                logger.exception(
                    "Error processing Kafka message from topic %s: %s",
                    message.topic,
                    message.value,
                )


def start_event_consumer(notifier) -> None:
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "")
    if not bootstrap_servers:
        logger.info(
            "KAFKA_BOOTSTRAP_SERVERS not set — Kafka consumer will not start."
        )
        return

    thread = threading.Thread(
        target=_consume,
        args=(bootstrap_servers, notifier),
        daemon=True,
        name="kafka-consumer-notificacao",
    )
    thread.start()
    logger.info("Kafka consumer thread started.")
