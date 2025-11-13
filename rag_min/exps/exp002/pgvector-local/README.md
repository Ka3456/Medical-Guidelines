# pgvectorローカル検証環境

PostgreSQL + pgvector を使ったRAG検証環境（Docker Compose）

## 📋 接続情報（重要）

**すべてここにまとめています：**

| 項目 | 値 |
|------|-----|
| **ホスト** | 127.0.0.1 |
| **ポート** | **5433** ⚠️ 既存PostgreSQLと競合しないよう5433に変更 |
| **データベース名** | ragdb |
| **ユーザー名** | pguser |
| **パスワード** | pgpass |

**接続URL:**
```
postgresql://pguser:pgpass@127.0.0.1:5433/ragdb
```

環境変数として設定する場合:
```bash
export DATABASE_URL="postgresql://pguser:pgpass@127.0.0.1:5433/ragdb"
```

**注意**: 既存のPostgreSQLが5432ポートを使用しているため、Dockerコンテナは**5433ポート**を使用します。

---

## 🚀 クイックスタート（3ステップ）

### ステップ1: Dockerコンテナ起動

```bash
cd /home/kaitech/KaiTech/Medical-Guidelines/rag_min/exps/exp002/pgvector-local
sudo docker compose up -d
```

起動確認:
```bash
sudo docker compose ps
# または
docker compose logs -f
```

### ステップ2: データ投入

**重要**: データが無いと検索結果が0件になります。まずデータを投入しましょう。

**方法1: 既存SQLファイルを使用（推奨）**
```bash
# pgvector-localディレクトリで実行
python3 import_sql.py
```

これは `output/JCS2013_ogawah_h.sql` を読み込んで投入します。
医療ガイドラインの実際のデータが使用できます。

**方法2: 簡易版サンプルデータ（numpy不要）**
```bash
# pgvector-localディレクトリで実行
python3 init_data.py
```

**方法3: 詳細版サンプルデータ（numpy必要）**
```bash
# 仮想環境をアクティベート（必要に応じて）
source ../../.venv/bin/activate  # または適切なパス

# サンプルデータ投入＆検索テスト
cd examples
python3 seed_and_query.py
```

**方法1**を使うと、`chunks`テーブルに実際の医療ガイドラインデータが投入されます。

### ステップ3: RAG検索実行

```bash
# pgvector-localディレクトリで実行
cd ..

# デフォルト値で実行（引数なし！）
python3 rag_vector.py

# 質問を変える
python3 rag_vector.py --q "心不全の初期対応"

# 特定ドキュメントで絞る
python3 rag_vector.py --doc hf_01 --q "心不全"

# 返す件数を変える
python3 rag_vector.py --q "心不全" --k 10
```

### ステップ4: `rag_chat.py` で対話する

OpenAI API を利用した対話型 CLI です。チャンク済みデータと pgvector を使って関連箇所を検索し、回答を日本語で生成します。

1. **依存パッケージのインストール**
   ```bash
   pip install openai psycopg2-binary
   ```

2. **環境変数を設定**
   ```bash
   export OPENAI_API_KEY="sk-..."  # OpenAI APIキー
   export PG_DSN="dbname=ragdb user=pguser password=pgpass host=127.0.0.1 port=5433"  # 任意（未設定なら既定値を使用）
   ```

3. **CLIを実行**
   ```bash
   cd /home/kaitech/KaiTech/Medical-Guidelines/rag_min/exps/exp002/pgvector-local
   python3 rag_chat.py \
     --doc-id JCS2015_aonuma_h \
     --version v1 \
     --top-k 8 \
     --dsn "dbname=ragdb user=pguser password=pgpass host=127.0.0.1 port=5433"
   ```

   - `--doc-id`, `--version` は検索対象のガイドラインを指定します。
   - `--top-k` は取得するチャンク数（デフォルト8）。
   - `--dsn` を省略した場合は `PG_DSN` 環境変数、未設定なら `rag_chat.py` 内の既定値を使用します。

4. **挙動**
   - 起動時に `DEFAULT_QUESTION_TEXT`（デフォルト: ジゴキシンに関する質問）が自動実行され、回答が表示されます。
   - 続けてプロンプト `質問>` が表示され、自由に質問できます。`exit` / `quit` / `q` で終了。
   - 質問と取得チャンクの要約が OpenAI Chat API に渡され、臨床向けの日本語回答が生成されます。

## ディレクトリ構成

