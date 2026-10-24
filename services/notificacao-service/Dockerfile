FROM python:3.12-slim AS base
WORKDIR /app

FROM base AS deps
COPY pyproject.toml .
RUN mkdir -p src && pip install --no-cache-dir -e .

FROM deps AS final
COPY src/ src/
ENV PYTHONPATH=/app/src
EXPOSE 8004
CMD ["uvicorn", "notificacao.main:app", "--host", "0.0.0.0", "--port", "8004"]
