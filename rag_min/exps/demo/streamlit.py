import streamlit as st
import os
import sys
import json
import requests
from pathlib import Path
from typing import List, Dict, Any, Optional
import time

# パスの設定
current_dir = Path(__file__).parent
rag_min_dir = current_dir.parent.parent
sys.path.append(str(rag_min_dir))
sys.path.append(str(current_dir.parent / "exp001"))

# 実験ディレクトリの設定
EXPERIMENTS_DIR = current_dir.parent

# ページ設定
st.set_page_config(
    page_title="RAG性能テストデモ",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# カスタムCSS
st.markdown("""
<style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        color: #1f77b4;
        text-align: center;
        margin-bottom: 2rem;
    }
    .experiment-card {
        border: 1px solid #ddd;
        border-radius: 10px;
        padding: 1rem;
        margin: 0.5rem 0;
        background-color: #f9f9f9;
    }
    .metric-box {
        background-color: #e8f4fd;
        padding: 1rem;
        border-radius: 5px;
        margin: 0.5rem 0;
    }
    .response-box {
        background-color: #f0f8ff;
        padding: 1rem;
        border-radius: 5px;
        border-left: 4px solid #1f77b4;
        margin: 1rem 0;
    }
    .context-box {
        background-color: #fff5f5;
        padding: 0.8rem;
        border-radius: 5px;
        border-left: 4px solid #ff6b6b;
        margin: 0.5rem 0;
    }
</style>
""", unsafe_allow_html=True)

class RAGExperiment:
    """RAG実験の基底クラス"""
    
    def __init__(self, name: str, description: str):
        self.name = name
        self.description = description
    
    def query(self, question: str, k: int = 5) -> Dict[str, Any]:
        """クエリを実行して結果を返す"""
        raise NotImplementedError
    
    def chat(self, message: str, k: int = 5) -> Dict[str, Any]:
        """チャット形式でクエリを実行"""
        raise NotImplementedError

class MainRAGExperiment(RAGExperiment):
    """メインのRAGシステム（FastAPI経由）"""
    
    def __init__(self):
        super().__init__(
            name="Main RAG System",
            description="メインのRAGシステム（FastAPI + ChromaDB + OpenAI）"
        )
        self.base_url = "http://localhost:8000"
    
    def query(self, question: str, k: int = 5) -> Dict[str, Any]:
        """/ask エンドポイントを使用"""
        try:
            response = requests.post(
                f"{self.base_url}/ask",
                json={"question": question, "k": k},
                timeout=30
            )
            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"API Error: {response.status_code}"}
        except requests.exceptions.RequestException as e:
            return {"error": f"Connection Error: {str(e)}"}
    
    def chat(self, message: str, k: int = 5) -> Dict[str, Any]:
        """/chat エンドポイントを使用"""
        try:
            response = requests.post(
                f"{self.base_url}/chat",
                json={"message": message, "k": k, "include_context": True},
                timeout=30
            )
            if response.status_code == 200:
                return response.json()
            else:
                return {"error": f"API Error: {response.status_code}"}
        except requests.exceptions.RequestException as e:
            return {"error": f"Connection Error: {str(e)}"}

