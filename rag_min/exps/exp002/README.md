# PDFから章情報を抽出 (exp002)

## 概要
`getchapter.py`は、PDFファイルから章情報を抽出して`chapter.json`形式で出力するスクリプトです。

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

