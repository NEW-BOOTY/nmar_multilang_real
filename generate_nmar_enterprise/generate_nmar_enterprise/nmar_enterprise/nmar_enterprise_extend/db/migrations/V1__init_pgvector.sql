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
