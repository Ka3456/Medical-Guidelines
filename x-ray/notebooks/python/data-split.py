import pandas as pd
import numpy as np
from pathlib import Path
import shutil


def split_data_by_patient_id(
    csv_path: str,
    output_dir: str,
    train_ratio: float = 0.7,
    eval_ratio: float = 0.2,
    test_ratio: float = 0.1,
    copy_images: bool = True,
    random_seed: int = 42
):
    """
    Split dataset by patient ID into train/eval/test sets with specified ratios.
    
    Parameters
    ----------
    csv_path : str
        Path to the CSV file containing labels and patient IDs
    output_dir : str
        Base output directory (will create train/, eval/, test/ subdirectories)
    train_ratio : float
        Ratio for training set (default: 0.7)
    eval_ratio : float
        Ratio for evaluation set (default: 0.2)
    test_ratio : float
        Ratio for test set (default: 0.1)
    copy_images : bool
        Whether to copy image files to respective directories (default: True)
    random_seed : int
        Random seed for reproducibility (default: 42)
    """
    # Validate ratios
    assert abs(train_ratio + eval_ratio + test_ratio - 1.0) < 1e-6, \
        "Ratios must sum to 1.0"
    
    # Set random seed
    np.random.seed(random_seed)
    
    # Read CSV
    print(f"Reading CSV from: {csv_path}")
    df = pd.read_csv(csv_path)
    print(f"Total rows: {len(df)}")
    
    # Get unique patient IDs
    unique_patients = df['Patient ID'].unique()
    print(f"Unique patients: {len(unique_patients)}")
    
    # Shuffle patient IDs randomly
    shuffled_patients = unique_patients.copy()
    np.random.shuffle(shuffled_patients)
    
    # Calculate split indices for 7:2:1 ratio
    n_patients = len(shuffled_patients)
    n_train = int(n_patients * train_ratio)
    n_eval = int(n_patients * eval_ratio)
    # n_test = n_patients - n_train - n_eval (remaining patients)
    
    # Split patient IDs into train/eval/test
    train_patients = set(shuffled_patients[:n_train])
    eval_patients = set(shuffled_patients[n_train:n_train + n_eval])
    test_patients = set(shuffled_patients[n_train + n_eval:])
    
    print(f"\nSplit distribution:")
    print(f"  Train patients: {len(train_patients)} ({len(train_patients)/len(unique_patients)*100:.1f}%)")
    print(f"  Eval patients: {len(eval_patients)} ({len(eval_patients)/len(unique_patients)*100:.1f}%)")
    print(f"  Test patients: {len(test_patients)} ({len(test_patients)/len(unique_patients)*100:.1f}%)")
    
    # Create output directories
    output_path = Path(output_dir)
    train_dir = output_path / "train"
    eval_dir = output_path / "eval"
    test_dir = output_path / "test"
    
    for dir_path in [train_dir, eval_dir, test_dir]:
        dir_path.mkdir(parents=True, exist_ok=True)
        if copy_images:
            (dir_path / "images").mkdir(parents=True, exist_ok=True)
    
    # Split dataframes by patient ID
    train_df = df[df['Patient ID'].isin(train_patients)].copy()
    eval_df = df[df['Patient ID'].isin(eval_patients)].copy()
    test_df = df[df['Patient ID'].isin(test_patients)].copy()
    
    print(f"\nData distribution:")
    print(f"  Train rows: {len(train_df)} ({len(train_df)/len(df)*100:.1f}%)")
    print(f"  Eval rows: {len(eval_df)} ({len(eval_df)/len(df)*100:.1f}%)")
    print(f"  Test rows: {len(test_df)} ({len(test_df)/len(df)*100:.1f}%)")
    
    # Save CSV files
    train_csv = train_dir / "labels.csv"
    eval_csv = eval_dir / "labels.csv"
    test_csv = test_dir / "labels.csv"
    
    train_df.to_csv(train_csv, index=False)
    eval_df.to_csv(eval_csv, index=False)
    test_df.to_csv(test_csv, index=False)
    
    print(f"\nCSV files saved:")
    print(f"  {train_csv}")
    print(f"  {eval_csv}")
    print(f"  {test_csv}")
    
    # Copy images if requested
    if copy_images:
        csv_parent = Path(csv_path).parent
        images_source = csv_parent / "images"
        
        if images_source.exists():
            print(f"\nCopying images from: {images_source}")
            
            # Copy train images
            train_images = train_df['Image Index'].tolist()
            print(f"  Copying {len(train_images)} train images...")
            for img_name in train_images:
                src = images_source / img_name
                dst = train_dir / "images" / img_name
                if src.exists():
                    shutil.copy2(src, dst)
            
            # Copy eval images
            eval_images = eval_df['Image Index'].tolist()
            print(f"  Copying {len(eval_images)} eval images...")
            for img_name in eval_images:
                src = images_source / img_name
                dst = eval_dir / "images" / img_name
                if src.exists():
                    shutil.copy2(src, dst)
            
            # Copy test images
            test_images = test_df['Image Index'].tolist()
            print(f"  Copying {len(test_images)} test images...")
            for img_name in test_images:
                src = images_source / img_name
                dst = test_dir / "images" / img_name
                if src.exists():
                    shutil.copy2(src, dst)
            
            print("  Image copying completed!")
        else:
            print(f"\nWarning: Images directory not found at {images_source}")
            print("  Skipping image copying.")
    
    print("\nData splitting completed successfully!")
    return train_df, eval_df, test_df


if __name__ == "__main__":
    # Paths
    csv_path = "/home/kaitech/KaiTech/Medical-Guidelines/x-ray/raw_data/3000data/labels_subset_1000.csv"
    output_dir = "/home/kaitech/KaiTech/Medical-Guidelines/x-ray/data"
    
    # Split data with 7:2:1 ratio
    split_data_by_patient_id(
        csv_path=csv_path,
        output_dir=output_dir,
        train_ratio=0.7,
        eval_ratio=0.2,
        test_ratio=0.1,
        copy_images=True,
        random_seed=42
    )

