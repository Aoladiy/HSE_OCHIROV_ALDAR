FROM python:3.12-slim

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .
COPY tests/ ./tests/

ENV PYTHONIOENCODING=utf-8
ENV PYTHONUNBUFFERED=1

CMD ["python", "client.py"]
