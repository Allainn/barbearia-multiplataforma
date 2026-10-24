FROM python:3.12-slim

WORKDIR /app
COPY pyproject.toml .
COPY src ./src
RUN pip install --no-cache-dir .

RUN useradd --create-home app
USER app

EXPOSE 8001
CMD ["uvicorn", "barbearia.main:app", "--host", "0.0.0.0", "--port", "8001"]
