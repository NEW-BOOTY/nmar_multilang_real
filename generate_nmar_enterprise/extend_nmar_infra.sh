#!/usr/bin/env bash
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
# extend_nmar_infra.sh
#
# Purpose: Extend an existing NMAR enterprise skeleton with:
#  - Triton/ONNX/TorchServe adapter scaffolds (gRPC + REST)
#  - .proto files and client/server skeletons
#  - Helm chart scaffolding for production deployment
#  - PostgreSQL + pgvector migrations and Java DAO persistence (MemoryAnchors -> vector DB)
#  - Mock local infra via docker-compose (simulated Triton/TorchServe/ONNX endpoints)
#  - Randomized local credentials and API keys (safe to run locally)
#
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="${ROOT:-$(pwd)}"
EXT_DIR="$ROOT/nmar_enterprise_extend"
JAVA_DIR="$ROOT/java_nmar"
PY_DIR="$ROOT/python_model_server"
INFRA_DIR="$EXT_DIR/infra"
PROTO_DIR="$EXT_DIR/proto"
DB_DIR="$EXT_DIR/db"
HELM_DIR="$INFRA_DIR/helm/nmar"
COMPOSE_FILE="$EXT_DIR/docker-compose.mock.yml"
ENV_FILE="$EXT_DIR/.nmar_local.env"

mkdir -p "$EXT_DIR" "$INFRA_DIR" "$PROTO_DIR" "$DB_DIR" "$HELM_DIR" "$EXT_DIR/scripts"

echo "Extending NMAR repo under: $EXT_DIR"

# generate randomized local credentials and API keys (safe random, local only)
RANDOM_SECRET() { openssl rand -hex 16 2>/dev/null || head -c16 /dev/urandom | od -An -t x1 | tr -d ' \n'; }
POSTGRES_PASSWORD="$(RANDOM_SECRET)"
POSTGRES_USER="nmar_user"
POSTGRES_DB="nmar_db"
POSTGRES_PORT=54321
PGVECTOR_IMAGE="ankane/pgvector:pg15" # placeholder image with pgvector extension
MODEL_SERVER_API_KEY="$(RANDOM_SECRET)"
TRITON_MOCK_PORT=8001
TORCHSERVE_MOCK_PORT=8081
ONNX_MOCK_PORT=8082
GRPC_PORT=50051
HELM_APP_NAME="nmar"

cat > "$ENV_FILE" <<EOF
# Local NMAR environment (randomized; safe to commit for local use)
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB
POSTGRES_PORT=$POSTGRES_PORT
PGVECTOR_IMAGE=$PGVECTOR_IMAGE
MODEL_SERVER_API_KEY=$MODEL_SERVER_API_KEY
TRITON_MOCK_PORT=$TRITON_MOCK_PORT
TORCHSERVE_MOCK_PORT=$TORCHSERVE_MOCK_PORT
ONNX_MOCK_PORT=$ONNX_MOCK_PORT
GRPC_PORT=$GRPC_PORT
EOF

# ---------------------------
# 1) Protobuf (gRPC) definition
# ---------------------------
cat > "$PROTO_DIR/nmar_model_service.proto" <<'PROTO'
/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
syntax = "proto3";

package nmar.model;

option java_package = "com.devin.nmar.grpc";
option java_outer_classname = "NmarModelProto";

message EmbeddingRequest {
  string modality = 1;
  repeated float input = 2;
  string api_key = 3;
}

message EmbeddingResponse {
  repeated float embedding = 1;
  string message = 2;
}

service ModelService {
  rpc GetEmbedding(EmbeddingRequest) returns (EmbeddingResponse);
}
PROTO

# ---------------
# 2) Java gRPC client skeleton (placeholder for protoc generated stubs)
# ---------------
mkdir -p "$JAVA_DIR/src/main/java/com/devin/nmar/grpc"

cat > "$JAVA_DIR/src/main/java/com/devin/nmar/grpc/ModelServiceGrpcClient.java" <<'JAVA_GRPC_CLIENT'
/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar.grpc;

import java.util.ArrayList;
import java.util.List;
import java.util.logging.Logger;

/**
 * ModelServiceGrpcClient - a lightweight gRPC client wrapper skeleton.
 * NOTE: This file is a hand-written skeleton to allow compilation and local testing
 * without protoc. For real deployment, generate stubs using protoc and replace this.
 */