```
pgvector-local/
├── docker-compose.yml    # Docker Compose設定
├── init/
│   └── 01_init.sql      # 初期化SQL（拡張機能・テーブル定義）
├── examples/
│   └── seed_and_query.py # サンプルデータ投入＆検索スクリプト（numpy必要）
├── init_data.py          # サンプルデータ投入スクリプト（簡易版、numpy不要）
├── import_sql.py          # 既存SQLファイル投入スクリプト（JCS2013_ogawah_h.sql用）
├── rag_vector.py         # RAG検索ツール（pgvector版、chunksテーブル対応）
└── README.md            # このファイル
```

## 📖 詳細な使い方

## 🐳 Dockerコンテナの完全ガイド

### 1. 新規立ち上げ（初回セットアップ）

**初めてDockerコンテナを立ち上げる場合:**

```bash
# 1. ディレクトリに移動
cd /home/kaitech/KaiTech/Medical-Guidelines/rag_min/exps/exp002/pgvector-local

# 2. Dockerコンテナを起動（バックグラウンドで実行）
sudo docker compose up -d

# 3. 起動確認（コンテナが "Up" 状態になっているか確認）
docker compose ps

# 4. ログで正常起動を確認（Ctrl+Cで終了）
docker compose logs -f db
```

**期待される動作:**
- コンテナが正常に起動する
- `init/01_init.sql` が自動実行され、pgvector拡張とテーブルが作成される
- ログに "database system is ready to accept connections" が表示される

**権限エラーが出る場合:**
```bash
# sudoを使用する場合
sudo docker compose up -d

# または、ユーザーをdockerグループに追加（再ログインが必要）
sudo usermod -aG docker $USER
```

### 2. 再起動（データを保持）

**コンテナを再起動する場合（データは保持されます）:**

```bash
# 方法1: 再起動コマンド（推奨）
docker compose restart

# 方法2: 停止→起動
docker compose stop
docker compose start

# 方法3: 完全に停止してから起動
docker compose down
docker compose up -d
```

**再起動が必要なケース:**
- 設定ファイル（`docker-compose.yml`）を変更した場合
- コンテナが不安定になった場合
- システム再起動後

**注意**: `docker compose restart` や `docker compose stop/start` はデータを保持します。

### 3. 更新・設定変更

#### 3.1 docker-compose.ymlの設定を変更した場合

```bash
# 1. コンテナを停止
docker compose down

# 2. 新しい設定で起動
docker compose up -d

# 3. 変更が反映されたか確認
docker compose ps
docker compose logs -f db
```

#### 3.2 PostgreSQL/pgvectorのイメージを更新する場合

```bash
# 1. 最新イメージを取得
docker compose pull

# 2. コンテナを再作成（データは保持）
docker compose up -d

# 3. 確認
docker compose ps
```

#### 3.3 初期化SQL（init/01_init.sql）を変更した場合

**重要**: 既存のデータベースには自動適用されません。以下のいずれかを実行:

**オプションA: 完全リセット（全データ削除）**
```bash
# データを削除して再初期化
docker compose down -v
docker compose up -d
```

**オプションB: 手動でSQLを実行**
```bash
# コンテナ内でpsqlに接続
docker exec -it pgvector-local psql -U pguser -d ragdb

# SQLファイルを実行
\i /docker-entrypoint-initdb.d/01_init.sql
# または、ホストから直接実行
docker exec -i pgvector-local psql -U pguser -d ragdb < init/01_init.sql
```

### 4. 状態確認

```bash
# コンテナの状態確認
docker compose ps

# ログの確認（リアルタイム）
docker compose logs -f db

# ログの確認（最新50行）
docker compose logs --tail=50 db

# コンテナのリソース使用状況
docker stats pgvector-local

# データベースへの接続テスト
docker exec -it pgvector-local psql -U pguser -d ragdb -c "SELECT version();"
```

### 5. 停止・削除

```bash
# コンテナを停止（データは保持）
docker compose stop

# コンテナを停止して削除（データは保持）
docker compose down

# コンテナとボリュームを完全削除（全データが消えます！）
docker compose down -v
```

**警告**: `docker compose down -v` はすべてのデータを削除します。実行前にバックアップを取ることを推奨します。

### 6. トラブル時の完全リセット

**問題が解決しない場合の完全リセット手順:**

```bash
# 1. コンテナとボリュームを完全削除
docker compose down -v

# 2. イメージも削除する場合（オプション）
docker rmi pgvector/pgvector:pg16

# 3. クリーンな状態から再起動
docker compose up -d

# 4. ログで正常起動を確認
docker compose logs -f db

# 5. データを再投入
python3 import_sql.py
# または
python3 init_data.py
```

