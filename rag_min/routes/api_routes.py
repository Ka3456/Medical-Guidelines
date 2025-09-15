#!/usr/bin/env python3
"""
FastAPIルート定義
"""
from typing import Dict, Any, Optional
from fastapi import APIRouter as FastAPIRouter, HTTPException
from starlette.concurrency import run_in_threadpool

from services.rag_service import MedicalGuidelineRAGService
from models.api_models import (
    Status, AskRequest, ChapterRequest, ChunkRequest,
    ChapterResponse, ChunkResponse, AskResponse,
    RatingRequest, RatingResponse
)


class MedicalGuidelineAPIRouter:
    """APIルータークラス"""
    
    def __init__(self, rag_service: MedicalGuidelineRAGService):
        """
        APIルーターの初期化
        
        Args:
            rag_service: RAGサービスのインスタンス
        """
        self.rag_service = rag_service
        self.router = FastAPIRouter()
        self._setup_routes()
    
    def _setup_routes(self):
        """ルートの設定"""
        
        @self.router.get("/status", response_model=Status)
        async def status() -> Status:
            """システムステータスの取得"""
            return Status(
                ok=True,
                persist_dir=self.rag_service.persist_dir,
                collection=self.rag_service.collection,
                toc_path=self.rag_service.toc_path,
                output_dir=self.rag_service.output_dir,
            )

        @self.router.post("/ask", response_model=AskResponse)
        async def ask(req: AskRequest) -> AskResponse:
            """質問に対する回答生成"""
            try:
                # Chroma/OpenAI 呼び出しはブロッキングが多いのでスレッドに逃がす
                result = await run_in_threadpool(
                    self.rag_service.process_question, 
                    req.question, 
                    req.topk_chapters, 
                    req.topk_chunks
                )
                return AskResponse(**result)
            except Exception as e:
                raise HTTPException(status_code=500, detail=str(e))

        @self.router.post("/select/chapters", response_model=ChapterResponse)
        async def select_chapters(req: ChapterRequest) -> ChapterResponse:
            """章選択のみの実行"""
            try:
                chapters = await run_in_threadpool(
                    self.rag_service.select_chapters, 
                    req.question, 
                    req.topk
                )
                return ChapterResponse(question=req.question, chapters=chapters)
            except Exception as e:
                raise HTTPException(status_code=500, detail=str(e))

        @self.router.post("/select/chunks", response_model=ChunkResponse)
        async def select_chunks(req: ChunkRequest) -> ChunkResponse:
            """チャンク選択のみの実行"""
            try:
                if req.chapters is None:
                    chapters = await run_in_threadpool(
                        self.rag_service.select_chapters, 
                        req.question, 
                        3
                    )
                else:
                    chapters = req.chapters
                
                chunks = await run_in_threadpool(
                    self.rag_service.select_chunks, 
                    req.question, 
                    chapters, 
                    req.topk
                )
                return ChunkResponse(
                    question=req.question, 
                    chapters=chapters, 
                    chunks=chunks
                )
            except Exception as e:
                raise HTTPException(status_code=500, detail=str(e))

        @self.router.post("/rating", response_model=RatingResponse)
        async def update_rating(req: RatingRequest) -> RatingResponse:
            """メッセージの評価を更新または削除"""
            try:
                result = await run_in_threadpool(
                    self.rag_service.update_message_rating,
                    req.message_id,
                    req.rating,
                    req.comment
                )
                return RatingResponse(**result)
            except Exception as e:
                raise HTTPException(status_code=500, detail=str(e))
    
    def get_router(self):
        """ルーターの取得"""
        return self.router