public class ModelServiceGrpcClient {
    private static final Logger LOG = Logger.getLogger(ModelServiceGrpcClient.class.getName());
    private final String host;
    private final int port;
    private final String apiKey;

    public ModelServiceGrpcClient(String host, int port, String apiKey) {
        this.host = host;
        this.port = port;
        this.apiKey = apiKey;
    }

    /**
     * Simulated gRPC call to model server. In production, replace with actual gRPC stub invocation.
     */
    public List<Float> getEmbedding(String modality, float[] input) {
        try {
            // Simulate network call latency
            Thread.sleep(30);
            // Simple deterministic embedding: hash-based pseudo-random vector (safe simulation)
            List<Float> embed = new ArrayList<>();
            int dim = 128;
            int seed = java.util.Arrays.hashCode(input) ^ modality.hashCode() ^ apiKey.hashCode();
            java.util.Random r = new java.util.Random(seed);
            for (int i = 0; i < dim; i++) {
                embed.add((float)(r.nextGaussian() * 0.5));
            }
            return embed;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new RuntimeException("Interrupted", e);
        } catch (Exception ex) {
            LOG.warning("getEmbedding simulation failed: " + ex.getMessage());
            return new ArrayList<>();
        }
    }
}
JAVA_GRPC_CLIENT

# -----------------------
# 3) Python mock gRPC server (for local simulation)
# -----------------------
mkdir -p "$PY_DIR/mock"
cat > "$PY_DIR/mock/mock_grpc_server.py" <<'PY_GRPC_SERVER'
"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
Mock gRPC server for ModelService (simulated). Standing in for Triton/TorchServe for local tests.
This uses pure HTTP as an accessible simulation so users don't need to compile protos.
"""
import os
import time
import random
from flask import Flask, request, jsonify

app = Flask("mock_grpc")

API_KEY = os.environ.get("MODEL_SERVER_API_KEY", "local_dummy_key")

@app.route("/v1/get_embedding", methods=["POST"])
def get_embedding():
    data = request.json or {}
    api_key = data.get("api_key")
    if api_key != API_KEY:
        return jsonify({"error":"unauthorized"}), 401
    modality = data.get("modality","text")
    input_vals = data.get("input", [0.0])
    # deterministic pseudo-embedding
    seed = int(sum([float(x) for x in input_vals]) * 1000) ^ hash(modality)
    r = random.Random(seed)
    emb = [r.gauss(0,0.5) for _ in range(128)]
    time.sleep(0.03)
    return jsonify({"embedding": emb, "message":"simulated embed"}), 200

if __name__ == "__main__":
    port = int(os.environ.get("TRITON_MOCK_PORT", "8001"))
    app.run(host="0.0.0.0", port=port)
PY_GRPC_SERVER

# -----------------------
# 4) Triton/ONNX/TorchServe adapter scaffolds (Python)
# -----------------------
mkdir -p "$PY_DIR/adapters"
cat > "$PY_DIR/adapters/triton_adapter.py" <<'PY_TRITON'
"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
Triton adapter scaffold: demonstrates how to call Triton Inference Server (HTTP/gRPC).
This file contains example implementation details but uses a local simulated endpoint if no Triton server is available.
"""
import os, logging, requests, json

LOG = logging.getLogger("triton_adapter")

TRITON_URL = os.environ.get("TRITON_URL", f"http://localhost:{os.environ.get('TRITON_MOCK_PORT',8001)}")

def get_embedding_from_triton(modality, input_vector, model_name="nmar_model"):
    """
    Example HTTP POST to Triton model endpoint; in local tests this will hit the mock server.
    Triton HTTP API differs; adapt input formatting accordingly.
    """
    url = TRITON_URL.rstrip("/") + "/v1/models/" + model_name + "/infer"
    payload = {
        "inputs": [{"name":"INPUT__0", "shape":[1,len(input_vector)], "datatype":"FP32", "data":[input_vector]}],
        "parameters": {}
    }
    try:
        r = requests.post(url, json=payload, timeout=5)
        if r.status_code != 200:
            LOG.warning("Triton call failed status=%s body=%s", r.status_code, r.text)
            return None
        # parse and return embedding (placeholder parsing)
        j = r.json()
        # adapt to Triton's actual output format
        return j.get("outputs", [{}])[0].get("data", [])[0]
    except Exception as e:
        LOG.exception("Triton call exception")
        return None
