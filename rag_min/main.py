#!/usr/bin/env python3
"""
Medical Guideline RAG API - メインエントリーポイント
クリーンなアーキテクチャでRAGロジックとFastAPIを分離

- /status: 動作確認
- /ask: 質問→ Chapter選択 → チャンク選択 → GPT-4o で回答生成（ログ保存あり）
- /select/chapters: Chapterルーターの結果のみ確認
- /select/chunks: チャンク選択のみ確認（Chapter指定または自動選択）

前提:
- ChromaDB 永続化: PERSIST_DIR = data/chroma_db
- ルーター: route_chapter.py に ChapterRouter が定義されていること
- TOC JSON: toc/chapter.json (キー "toc")
- .env に OPENAI_API_KEY

起動: uvicorn main:app --reload --port 8000
"""
import os
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from services.rag_service import MedicalGuidelineRAGService
from routes.api_routes import MedicalGuidelineAPIRouter

# =========================
# 環境・定数
# =========================
load_dotenv(".env")

# 環境変数の設定
PERSIST_DIR = os.getenv("PERSIST_DIR", "exps/exp001/data/chroma_db")
TOC_PATH = os.getenv("TOC_PATH", "exps/exp001/toc/chapter.json")
OUTPUT_DIR = os.getenv("OUTPUT_DIR", "exps/exp001/output")
COLLECTION = "guidelines"

# =========================
# FastAPI アプリケーション
# =========================
app = FastAPI(
    title="Medical Guideline RAG API",
    description="RAGベースの医療ガイドライン検索API (FastAPI)",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 開発中は *、本番は限定
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================
# サービス初期化
# =========================
_rag_service: Optional[MedicalGuidelineRAGService] = None

def get_rag_service() -> MedicalGuidelineRAGService:
    """RAGサービスのシングルトン取得"""
    global _rag_service
    if _rag_service is None:
        _rag_service = MedicalGuidelineRAGService(
            persist_dir=PERSIST_DIR,
            toc_path=TOC_PATH,
            output_dir=OUTPUT_DIR,
            collection=COLLECTION
        )
    return _rag_service

# =========================
# ルート設定
# =========================
# RAGサービスを初期化
rag_service = get_rag_service()

# APIルーターを設定
api_router = MedicalGuidelineAPIRouter(rag_service)
app.include_router(api_router.get_router())


# =========================
# ローカル実行
# =========================
if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
