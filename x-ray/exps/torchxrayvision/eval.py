import torchxrayvision as xrv
import skimage
import torch
import torchvision
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.metrics import roc_auc_score
from tqdm import tqdm

# パスの設定
base_dir = Path(__file__).parent.parent.parent
csv_path = base_dir / "data" / "test" / "labels.csv"
images_dir = base_dir / "data" / "test" / "images"

# CSVを読み込む
df = pd.read_csv(csv_path)

# 病理ラベルの列名
pathology_columns = [
    'No Finding', 'Infiltration', 'Effusion', 'Atelectasis', 'Nodule',
    'Mass', 'Pneumothorax', 'Consolidation', 'Pleural_Thickening',
    'Cardiomegaly', 'Emphysema', 'Edema', 'Fibrosis', 'Pneumonia', 'Hernia'
]

# モデルを読み込む（一度だけ）
print("モデルを読み込んでいます...")
model = xrv.models.DenseNet(weights="densenet121-res224-all")
model.eval()

# モデルの病理名とCSVの列名のマッピング
pathology_mapping = {}
for model_pathology in model.pathologies:
    csv_name = model_pathology.replace('_', ' ').title().replace(' ', '_')
    if csv_name in pathology_columns:
        pathology_mapping[model_pathology] = csv_name
    elif model_pathology in pathology_columns:
        pathology_mapping[model_pathology] = model_pathology

# 画像処理用の変換を定義
transform = torchvision.transforms.Compose([
    xrv.datasets.XRayCenterCrop(),
    xrv.datasets.XRayResizer(224)
])

# 全画像の予測結果と真のラベルを保存するリスト
all_predictions = []  # [{image_filename: str, pathology: str, pred_score: float, true_label: int}, ...]
all_image_filenames = []

# 利用可能な画像を取得
print(f"\n画像を処理しています...")
print(f"総画像数: {len(df)}")

# 画像をバッチで処理
processed_count = 0
failed_count = 0

for idx in tqdm(range(len(df)), desc="画像処理中"):
    row = df.iloc[idx]
    image_filename = row['Image Index']
    image_path = images_dir / image_filename
    
    # 画像が存在するか確認
    if not image_path.exists():
        failed_count += 1
        continue
    
    try:
        # 画像を処理
        img = skimage.io.imread(str(image_path))
        img = xrv.datasets.normalize(img, 255)
        
        # Handle both grayscale (2D) and color (3D) images
        if len(img.shape) == 3:
            img = img.mean(2)
        img = img[None, ...]
        
        img = transform(img)
        img = torch.from_numpy(img)
        
        # 予測
        with torch.no_grad():
            outputs = model(img[None, ...])
        
        predictions = dict(zip(model.pathologies, outputs[0].detach().numpy()))
        
        # CSVから該当画像のラベルを取得
        image_row = df[df['Image Index'] == image_filename]
        if image_row.empty:
            failed_count += 1
            continue
        
        # 各病理について予測結果と真のラベルを保存
        for model_pathology in model.pathologies:
            if model_pathology in pathology_mapping:
                csv_column = pathology_mapping[model_pathology]
                true_label = int(image_row[csv_column].iloc[0])
                pred_score = float(predictions[model_pathology])
                
                all_predictions.append({
                    'Image Index': image_filename,
                    'Pathology': model_pathology,
                    'True Label': true_label,
                    'Prediction Score': pred_score
                })
        
        all_image_filenames.append(image_filename)
        processed_count += 1
        
    except Exception as e:
        failed_count += 1
        print(f"\n警告: 画像 '{image_filename}' の処理に失敗しました: {e}")
        continue

print(f"\n処理完了: {processed_count}枚成功, {failed_count}枚失敗")

# 予測結果をDataFrameに変換
results_df = pd.DataFrame(all_predictions)

if len(results_df) == 0:
    print("エラー: 処理された画像がありません")
    exit(1)

# 病理ごとにAUCを計算
print("\n" + "="*100)
print("病理別AUC評価結果")
print("="*100)

pathology_aucs = {}
pathology_stats = {}

for pathology in sorted(pathology_mapping.keys()):
    pathology_data = results_df[results_df['Pathology'] == pathology]
    
    if len(pathology_data) == 0:
        continue
    
    true_labels = pathology_data['True Label'].values
    pred_scores = pathology_data['Prediction Score'].values
    
    # AUCを計算（少なくとも1つのクラスが存在する必要がある）
    if len(np.unique(true_labels)) >= 2:
        try:
            auc = roc_auc_score(true_labels, pred_scores)
            pathology_aucs[pathology] = auc
        except ValueError as e:
            pathology_aucs[pathology] = np.nan
            print(f"警告: {pathology}のAUC計算に失敗: {e}")
    else:
        pathology_aucs[pathology] = np.nan
    
    # 統計情報を計算
    positive_count = int(np.sum(true_labels))
    negative_count = int(len(true_labels) - positive_count)
    pathology_stats[pathology] = {
        'positive': positive_count,
        'negative': negative_count,
        'total': len(true_labels)
    }

