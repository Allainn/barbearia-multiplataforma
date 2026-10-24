FROM python:3.12-slim

RUN useradd --system app

WORKDIR /app
COPY pyproject.toml .
# Camada das dependencias: so e refeita quando o pyproject.toml muda.
RUN mkdir -p src/barbearia && touch src/barbearia/__init__.py \
    && pip install --no-cache-dir .
COPY src ./src
RUN pip install --no-cache-dir --no-deps --force-reinstall .

USER app

EXPOSE 8001
CMD ["uvicorn", "barbearia.main:app", "--host", "0.0.0.0", "--port", "8001"]
