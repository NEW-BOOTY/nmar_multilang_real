#!/usr/bin/env bash
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
set -Eeuo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
export $(grep -v '^#' "$DIR/.nmar_local.env" | xargs)

echo "Bringing up mock infra (postgres + mock model server)"
docker-compose -f "$DIR/docker-compose.mock.yml" up -d --build

echo "Waiting for postgres to be healthy..."
for i in {1..30}; do
  pg_isready -h localhost -p ${POSTGRES_PORT} -U ${POSTGRES_USER} >/dev/null 2>&1 && break
  echo "waiting for postgres..."
  sleep 1
done

echo "Running small Python client that calls mock model server and writes to Postgres"
python3 - <<'PY'
import os, requests, time, psycopg2, json
from time import sleep
env = {}
with open(os.path.join(os.path.dirname(__file__), "../.nmar_local.env")) as f:
    for l in f:
        if "=" in l and not l.strip().startswith("#"):
            k,v = l.strip().split("=",1); env[k]=v

server = "http://localhost:8080/infer"
payload = {"modality":"text","payload":{"input":[0.1,0.2,0.3], "meta": "local"}}
r = requests.post(server, json=payload, timeout=10)
print("model-server status:", r.status_code, "embedding length:", len(r.json().get("embedding",[])))
emb = r.json().get("embedding", [0.0]*128)
# connect to postgres and insert vector
pg_user = env["POSTGRES_USER"]
pg_pass = env["POSTGRES_PASSWORD"]
pg_db = env["POSTGRES_DB"]
pg_port = int(env["POSTGRES_PORT"])
import psycopg2
conn = psycopg2.connect(host="localhost", port=pg_port, dbname=pg_db, user=pg_user, password=pg_pass)
cur = conn.cursor()
cur.execute("INSERT INTO memory_anchors (key, payload, relevance, embedding) VALUES (%s,%s,%s,%s::vector) RETURNING id",
            ("e2e:key","e2e payload", 0.9, '['+','.join(map(str, emb))+']'))
row = cur.fetchone()
conn.commit()
print("Inserted memory id:", row[0])
cur.close()
conn.close()
PY

echo "E2E done. To tear down run: docker-compose -f $DIR/docker-compose.mock.yml down -v"
