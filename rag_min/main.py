#!/usr/bin/env python3
import os
import pathlib
import logging

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from google.cloud import storage

from routes.api_routes import MedicalGuidelineAPIRouter
from services.rag_service import MedicalGuidelineRAGService

# =========================
# 環境
# =========================
load_dotenv(".env")  # ローカル実行時のみ有効。Cloud Run では環境変数/Secretを使用

GCS_BUCKET  = os.getenv("GCS_BUCKET")                   # 例: medical-guideline-bucket-20250907
GCS_PREFIX  = os.getenv("GCS_PREFIX", "chroma_db")      # 例: chroma_db
PERSIST_DIR = os.getenv("PERSIST_DIR", "/tmp/chroma_db")  # Cloud Run は /tmp を使用

# TOC はリポジトリ同梱（Docker イメージ内）
TOC_PATH    = os.getenv("TOC_PATH", "toc/chapter.json")
COLLECTION  = os.getenv("COLLECTION", "guidelines")

# =========================
# ログ設定
# =========================
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("startup")

# =========================
# GCS → /tmp 同期（Chromaのみ）
# =========================
def download_gcs_dir(bucket_name: str, prefix: str, local_dir: str):
    """GCS の prefix 配下をローカルへ再帰ダウンロード。"""
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blobs = client.list_blobs(bucket, prefix=prefix)

    base = pathlib.Path(local_dir)
    count = 0
    for b in blobs:
        # ディレクトリエントリはスキップ
        if b.name.endswith("/"):
            continue
        rel = b.name[len(prefix):].lstrip("/")
        dest = base / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        b.download_to_filename(dest.as_posix())
        count += 1
    logger.info("Downloaded %d files from gs://%s/%s -> %s", count, bucket_name, prefix, local_dir)

# =========================
# FastAPI
# =========================
app = FastAPI(
    title="Medical Guideline RAG API",
    description="RAGベースの医療ガイドライン検索API (FastAPI)",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番は適切に制限
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================
# 起動時：Chroma同期 → RAG初期化 → ルータ組み込み（フェイルセーフ）
# =========================
@app.on_event("startup")
def prepare_chroma_and_rag():
    try:
        logger.info("===== Startup: begin =====")
        logger.info("Env  Bucket=%s  Prefix=%s  PersistDir=%s", GCS_BUCKET, GCS_PREFIX, PERSIST_DIR)
        logger.info("Paths TOC=%s  COLLECTION=%s", TOC_PATH, COLLECTION)

        # 1) Chroma 同期
        if not GCS_BUCKET:
            raise RuntimeError("GCS_BUCKET is not set")
        if not os.path.exists(PERSIST_DIR) or not os.listdir(PERSIST_DIR):
            logger.info("Local persist dir is empty → start GCS sync...")
            os.makedirs(PERSIST_DIR, exist_ok=True)
            download_gcs_dir(GCS_BUCKET, GCS_PREFIX, PERSIST_DIR)
        else:
            logger.info("Local persist dir already has data: %s", PERSIST_DIR)

        # 2) TOC 存在チェック（リポジトリ同梱）
        if not os.path.isfile(TOC_PATH):
            raise FileNotFoundError(f"TOC file not found at {TOC_PATH}")

        # 3) RAGサービス初期化（output_dir は使わない運用）
        logger.info("Initialize RAG service...")
        rag_service = MedicalGuidelineRAGService(
            persist_dir=PERSIST_DIR,
            toc_path=TOC_PATH,
            collection=COLLECTION,
        )
        app.state.rag_service = rag_service
        logger.info("RAG service initialized")

        # 4) ルーター登録
        api_router = MedicalGuidelineAPIRouter(rag_service)
        app.include_router(api_router.get_router())
        logger.info("Router mounted")

        app.state.startup_ok = True
        app.state.startup_error = None
        logger.info("===== Startup: success =====")

    except Exception as e:
        logger.exception("===== Startup FAILED =====")
        app.state.startup_ok = False
        app.state.startup_error = f"{type(e).__name__}: {e}"
        # サーバは起動継続（/statusで原因を確認可能）

# =========================
# ヘルス／デバッグ
# =========================
@app.get("/status")
def status():
    ready = os.path.isdir(PERSIST_DIR) and bool(os.listdir(PERSIST_DIR))
    return {
        "ok": True,
        "persist_dir_ready": ready,
        "bucket": GCS_BUCKET,
        "prefix": GCS_PREFIX,
        "persist_dir": PERSIST_DIR,
        "startup_ok": getattr(app.state, "startup_ok", None),
        "startup_error": getattr(app.state, "startup_error", None),
        "toc_path": TOC_PATH,
    }

# =========================
# ローカル実行
# =========================
if __name__ == "__main__":
    import uvicorn
    # Cloud Run ではエントリポイントは Docker CMD/ENTRYPOINT 側。ローカルのみ使用。
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