# AUC結果を表示
print(f"\n{'病理名':<30} {'AUC':<12} {'陽性例':<10} {'陰性例':<10} {'総数':<10}")
print("-"*100)

for pathology in sorted(pathology_aucs.keys()):
    auc = pathology_aucs[pathology]
    stats = pathology_stats[pathology]
    auc_str = f"{auc:.4f}" if not np.isnan(auc) else "N/A"
    print(f"{pathology:<30} {auc_str:<12} {stats['positive']:<10} {stats['negative']:<10} {stats['total']:<10}")

# 平均AUCを計算（NaNを除外）
valid_aucs = [auc for auc in pathology_aucs.values() if not np.isnan(auc)]
if valid_aucs:
    mean_auc = np.mean(valid_aucs)
    print(f"\n平均AUC (有効な病理のみ): {mean_auc:.4f} ({mean_auc*100:.2f}%)")
    print(f"有効な病理数: {len(valid_aucs)} / {len(pathology_aucs)}")

# 複数の閾値で評価（全画像の集計）
print("\n" + "="*100)
print("閾値別評価結果（全画像集計）")
print("="*100)

thresholds = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
threshold_results = []

for threshold in thresholds:
    # 全病理・全画像での集計
    total_tp = 0
    total_fp = 0
    total_fn = 0
    total_tn = 0
    total_correct = 0
    total_predictions = 0
    
    for pathology in pathology_mapping.keys():
        pathology_data = results_df[results_df['Pathology'] == pathology]
        if len(pathology_data) == 0:
            continue
        
        true_labels = pathology_data['True Label'].values
        pred_scores = pathology_data['Prediction Score'].values
        pred_labels = (pred_scores >= threshold).astype(int)
        
        for true_label, pred_label in zip(true_labels, pred_labels):
            total_predictions += 1
            if true_label == 1 and pred_label == 1:
                total_tp += 1
                total_correct += 1
            elif true_label == 0 and pred_label == 1:
                total_fp += 1
            elif true_label == 1 and pred_label == 0:
                total_fn += 1
            else:
                total_tn += 1
                total_correct += 1
    
    accuracy = total_correct / total_predictions if total_predictions > 0 else 0
    precision = total_tp / (total_tp + total_fp) if (total_tp + total_fp) > 0 else 0
    recall = total_tp / (total_tp + total_fn) if (total_tp + total_fn) > 0 else 0
    f1_score = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
    
    threshold_results.append({
        'threshold': threshold,
        'accuracy': accuracy,
        'precision': precision,
        'recall': recall,
        'f1': f1_score,
        'tp': total_tp,
        'fp': total_fp,
        'fn': total_fn,
        'tn': total_tn
    })

# 閾値別結果を表示
print(f"\n{'閾値':<8} {'Accuracy':<12} {'Precision':<12} {'Recall':<12} {'F1 Score':<12} {'TP':<8} {'FP':<8} {'FN':<8} {'TN':<8}")
print("-"*100)

best_f1 = 0
best_threshold = 0
best_accuracy = 0
best_threshold_acc = 0

for result in threshold_results:
    threshold = result['threshold']
    accuracy = result['accuracy']
    precision = result['precision']
    recall = result['recall']
    f1_score = result['f1']
    
    marker = ""
    if f1_score > best_f1:
        best_f1 = f1_score
        best_threshold = threshold
        marker = " ← Best F1"
    if accuracy > best_accuracy:
        best_accuracy = accuracy
        best_threshold_acc = threshold
    
    print(f"{threshold:<8.1f} {accuracy:<12.4f} {precision:<12.4f} {recall:<12.4f} {f1_score:<12.4f} "
          f"{result['tp']:<8} {result['fp']:<8} {result['fn']:<8} {result['tn']:<8}{marker}")

print("-"*100)

# 最適な閾値の詳細を表示
best_result = next(r for r in threshold_results if r['threshold'] == best_threshold)
print(f"\n最適な閾値（F1 Score基準）: {best_threshold:.1f}")
print(f"  F1 Score: {best_f1:.4f} ({best_f1*100:.2f}%)")
print(f"  Accuracy: {best_result['accuracy']:.4f} ({best_result['accuracy']*100:.2f}%)")
print(f"  Precision: {best_result['precision']:.4f} ({best_result['precision']*100:.2f}%)")
print(f"  Recall: {best_result['recall']:.4f} ({best_result['recall']*100:.2f}%)")

if best_threshold_acc != best_threshold:
    best_acc_result = next(r for r in threshold_results if r['threshold'] == best_threshold_acc)
    print(f"\n最適な閾値（Accuracy基準）: {best_threshold_acc:.1f}")
    print(f"  Accuracy: {best_accuracy:.4f} ({best_accuracy*100:.2f}%)")
    print(f"  F1 Score: {best_acc_result['f1']:.4f} ({best_acc_result['f1']*100:.2f}%)")
    print(f"  Precision: {best_acc_result['precision']:.4f} ({best_acc_result['precision']*100:.2f}%)")
    print(f"  Recall: {best_acc_result['recall']:.4f} ({best_acc_result['recall']*100:.2f}%)")