### 7. よく使うコマンド一覧

| 操作 | コマンド | データ保持 |
|------|----------|-----------|
| 起動 | `docker compose up -d` | - |
| 停止 | `docker compose stop` | ✅ |
| 再起動 | `docker compose restart` | ✅ |
| 停止+削除 | `docker compose down` | ✅ |
| 完全削除 | `docker compose down -v` | ❌ |
| 状態確認 | `docker compose ps` | - |
| ログ確認 | `docker compose logs -f db` | - |
| イメージ更新 | `docker compose pull` | - |

### Dockerコンテナの操作（簡易版）

```bash
# 起動
docker compose up -d

# ログ確認
docker compose logs -f

# 状態確認
docker compose ps

# 停止
docker compose down

# データを削除して再初期化（全データが消えます）
docker compose down -v
docker compose up -d
```

**注意**: `docker compose down -v` はボリュームを削除するため、すべてのデータが消えます。

### psql接続（接続情報確認用）

**ホストのpsqlから接続:**
```bash
PGPASSWORD=pgpass psql -h 127.0.0.1 -p 5433 -U pguser -d ragdb
```

**コンテナ内から接続:**
```bash
docker exec -it pgvector-local psql -U pguser -d ragdb
```

**接続後、テーブル確認:**
```sql
-- テーブル一覧
\dt

-- データ件数確認
SELECT COUNT(*) FROM docs;

-- データ確認
SELECT doc_id, LEFT(content, 50) AS content FROM docs LIMIT 5;
```

### ベクトル検索の確認（psql内）

```sql
-- サンプルクエリ
SELECT doc_id, content,
       (embedding <=> '[0.1,0.2,...]'::vector) AS distance
FROM docs
ORDER BY embedding <=> '[0.1,0.2,...]'::vector
LIMIT 5;
```

## 実装メモ

### ダミー埋め込みについて

現在は外部API依存なしで検証できるよう、テキストから決定論的にダミー埋め込みを生成しています。

実際の使用時は以下のように置き換えます：

```python
# OpenAI API使用例
from openai import OpenAI
client = OpenAI()
response = client.embeddings.create(
    model="text-embedding-3-small",
    input=text
)
embedding = response.data[0].embedding
```

### 次元数の変更

他の埋め込みモデルを使用する場合（例: text-embedding-3-large = 3072次元）:

```sql
ALTER TABLE docs ALTER COLUMN embedding TYPE vector(3072);
-- インデックス再作成
DROP INDEX docs_embedding_ivfflat;
CREATE INDEX docs_embedding_ivfflat
  ON docs USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);
```

### パフォーマンス調整

```sql
-- 検索精度を上げる（速度は低下）
SET ivfflat.probes = 50;

-- 検索速度を優先（精度は低下）
SET ivfflat.probes = 5;
```

## 🔧 トラブルシューティング

### 接続エラー

**症状**: `connection failed` などのエラー

**確認方法:**
```bash
# 1. Dockerコンテナが起動しているか確認
docker compose ps

# 2. コンテナのログを確認
docker compose logs -f db

# 3. ポート5433が使用中でないか確認
lsof -i :5433

**注意**: 既存のPostgreSQLが5432を使用しているため、デフォルトで5433ポートを使用します
```

**解決方法:**
- コンテナが起動していない場合: `docker compose up -d`
- ポート競合の場合: `docker-compose.yml`でポート番号を変更

### データが見つからない

**症状**: `該当箇所なし` と表示される

**原因**: データベースにデータが入っていない可能性があります

**解決方法:**
```bash
# 方法1: 簡易版（推奨）
python3 init_data.py

# 方法2: 詳細版（numpyがインストール済みの場合）
cd examples
python3 seed_and_query.py
```

**psqlで直接確認:**
```sql
-- データ件数確認
SELECT COUNT(*) FROM docs;

-- データが0件の場合、上記スクリプトでサンプルデータを投入
```

### 認証エラー

**症状**: `password authentication failed`

**確認事項:**
- パスワードは `pgpass` です（ユーザー名: `pguser`）
- 接続URLが正しいか確認: `postgresql://pguser:pgpass@127.0.0.1:5433/ragdb`
- **ポート番号が5433**であることを確認（既存PostgreSQLと競合回避のため）

## 次のステップ

1. **実データ投入**: `build_guideline_sql.py` で生成したデータをベクトル化して投入
2. **実埋め込みAPI統合**: OpenAI API などで実際の埋め込みを生成
3. **ハイブリッド検索**: pgvector + pg_trgm の組み合わせで検索精度向上

