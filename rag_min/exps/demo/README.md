# RAG性能テストデモ

このStreamlitアプリは、異なるRAG実験（exp001、exp002など）の性能を比較・テストするためのデモアプリケーションです。

## 機能

### 🔍 検索テスト
- 各実験でクエリを実行し、検索結果を比較
- 距離スコア、ページ情報、チャンク情報を表示
- 章ルーティング情報（Exp001）を表示

### 💬 チャットテスト
- 各実験でチャット形式のクエリを実行
- AI回答、使用されたコンテキスト、コスト情報を表示
- 章ルーティング情報（Exp001）を表示

### 📊 比較テスト
- 全実験で同じクエリを実行し、結果を並べて比較
- タブ形式で各実験の結果を表示

## 利用可能な実験

### Main RAG System
- メインのRAGシステム（FastAPI + ChromaDB + OpenAI）
- `/ask` と `/chat` エンドポイントを使用
- 本格的なAI回答生成

### Exp001 - Chapter Router
- 章ルーティング機能付きRAGシステム
- 医療ガイドラインの章構造を活用
- TF-IDF + ルールベースの章選択

## セットアップ

### 1. 依存関係のインストール
```bash
pip install -r requirements.txt
```

### 2. 環境変数の設定
`.env` ファイルに以下を設定：
```
OPENAI_API_KEY=your_openai_api_key_here
```

### 3. メインRAGシステムの起動（オプション）
```bash
# 別ターミナルで
cd /path/to/rag_min
python main.py
```

### 4. Streamlitアプリの起動
```bash
cd /path/to/rag_min/exps/demo
streamlit run streamlit.py
```

## 使用方法

1. サイドバーで実験を選択
2. パラメータ（検索結果数など）を調整
3. モードを選択（検索/チャット/比較）
4. クエリを入力して実行
5. 結果を確認・比較

## 注意事項

- このデモは医療ガイドラインのRAG性能をテストするためのものです
- 実際の医療判断には使用しないでください
- OpenAI APIキーが必要です（コストが発生します）
- メインRAGシステムを使用する場合は、FastAPIサーバーが起動している必要があります

## カスタマイズ

新しい実験を追加するには：

1. `RAGExperiment` クラスを継承
2. `query()` と `chat()` メソッドを実装
3. `get_available_experiments()` に追加

例：
```python
class Exp002RAGExperiment(RAGExperiment):
    def __init__(self):
        super().__init__(
            name="Exp002 - Custom RAG",
            description="カスタムRAGシステム"
        )
        # 初期化処理
    
    def query(self, question: str, k: int = 5) -> Dict[str, Any]:
        # クエリ実装
        pass
    
    def chat(self, message: str, k: int = 5) -> Dict[str, Any]:
        # チャット実装
        pass
```
