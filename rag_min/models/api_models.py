#!/usr/bin/env python3
"""
FastAPI用のPydanticモデル定義
"""
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field


class Status(BaseModel):
    """システムステータスレスポンスモデル"""
    ok: bool
    persist_dir: str
    collection: str
    toc_path: str
    output_dir: str


class AskRequest(BaseModel):
    """質問リクエストモデル"""
    question: str = Field(..., description="質問文")
    topk_chapters: int = Field(3, ge=1, le=10, description="選択する章の数")
    topk_chunks: int = Field(5, ge=1, le=20, description="選択するチャンクの数")


class ChapterRequest(BaseModel):
    """章選択リクエストモデル"""
    question: str = Field(..., description="質問文")
    topk: int = Field(3, ge=1, le=10, description="選択する章の数")


class ChunkRequest(BaseModel):
    """チャンク選択リクエストモデル"""
    question: str = Field(..., description="質問文")
    topk: int = Field(5, ge=1, le=20, description="選択するチャンクの数")
    chapters: Optional[List[Dict[str, Any]]] = Field(
        None, 
        description="章を外部から固定したい場合に利用"
    )


class ChapterResponse(BaseModel):
    """章選択レスポンスモデル"""
    question: str
    chapters: List[Dict[str, Any]]


class ChunkResponse(BaseModel):
    """チャンク選択レスポンスモデル"""
    question: str
    chapters: List[Dict[str, Any]]
    chunks: List[Dict[str, Any]]


class AskResponse(BaseModel):
    """質問回答レスポンスモデル"""
    question: str
    selected_chapters: List[Dict[str, Any]]
    selected_chunks: List[Dict[str, Any]]
    answer: str
    log_file: str
