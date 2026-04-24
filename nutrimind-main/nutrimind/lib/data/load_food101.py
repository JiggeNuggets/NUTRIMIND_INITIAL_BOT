from datasets import load_dataset

# Load only the dataset info without downloading data
ds = load_dataset("ethz/food101", split="train[:1]")  # Load just one example to get features

# Print the dataset info
print("Dataset info:", ds)

# Print the class names
print("Classes:", ds.features['label'].names)