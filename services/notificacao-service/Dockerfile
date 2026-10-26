FROM python:3.12-slim AS base
WORKDIR /app

FROM base AS deps
COPY pyproject.toml .
RUN mkdir -p src && pip install --no-cache-dir -e .

FROM deps AS final
# Não rodar como root (Aula 4). O serviço só lê os arquivos da imagem. O
# useradd vem antes do COPY para a camada não ser refeita a cada mudança no código.
RUN useradd --create-home app
COPY src/ src/
ENV PYTHONPATH=/app/src
USER app
EXPOSE 8004
CMD ["uvicorn", "notificacao.main:app", "--host", "0.0.0.0", "--port", "8004"]