PY_TRITON

cat > "$PY_DIR/adapters/torchserve_adapter.py" <<'PY_TORCHSERVE'
"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
TorchServe adapter scaffold (REST). In local mode, calls a mock endpoint.
"""
import os, logging, requests

LOG = logging.getLogger("torchserve_adapter")
TORCHSERVE_URL = os.environ.get("TORCHSERVE_URL", f"http://localhost:{os.environ.get('TORCHSERVE_MOCK_PORT',8081)}")

def get_embedding_from_torchserve(modality, input_vector, model_name="nmar_model"):
    url = TORCHSERVE_URL.rstrip("/") + f"/models/{model_name}/predict"
    try:
        r = requests.post(url, json={"data": [input_vector]}, timeout=5)
        if r.status_code != 200:
            LOG.warning("TorchServe call failed status=%s", r.status_code)
            return None
        j = r.json()
        return j.get("data", [None])[0]
    except Exception:
        LOG.exception("TorchServe call exception")
        return None
PY_TORCHSERVE

cat > "$PY_DIR/adapters/onnx_adapter.py" <<'PY_ONNX'
"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
ONNX adapter scaffold (ONNX Runtime). For local tests it will call the mock server.
"""
import os, logging, requests

LOG = logging.getLogger("onnx_adapter")
ONNX_URL = os.environ.get("ONNX_URL", f"http://localhost:{os.environ.get('ONNX_MOCK_PORT',8082)}")

def get_embedding_from_onnx(modality, input_vector, model_name="nmar_model"):
    # Placeholder for actual onnxruntime inference; here we proxy to mock.
    try:
        r = requests.post(ONNX_URL.rstrip("/") + "/v1/infer", json={"modality": modality, "input": input_vector}, timeout=5)
        if r.status_code != 200:
            LOG.warning("ONNX mock call failed")
            return None
        return r.json().get("embedding")
    except Exception:
        LOG.exception("ONNX call exception")
        return None
PY_ONNX

# -----------------------
# 5) Postgres + pgvector migration SQL and JDBC DAO Java
# -----------------------
mkdir -p "$DB_DIR/migrations"
cat > "$DB_DIR/migrations/V1__init_pgvector.sql" <<SQL
-- Copyright © 2025 Devin B. Royal. All Rights Reserved.
-- Flyway-style migration: create db, extension and memory table with pgvector
CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS memory_anchors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL,
  payload text NOT NULL,
  relevance double precision NOT NULL,
  embedding vector(1536),
  created_at timestamptz DEFAULT now(),
  access_count int DEFAULT 0
);
-- index for vector similarity (adjust using ivfflat or hnsw in production)
CREATE INDEX IF NOT EXISTS idx_memory_embedding ON memory_anchors USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
SQL

# DAO Java class for vector persistence
mkdir -p "$JAVA_DIR/src/main/java/com/devin/nmar/persistence"
cat > "$JAVA_DIR/src/main/java/com/devin/nmar/persistence/MemoryDAO.java" <<'JAVA_DAO'
/*
Copyright © 2025 Devin B. Royal. All Rights Reserved.
*/
package com.devin.nmar.persistence;

import java.sql.*;
import java.util.*;
import java.util.logging.Logger;

/**
 * MemoryDAO - persistence layer for MemoryAnchors using PostgreSQL + pgvector.
 * NOTE: This class is a functional JDBC implementation. It expects the pgvector extension
 * and table created by migrations.
 */
public class MemoryDAO {
    private static final Logger LOG = Logger.getLogger(MemoryDAO.class.getName());
    private final String jdbcUrl;
    private final String user;
    private final String pass;

    public MemoryDAO(String jdbcUrl, String user, String pass) {
        this.jdbcUrl = jdbcUrl;
        this.user = user;
        this.pass = pass;
    }

    private Connection conn() throws SQLException {
        return DriverManager.getConnection(jdbcUrl, user, pass);
    }

    public UUID saveMemory(String key, String payload, double relevance, float[] embedding) {
        String sql = "INSERT INTO memory_anchors (key, payload, relevance, embedding) VALUES (?, ?, ?, ?::vector) RETURNING id";
        try (Connection c = conn(); PreparedStatement p = c.prepareStatement(sql)) {
            p.setString(1, key);
            p.setString(2, payload);
            p.setDouble(3, relevance);
            // array -> string format for pgvector: '[v1,v2,...]'
            String vec = arrayToPgVector(embedding);
            p.setString(4, vec);
            try (ResultSet rs = p.executeQuery()) {
                if (rs.next()) return UUID.fromString(rs.getString(1));
            }
        } catch (SQLException e) {
            LOG.severe("saveMemory failed: " + e.getMessage());
            throw new RuntimeException(e);
        }
        return null;
    }