class Exp001RAGExperiment(RAGExperiment):
    """Exp001のRAGシステム（直接実装）"""
    
    def __init__(self):
        super().__init__(
            name="Exp001 - Chapter Router",
            description="章ルーティング機能付きRAGシステム"
        )
        self._setup_exp001()
    
    def _setup_exp001(self):
        """Exp001の設定"""
        try:
            # ChromaDBの設定
            import chromadb
            from chromadb.utils.embedding_functions import OpenAIEmbeddingFunction
            
            self.persist_dir = str(EXPERIMENTS_DIR / "exp001" / "data" / "chroma_db")
            self.collection_name = "guidelines"
            
            # ChromaDBクライアント
            self.client = chromadb.PersistentClient(path=self.persist_dir)
            self.emb_fn = OpenAIEmbeddingFunction(
                model_name="text-embedding-3-large",
                api_key=os.getenv("OPENAI_API_KEY")
            )
            self.collection = self.client.get_or_create_collection(
                name=self.collection_name, 
                embedding_function=self.emb_fn
            )
            
            # 章ルーターの設定
            from route_chapter import ChapterRouter
            toc_path = EXPERIMENTS_DIR / "exp001" / "toc" / "chapter.json"
            if toc_path.exists():
                with open(toc_path, 'r', encoding='utf-8') as f:
                    toc_data = json.load(f)
                self.router = ChapterRouter(toc_data["toc"])
            else:
                self.router = None
                
        except Exception as e:
            st.error(f"Exp001の設定エラー: {str(e)}")
            self.collection = None
            self.router = None
    
    def query(self, question: str, k: int = 5) -> Dict[str, Any]:
        """直接ChromaDBにクエリ"""
        if not self.collection:
            return {"error": "Exp001が正しく設定されていません"}
        
        try:
            # 章ルーティング（利用可能な場合）
            chapter_info = []
            if self.router:
                chapter_hits = self.router.route(question, topk=3)
                chapter_info = chapter_hits
            
            # ChromaDBクエリ
            results = self.collection.query(
                query_texts=[question],
                n_results=k,
                include=["documents", "metadatas", "distances"]
            )
            
            hits = []
            docs = (results.get("documents") or [[]])[0]
            metas = (results.get("metadatas") or [[]])[0]
            dists = (results.get("distances") or [[]])[0]
            
            for doc, meta, dist in zip(docs, metas, dists):
                hits.append({
                    "text": doc,
                    "page": int(meta.get("page", 0)),
                    "chunk": int(meta.get("chunk", 0)),
                    "source": str(meta.get("source", "")),
                    "doc_id": str(meta.get("doc_id", "")),
                    "distance": float(dist) if dist is not None else None
                })
            
            return {
                "hits": hits,
                "chapter_info": chapter_info
            }
            
        except Exception as e:
            return {"error": f"Query Error: {str(e)}"}
    
    def chat(self, message: str, k: int = 5) -> Dict[str, Any]:
        """簡易チャット機能"""
        # まずクエリを実行
        query_result = self.query(message, k)
        if "error" in query_result:
            return query_result
        
        # 簡易的なレスポンス生成
        context_hits = query_result.get("hits", [])
        chapter_info = query_result.get("chapter_info", [])
        
        # コンテキストを構築
        context_text = ""
        if context_hits:
            context_text = "関連する医療ガイドライン情報:\n"
            for i, hit in enumerate(context_hits[:3], 1):
                context_text += f"\n[{i}] {hit['source']} (ページ {hit['page']})\n{hit['text'][:200]}...\n"
        
        # 章情報を追加
        if chapter_info:
            context_text += "\n関連する章:\n"
            for info in chapter_info[:2]:
                context_text += f"- {info['section_path']} (スコア: {info['score']:.3f})\n"
        
        response = f"質問: {message}\n\n{context_text}\n\n※これは簡易的なデモです。実際の回答にはOpenAI APIを使用してください。"
        
        return {
            "response": response,
            "context_used": context_hits,
            "chapter_info": chapter_info,
            "model_used": "Demo Mode"
        }

def get_available_experiments() -> List[RAGExperiment]:
    """利用可能な実験を取得"""
    experiments = []
    
    # メインRAGシステム
    experiments.append(MainRAGExperiment())
    
    # Exp001
    experiments.append(Exp001RAGExperiment())
    
    # 他の実験があれば追加
    # TODO: exp002, exp003などを追加
    
    return experiments

def display_query_results(results: Dict[str, Any], experiment_name: str):
    """クエリ結果を表示"""
    if "error" in results:
        st.error(f"エラー ({experiment_name}): {results['error']}")
        return
    
    # ヒット結果の表示
    hits = results.get("hits", [])
    if hits:
        st.subheader(f"🔍 検索結果 ({experiment_name})")
        
        for i, hit in enumerate(hits, 1):
            with st.expander(f"結果 {i}: {hit['source']} (ページ {hit['page']})"):
                st.write(f"**距離スコア:** {hit.get('distance', 'N/A')}")
                st.write(f"**チャンク:** {hit['chunk']}")
                st.write(f"**内容:**")
                st.write(hit['text'])
    
    # 章情報の表示（Exp001の場合）
    chapter_info = results.get("chapter_info", [])
    if chapter_info:
        st.subheader("📚 関連する章")
        for info in chapter_info:
            st.write(f"- **{info['section_path']}** (スコア: {info['score']:.3f})")
            st.write(f"  ページ: {info.get('start_page', 'N/A')}-{info.get('end_page', 'N/A')}")

