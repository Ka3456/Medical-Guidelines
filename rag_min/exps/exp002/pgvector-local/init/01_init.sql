-- pgvector拡張機能の有効化
CREATE EXTENSION IF NOT EXISTS vector;

-- 既存テーブルを削除（再初期化時用）
DROP TABLE IF EXISTS docs CASCADE;

-- メインのdocsテーブル
-- 1536次元（例：OpenAI text-embedding-3-small系）※後で好みの次元に変更OK
CREATE TABLE docs (
  id BIGSERIAL PRIMARY KEY,
  doc_id TEXT UNIQUE NOT NULL,
  content TEXT NOT NULL,
  embedding VECTOR(1536),
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 近傍検索用のIVFFLATインデックス
-- listsはコーパス規模で調整（1〜10万なら 100〜1000 くらいから）
CREATE INDEX IF NOT EXISTS docs_embedding_ivfflat
  ON docs USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

-- よく使うメタデータインデックス（任意）
CREATE INDEX IF NOT EXISTS docs_doc_id_idx ON docs(doc_id);
CREATE INDEX IF NOT EXISTS docs_metadata_idx ON docs USING GIN (metadata);

-- pg_trgm拡張も追加（trigram検索との併用も可能）
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS docs_content_trgm_idx ON docs USING GIN (content gin_trgm_ops);

ANALYZE docs;

-- サンプルコメント
COMMENT ON TABLE docs IS 'RAG検索用ドキュメントテーブル（pgvector + pg_trgm対応）';

