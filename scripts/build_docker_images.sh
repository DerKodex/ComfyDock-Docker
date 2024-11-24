#!/bin/bash

# Directory containing the Dockerfiles
DOCKERFILES_DIR="dockerfiles"

# Iterate over each subdirectory in the dockerfiles directory
for dir in "$DOCKERFILES_DIR"/*/; do
    # Extract the comfyui version, cuda version, and pytorch version from the directory path
    comfyui_version=$(basename "$dir" | cut -d'-' -f2)
    cuda_pytorch_dir=$(find "$dir" -type d -name "cuda*-pytorch*")
    cuda_version=$(basename "$cuda_pytorch_dir" | cut -d'-' -f1 | sed 's/cuda//')
    pytorch_version=$(basename "$cuda_pytorch_dir" | cut -d'-' -f2 | sed 's/pytorch//')

    # Construct the image name
    image_name="comfyui-${comfyui_version}-base-cuda${cuda_version}-pytorch${pytorch_version}:latest"

    # Build the Docker image
    docker build -t "$image_name" "$cuda_pytorch_dir"

    echo "Built image: $image_name"
done