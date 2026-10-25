# Imagem da aplicação Notas da Nuvem.

FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY templates/ templates/

ENV PYTHONUNBUFFERED=1 \
    APP_PORT=8080

EXPOSE 8080

# Um worker só: a tarefa Fargate desta atividade usa pouca memória.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--timeout", "120", "app:app"]
