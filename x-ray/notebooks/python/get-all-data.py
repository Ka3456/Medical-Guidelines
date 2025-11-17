from pathlib import Path

import kagglehub


def download_nih_dataset() -> Path:
    """
    Download the NIH Chest X-ray dataset via kagglehub.

    Returns
    -------
    Path
        Directory containing the downloaded files.
    """
    path = Path(kagglehub.dataset_download("nih-chest-xrays/data"))
    print("Path to dataset files:", path)
    return path


if __name__ == "__main__":
    download_nih_dataset()
