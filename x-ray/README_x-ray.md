# X-ray Dataset

## データ分布

### 全体統計
- **総データ行数**: 3,275
- **ユニーク患者数**: 2,531

### データセット分割（患者ID単位、7:2:1比率）

#### 患者数による分割
- **Train**: 1,771患者 (70.0%)
- **Eval**: 506患者 (20.0%)
- **Test**: 254患者 (10.0%)

#### データ行数による分割
- **Train**: 2,328行 (71.1%)
- **Eval**: 626行 (19.1%)
- **Test**: 321行 (9.8%)

### データディレクトリ構造
```
data/
├── train/
│   ├── labels.csv
│   └── images/
├── eval/
│   ├── labels.csv
│   └── images/
└── test/
    ├── labels.csv
    └── images/
```

### データ分割方法
- 患者ID単位で分割（同一患者のデータが複数のセットに分かれないように）
- ランダムシード: 42
- 分割比率: Train 70% / Eval 20% / Test 10%

### データ分割スクリプト
`notebooks/python/data-split.py` を使用してデータを分割しました。

## ベースモデル評価結果（TorchXRayVision）

### 評価設定
- **モデル**: TorchXRayVision ベースモデル
- **評価データ**: Testセット（321画像）
- **評価スクリプト**: `exps/torchxrayvision/eval.py`

### 全体結果
- **平均AUC**: 0.7287 (72.87%)
- **最適な閾値（F1 Score基準）**: 0.6
  - F1 Score: 0.2730 (27.30%)
  - Accuracy: 0.8838 (88.38%)
  - Precision: 0.3920 (39.20%)
  - Recall: 0.2094 (20.94%)
- **最適な閾値（Accuracy基準）**: 0.8
  - Accuracy: 0.8968 (89.68%)
  - F1 Score: 0.0645 (6.45%)

### 病理別AUC結果

| 病理名 | AUC | 陽性例 | 陰性例 | 総数 |
|--------|-----|--------|--------|------|
| Cardiomegaly | 0.9268 | 16 | 305 | 321 |
| Hernia | 0.8991 | 4 | 317 | 321 |
| Mass | 0.8440 | 33 | 288 | 321 |
| Edema | 0.8278 | 38 | 283 | 321 |
| Pleural_Thickening | 0.7840 | 12 | 309 | 321 |
| Effusion | 0.7525 | 48 | 273 | 321 |
| Emphysema | 0.7034 | 22 | 299 | 321 |
| Consolidation | 0.6847 | 30 | 291 | 321 |
| Pneumothorax | 0.6709 | 24 | 297 | 321 |
| Atelectasis | 0.6609 | 47 | 274 | 321 |
| Pneumonia | 0.6551 | 89 | 232 | 321 |
| Infiltration | 0.6517 | 71 | 250 | 321 |
| Nodule | 0.5642 | 23 | 298 | 321 |
| Fibrosis | 0.5765 | 11 | 310 | 321 |

### 評価結果ファイル
評価結果は `exps/torchxrayvision/output/` に保存されています：
- `all_predictions.csv` - 全予測結果
- `auc_results.csv` - AUC結果
- `threshold_results.csv` - 閾値別結果
- `pathology_details.csv` - 病理別詳細結果
- `summary.csv` - サマリー

