"""
Copyright © 2025 Devin B. Royal. All Rights Reserved.
"""
# small utilities for data preprocessing and model serialization
import numpy as np

def normalize_input(x):
    arr = np.array(x, dtype=np.float32)
    if arr.size == 0: return arr
    mean = arr.mean()
    std = arr.std() if arr.std() > 0 else 1.0
    return ((arr - mean) / std).astype(np.float32)
