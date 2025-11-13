# PDFから章情報を抽出 (exp002)

## 概要
`getchapter.py`は、PDFファイルから章情報を抽出して`chapter.json`形式で出力するスクリプトです。

`rag_min.py`は、安全なRAGパイプライン（チャンク化・埋め込み・検索）を提供するツールです。

## 使用方法

### 基本的な使用法
```bash
cd /home/kaitech/KaiTech/Medical-Guidelines/rag_min/exps/exp002

# PDFから章情報を抽出してJSONファイルに出力
python getchapter.py ../../pdf/JCS2025_Imai.pdf output/chapter.json "心不全診療ガイドライン"
```

### 引数
1. **PDFファイルパス** (必須): 抽出元のPDFファイルのパス
2. **出力JSONパス** (オプション): 出力先のJSONファイルパス（指定しない場合は標準出力）
3. **doc_id** (オプション): ドキュメントID（デフォルトはPDFファイル名）

### 例

#### 例1: 基本的な抽出
```bash
python getchapter.py ../../pdf/JCS2025_Imai.pdf
```

#### 例2: ファイルに出力
```bash
python getchapter.py ../../pdf/JCS2025_Imai.pdf output/chapter.json "心不全診療ガイドライン"
```

#### 例3: カスタムdoc_idを指定
```bash
python getchapter.py ../../pdf/JCS2025_Kato.pdf output/kato_chapter.json "JCS2025_Kato"
```

## 出力形式

出力されるJSONファイルは以下の形式です:

```json
{
  "doc_id": "心不全診療ガイドライン",
  "version": "v1.0",
  "toc": [
    {
      "section_path": "第1章 はじめに",
      "level": 1,
      "start_page": 17,
      "end_page": 18
    },
    {
      "section_path": "第1章 > 1. 推奨クラスとエビデンスレベルについて",
      "level": 2,
      "start_page": 17,
      "end_page": 17
    }
  ]
}
```

## 動作の仕組み

1. **TOCからの抽出**: PDFに埋め込まれた目次（TOC）がある場合、それを直接使用します
2. **テキスト解析**: TOCがない場合、PDFのテキストを解析して見出しパターンを検出します
   - フォントサイズや太字などの書式情報を利用
   - 正規表現パターンで見出しを識別
   - 階層構造を自動検出

## トラブルシューティング

### PyMuPDFがインストールされていない場合
```bash
pip install pymupdf
```

### 章情報が正しく抽出されない場合
- PDFに埋め込まれたTOCがあるか確認
- フォントサイズのしきい値を調整（`getchapter.py`の`min_font_size`パラメータ）

---

## rag_min.py の使い方

### 概要
`rag_min.py`は、安全なRAGパイプラインを提供するツールです。以下の4つのサブコマンドがあります：

1. **init-db**: データベーススキーマの初期化
2. **chunk**: PDFをチャンク化してDBに保存（埋め込みはNULLのまま）
3. **embed**: チャンクに埋め込みを生成・設定
4. **retrieve**: クエリで検索

### 前提条件

#### 1. 依存パッケージのインストール
```bash
pip install psycopg[binary] pymupdf regex
```

#### 2. 環境変数の設定
```bash
export DATABASE_URL="postgresql://postgres@localhost:5432/med_guides"
```

#### 3. TOCデータの準備
`chunk`コマンドを実行する前に、`toc`テーブルに章情報を投入する必要があります。

**方法1: SQLファイルから投入**
```bash
# build_guideline_sql.pyで生成したSQLファイルを実行
psql $DATABASE_URL -f output/JCS2013_ogawah_h.sql
```

**方法2: 直接INSERT**
```sql
INSERT INTO toc (doc_id, section_path, start_page, end_page, version)
VALUES ('心不全診療ガイドライン', '第1章 はじめに', 17, 18, 'v1.0');
```

### 基本的な使用フロー

#### ステップ1: データベース初期化
```bash
python rag_min.py init-db
```

#### ステップ2: TOCデータの投入
```bash
# 事前にtocテーブルにデータを投入（上記参照）
```

#### ステップ3: PDFのチャンク化
```bash
python rag_min.py chunk \
  --doc "心不全診療ガイドライン" \
  --pdf ../../pdf/JCS2025_Imai.pdf \
  --version "v1.0"
```

#### ステップ4: 埋め込みの生成
```bash
python rag_min.py embed \
  --doc "心不全診療ガイドライン" \
  --batch 256
```

**注意**: 現在は`dummy_embed`関数（ダミー埋め込み）が使用されています。実運用では、`rag_min.py`の`dummy_embed`関数をOpenAI/Azure/ローカルSentence Transformersに置き換えてください。

#### ステップ5: 検索
```bash
python rag_min.py retrieve \
  --doc "心不全診療ガイドライン" \
  --query "心不全の治療" \
  --k 8 \
  --oversample 40
```

### 各コマンドの詳細

#### `init-db`
データベーススキーマを作成・更新します。安全ガード（NOT NULL制約、CHECK制約、一意制約）も設定されます。

```bash
python rag_min.py init-db
```

#### `chunk`
PDFをチャンク化してDBに保存します。埋め込みはNULLのままです。

```bash
python rag_min.py chunk \
  --doc <doc_id> \          # 必須: ドキュメントID
  --pdf <pdf_path> \        # 必須: PDFファイルのパス
  --version <version>       # オプション: バージョン（デフォルト: v1）
```

**注意**: `toc`テーブルに該当`doc_id`の章情報が存在する必要があります。

#### `embed`
チャンクに埋め込みを生成・設定します。

```bash
python rag_min.py embed \
  --doc <doc_id> \          # 必須: ドキュメントID
  --batch <batch_size>      # オプション: バッチサイズ（デフォルト: 256）
```

#### `retrieve`
クエリで検索します。章ルーティングとtrgm類似度検索を使用します。

```bash
python rag_min.py retrieve \
  --doc <doc_id> \          # 必須: ドキュメントID
  --query <query> \         # 必須: 検索クエリ
  --k <k> \                 # オプション: 返す結果数（デフォルト: 8）
  --oversample <n>          # オプション: オーバーサンプル数（デフォルト: 40）
```

### 出力例

`retrieve`コマンドの出力例：

```json
{
  "sections": [
    "第6章 薬物療法",
    "第6章 > 6.2 DPP-4阻害薬"
  ],
  "hits": [
    {
      "id": 123,
      "section_path": "第6章 薬物療法",
      "page": 45,
      "text": "DPP-4阻害薬は...（チャンクテキスト）"
    }
  ]
}
```

### トラブルシューティング

#### `toc empty for doc_id=XXX` エラー
- `toc`テーブルに該当`doc_id`のデータが存在しない
- `INSERT INTO toc ...`でデータを投入してください

#### ゼロトークン検出エラー
- チャンク化時に空のテキストが検出された
- PDFのテキスト抽出を確認してください

#### データベース接続エラー
- `DATABASE_URL`環境変数が正しく設定されているか確認
- PostgreSQLが起動しているか確認
- `vector`と`pg_trgm`拡張がインストールされているか確認