    public List<Map<String,Object>> nearestNeighbors(float[] embedding, int k) {
        List<Map<String,Object>> out = new ArrayList<>();
        String sql = "SELECT id, key, payload, relevance, 1 - (embedding <#> ?::vector) AS similarity FROM memory_anchors ORDER BY embedding <#> ?::vector LIMIT ?";
        // NOTE: '<#>' is pgvector operator for cosine distance; adjust for your pgvector version
        try (Connection c = conn(); PreparedStatement p = c.prepareStatement(sql)) {
            String vec = arrayToPgVector(embedding);
            p.setString(1, vec);
            p.setString(2, vec);
            p.setInt(3, k);
            try (ResultSet rs = p.executeQuery()) {
                while (rs.next()) {
                    Map<String,Object> m = new HashMap<>();
                    m.put("id", rs.getString("id"));
                    m.put("key", rs.getString("key"));
                    m.put("payload", rs.getString("payload"));
                    m.put("relevance", rs.getDouble("relevance"));
                    m.put("similarity", rs.getDouble("similarity"));
                    out.add(m);
                }
            }
        } catch (SQLException e) {
            LOG.severe("nearestNeighbors failed: " + e.getMessage());
            throw new RuntimeException(e);
        }
        return out;
    }

    private String arrayToPgVector(float[] v) {
        StringBuilder sb = new StringBuilder();
        sb.append('[');
        for (int i=0;i<v.length;i++) {
            if (i>0) sb.append(',');
            sb.append(v[i]);
        }
        sb.append(']');
        return sb.toString();
    }
}
JAVA_DAO

# patch Java pom.xml to add PostgreSQL JDBC dependency (if pom exists)
POM="$JAVA_DIR/pom.xml"
if [ -f "$POM" ]; then
  if ! grep -q "org.postgresql" "$POM"; then
    # insert dependency before </dependencies>
    perl -0777 -pe 's#</dependencies>#  <dependency>\n      <groupId>org.postgresql</groupId>\n      <artifactId>postgresql</artifactId>\n      <version>42.6.0</version>\n    </dependency>\n  </dependencies>#s' -i "$POM" || true
  fi
fi

# -----------------------
# 6) Helm chart scaffold
# -----------------------
mkdir -p "$HELM_DIR/templates"
cat > "$HELM_DIR/Chart.yaml" <<'HELM_CHART'
apiVersion: v2
name: nmar
description: NMAR Helm chart (scaffold). Replace placeholders for production.
type: application
version: 0.1.0
appVersion: "0.2.0"
HELM_CHART

cat > "$HELM_DIR/values.yaml" <<'HELM_VALUES'
replicaCount: 2
image:
  repository: nmar-core
  tag: latest
modelServer:
  image: nmar-model-server
  tag: latest
postgres:
  image: ankane/pgvector
  tag: pg15
  persistence:
    enabled: true
    size: 5Gi
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "2"
    memory: "4Gi"
nodeSelector: {}
tolerations: []
affinity: {}
HELM_VALUES

cat > "$HELM_DIR/templates/deployment-core.yaml" <<'HELM_DEPLOY_CORE'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nmar.fullname" . }}-core
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "nmar.name" . }}-core
  template:
    metadata:
      labels:
        app: {{ include "nmar.name" . }}-core
    spec:
      containers:
      - name: core
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        env:
        - name: MODEL_SERVER_URL
          value: "http://{{ include "nmar.name" . }}-model-server:8080"
        resources:
{{ toYaml .Values.resources | indent 10 }}
HELM_DEPLOY_CORE

cat > "$HELM_DIR/templates/deployment-modelserver.yaml" <<'HELM_DEPLOY_MS'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nmar.fullname" . }}-model-server
spec:
  replicas: 2
  selector:
    matchLabels:
      app: {{ include "nmar.name" . }}-model-server
  template:
    metadata:
      labels:
        app: {{ include "nmar.name" . }}-model-server
    spec:
      containers:
      - name: model-server
        image: "{{ .Values.modelServer.image }}:{{ .Values.modelServer.tag | default "latest" }}"
        ports:
        - containerPort: 8080
        resources:
{{ toYaml .Values.resources | indent 10 }}
HELM_DEPLOY_MS

