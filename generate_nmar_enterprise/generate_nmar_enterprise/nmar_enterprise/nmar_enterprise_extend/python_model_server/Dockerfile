# Copyright © 2025 Devin B. Royal. All Rights Reserved.
FROM python:3.11-slim

ENV NMAR_MODEL_PATH=/models/model.pt
ENV NMAR_MODEL_TYPE=torch

RUN apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY src /app/src
COPY models /models

EXPOSE 8080
CMD ["uvicorn", "src.server:app", "--host", "0.0.0.0", "--port", "8080"]
