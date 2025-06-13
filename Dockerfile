FROM python:3.8-slim

WORKDIR /app

COPY resources/web /app
COPY models /app/models

RUN pip install --no-cache-dir flask kafka-python pymongo iso8601 pyelasticsearch joblib

EXPOSE 5001

CMD ["python", "predict_flask.py"]