cat > "$HELM_DIR/templates/_helpers.tpl" <<'HELM_HELP'
{{- define "nmar.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 -}}
{{- end -}}

{{- define "nmar.fullname" -}}
{{- printf "%s-%s" (include "nmar.name" .) .Release.Name | trunc 63 -}}
{{- end -}}
HELM_HELP

# -----------------------
# 7) docker-compose mock infra (postgres + mock servers)
# -----------------------
cat > "$COMPOSE_FILE" <<DOCKER_COMPOSE
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
version: "3.8"
services:
  postgres:
    image: ${PGVECTOR_IMAGE}
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "${POSTGRES_PORT}:5432"
    volumes:
      - ./db/migrations:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 5s
      timeout: 5s
      retries: 10

  mock-grpc:
    build: ./python_model_server
    command: ["python","mock/mock_grpc_server.py"]
    environment:
      MODEL_SERVER_API_KEY: "${MODEL_SERVER_API_KEY}"
      TRITON_MOCK_PORT: ${TRITON_MOCK_PORT}
    ports:
      - "${TRITON_MOCK_PORT}:${TRITON_MOCK_PORT}"

  model-server:
    build: ./python_model_server
    command: ["uvicorn", "src.server:app", "--host", "0.0.0.0", "--port", "8080"]
    environment:
      NMAR_MODEL_PATH: /models/model.pt
      NMAR_MODEL_TYPE: torch
      MODEL_SERVER_API_KEY: "${MODEL_SERVER_API_KEY}"
    ports:
      - "8080:8080"
    volumes:
      - ./python_model_server/models:/models:ro
    depends_on:
      - postgres
DOCKER_COMPOSE

# -----------------------
# 8) Local end-to-end smoke test script (simulates network calls)
# -----------------------
cat > "$EXT_DIR/scripts/run_local_e2e.sh" <<'E2E'
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
E2E

chmod +x "$EXT_DIR/scripts/run_local_e2e.sh"

# -----------------------
# 9) Instructions and summary file
# -----------------------
cat > "$EXT_DIR/README.md" <<README_EXT
# NMAR Extension — Mock Infra, Triton/ONNX/TorchServe Adapters, Helm & pgvector
Copyright © 2025 Devin B. Royal. All Rights Reserved.

This extension script scaffolds production-ready artifacts and local simulation harnesses.
It does NOT provision any real cloud resources. It creates:
 - proto/ (gRPC proto definitions)
 - Java gRPC skeletons (replace with protoc-generated stubs for production)
 - Python adapter scaffolds (triton_adapter, torchserve_adapter, onnx_adapter)
 - docker-compose.mock.yml (Postgres with pgvector extension, model server mock)
 - Helm chart scaffold under infra/helm/nmar
 - Postgres migration SQL (db/migrations)
 - JDBC DAO (java_nmar/src/main/java/com/devin/nmar/persistence/MemoryDAO.java)
 - Local randomized .nmar_local.env with credentials (safe for local use)

How to run (local simulation):
1. Ensure Docker & docker-compose are installed.
2. Run this script to generate scaffolding.
3. From the extension directory:
   cd extend_nmar_enterprise
   ./scripts/run_local_e2e.sh
   # This will build the python model server image, launch postgres + mock server, call the model server, and insert a vector into Postgres.

Production notes:
 - Replace randomized credentials in .nmar_local.env with secure secrets, then store them in your secret manager.
 - Generate gRPC Java stubs from proto/ using protoc and replace ModelServiceGrpcClient with the generated stub.
 - Configure Triton/TorchServe/ONNX runtime endpoints and point the adapter scaffolds at them.
 - For pgvector production tuning, adjust index type (HNSW/IVF) and memory settings.
 - Helm chart is scaffolded; expand templates for ConfigMaps, Secrets, Ingress (TLS), and RBAC.

README_EXT

echo "Extend script completed. Files written to: $EXT_DIR"
echo "Local env: $ENV_FILE"
echo "Run the local E2E script to simulate infra: $EXT_DIR/scripts/run_local_e2e.sh"
# Copyright © 2025 Devin B. Royal. All Rights Reserved.