def display_chat_results(results: Dict[str, Any], experiment_name: str):
    """チャット結果を表示"""
    if "error" in results:
        st.error(f"エラー ({experiment_name}): {results['error']}")
        return
    
    # レスポンスの表示
    response = results.get("response", "")
    if response:
        st.markdown(f'<div class="response-box"><strong>🤖 回答 ({experiment_name}):</strong><br>{response}</div>', 
                   unsafe_allow_html=True)
    
    # コスト情報の表示
    cost_info = results.get("cost_info", {})
    if cost_info:
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("入力トークン", cost_info.get("input_tokens", 0))
        with col2:
            st.metric("出力トークン", cost_info.get("output_tokens", 0))
        with col3:
            st.metric("コスト (USD)", f"${cost_info.get('total_cost_usd', 0):.6f}")
    
    # 使用されたコンテキストの表示
    context_used = results.get("context_used", [])
    if context_used:
        st.subheader("📖 使用されたコンテキスト")
        for i, ctx in enumerate(context_used[:3], 1):
            st.markdown(f'<div class="context-box"><strong>[{i}] {ctx["source"]} (ページ {ctx["page"]})</strong><br>{ctx["text"][:300]}...</div>', 
                       unsafe_allow_html=True)
    
    # 章情報の表示（Exp001の場合）
    chapter_info = results.get("chapter_info", [])
    if chapter_info:
        st.subheader("📚 関連する章")
        for info in chapter_info:
            st.write(f"- **{info['section_path']}** (スコア: {info['score']:.3f})")

def main():
    # ヘッダー
    st.markdown('<div class="main-header">🏥 RAG性能テストデモ</div>', unsafe_allow_html=True)
    
    # サイドバー
    with st.sidebar:
        st.header("⚙️ 設定")
        
        # 実験選択
        experiments = get_available_experiments()
        experiment_names = [exp.name for exp in experiments]
        selected_exp_idx = st.selectbox(
            "実験を選択:",
            range(len(experiments)),
            format_func=lambda x: experiment_names[x]
        )
        selected_experiment = experiments[selected_exp_idx]
        
        st.markdown(f"**説明:** {selected_experiment.description}")
        
        # パラメータ設定
        st.subheader("🔧 パラメータ")
        k_results = st.slider("検索結果数 (k)", 1, 10, 5)
        
        # モード選択
        mode = st.radio(
            "モード:",
            ["🔍 検索テスト", "💬 チャットテスト", "📊 比較テスト"]
        )
    
    # メインコンテンツ
    if mode == "🔍 検索テスト":
        st.header("🔍 検索テスト")
        
        # クエリ入力
        query = st.text_area(
            "検索クエリを入力してください:",
            placeholder="例: HFpEFの薬物治療について教えて",
            height=100
        )
        
        if st.button("🔍 検索実行", type="primary"):
            if query.strip():
                with st.spinner("検索中..."):
                    results = selected_experiment.query(query, k_results)
                    display_query_results(results, selected_experiment.name)
            else:
                st.warning("クエリを入力してください。")
    
    elif mode == "💬 チャットテスト":
        st.header("💬 チャットテスト")
        
        # メッセージ入力
        message = st.text_area(
            "メッセージを入力してください:",
            placeholder="例: 心不全の診断基準について詳しく教えて",
            height=100
        )
        
        if st.button("💬 チャット実行", type="primary"):
            if message.strip():
                with st.spinner("回答生成中..."):
                    results = selected_experiment.chat(message, k_results)
                    display_chat_results(results, selected_experiment.name)
            else:
                st.warning("メッセージを入力してください。")
    
    elif mode == "📊 比較テスト":
        st.header("📊 比較テスト")
        
        # クエリ入力
        query = st.text_area(
            "比較するクエリを入力してください:",
            placeholder="例: 心不全の治療法について",
            height=100
        )
        
        if st.button("📊 全実験で比較実行", type="primary"):
            if query.strip():
                # 全実験で実行
                results_data = []
                
                for exp in experiments:
                    with st.spinner(f"{exp.name} で実行中..."):
                        if "chat" in mode.lower():
                            results = exp.chat(query, k_results)
                        else:
                            results = exp.query(query, k_results)
                        results_data.append((exp.name, results))
                
                # 結果をタブで表示
                tabs = st.tabs([exp.name for exp in experiments])
                
                for i, (exp_name, results) in enumerate(results_data):
                    with tabs[i]:
                        if "chat" in mode.lower():
                            display_chat_results(results, exp_name)
                        else:
                            display_query_results(results, exp_name)
            else:
                st.warning("クエリを入力してください。")
    
    # フッター
    st.markdown("---")
    st.markdown(
        "**注意:** このデモは医療ガイドラインのRAG性能をテストするためのものです。"
        "実際の医療判断には使用しないでください。"
    )

if __name__ == "__main__":
    main()