# 最適な閾値で各病理の詳細を表示
print("\n" + "="*100)
print(f"病理別詳細結果（閾値: {best_threshold:.1f}）")
print("="*100)

pathology_details = []

for pathology in sorted(pathology_mapping.keys()):
    pathology_data = results_df[results_df['Pathology'] == pathology]
    if len(pathology_data) == 0:
        continue
    
    true_labels = pathology_data['True Label'].values
    pred_scores = pathology_data['Prediction Score'].values
    pred_labels = (pred_scores >= best_threshold).astype(int)
    
    tp = np.sum((true_labels == 1) & (pred_labels == 1))
    fp = np.sum((true_labels == 0) & (pred_labels == 1))
    fn = np.sum((true_labels == 1) & (pred_labels == 0))
    tn = np.sum((true_labels == 0) & (pred_labels == 0))
    
    accuracy = (tp + tn) / len(true_labels) if len(true_labels) > 0 else 0
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0
    f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0
    auc = pathology_aucs.get(pathology, np.nan)
    
    pathology_details.append({
        'Pathology': pathology,
        'AUC': auc if not np.isnan(auc) else None,
        'Accuracy': accuracy,
        'Precision': precision,
        'Recall': recall,
        'F1 Score': f1,
        'TP': int(tp),
        'FP': int(fp),
        'FN': int(fn),
        'TN': int(tn),
        'Total': len(true_labels),
        'Positive': int(np.sum(true_labels)),
        'Negative': int(len(true_labels) - np.sum(true_labels))
    })

# 病理別詳細を表示
print(f"\n{'病理名':<30} {'AUC':<10} {'Accuracy':<10} {'Precision':<10} {'Recall':<10} {'F1':<10} {'TP':<6} {'FP':<6} {'FN':<6} {'TN':<6}")
print("-"*100)

for detail in pathology_details:
    auc_str = f"{detail['AUC']:.4f}" if detail['AUC'] is not None else "N/A"
    print(f"{detail['Pathology']:<30} {auc_str:<10} {detail['Accuracy']:<10.4f} {detail['Precision']:<10.4f} "
          f"{detail['Recall']:<10.4f} {detail['F1 Score']:<10.4f} {detail['TP']:<6} {detail['FP']:<6} "
          f"{detail['FN']:<6} {detail['TN']:<6}")

print("="*100)

# 結果をCSVに保存
output_dir = Path(__file__).parent / "output"
output_dir.mkdir(exist_ok=True)

# 1. 全予測結果を保存
all_results_path = output_dir / "all_predictions.csv"
results_df.to_csv(all_results_path, index=False, encoding='utf-8-sig')
print(f"\n全予測結果を保存しました: {all_results_path}")

# 2. AUC結果を保存
auc_results = []
for pathology in sorted(pathology_aucs.keys()):
    auc = pathology_aucs[pathology]
    stats = pathology_stats[pathology]
    auc_results.append({
        'Pathology': pathology,
        'AUC': auc if not np.isnan(auc) else None,
        'Positive Cases': stats['positive'],
        'Negative Cases': stats['negative'],
        'Total Cases': stats['total']
    })

auc_df = pd.DataFrame(auc_results)
auc_path = output_dir / "auc_results.csv"
auc_df.to_csv(auc_path, index=False, encoding='utf-8-sig')
print(f"AUC結果を保存しました: {auc_path}")

# 3. 閾値別結果を保存
threshold_df = pd.DataFrame(threshold_results)
threshold_path = output_dir / "threshold_results.csv"
threshold_df.to_csv(threshold_path, index=False, encoding='utf-8-sig')
print(f"閾値別結果を保存しました: {threshold_path}")

# 4. 病理別詳細結果を保存
pathology_detail_df = pd.DataFrame(pathology_details)
pathology_detail_path = output_dir / "pathology_details.csv"
pathology_detail_df.to_csv(pathology_detail_path, index=False, encoding='utf-8-sig')
print(f"病理別詳細結果を保存しました: {pathology_detail_path}")

# 5. サマリーを保存
summary = {
    'Total Images Processed': processed_count,
    'Failed Images': failed_count,
    'Mean AUC': mean_auc if valid_aucs else None,
    'Valid Pathology Count': len(valid_aucs),
    'Total Pathology Count': len(pathology_aucs),
    'Best Threshold (F1)': best_threshold,
    'Best F1 Score': best_f1,
    'Best Threshold (Accuracy)': best_threshold_acc,
    'Best Accuracy': best_accuracy
}

summary_df = pd.DataFrame([summary])
summary_path = output_dir / "summary.csv"
summary_df.to_csv(summary_path, index=False, encoding='utf-8-sig')
print(f"サマリーを保存しました: {summary_path}")

print("\n" + "="*100)
print("評価完了")
print("="*100)
