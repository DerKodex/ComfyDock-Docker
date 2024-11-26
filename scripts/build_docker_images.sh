#!/bin/bash

# Directory containing the Dockerfiles
DOCKERFILES_DIR="dockerfiles"

build_docker_image() {
    local dockerfile_path=$1
    # Extract the comfyui version from the parent directory
    comfyui_version=$(basename "$(dirname "$(dirname "$dockerfile_path")")" | cut -d'-' -f2)
    cuda_pytorch_dir=$(dirname "$dockerfile_path")
    cuda_version=$(basename "$cuda_pytorch_dir" | cut -d'-' -f1 | sed 's/cuda//')
    pytorch_version=$(basename "$cuda_pytorch_dir" | cut -d'-' -f2 | sed 's/pytorch//')

    # Construct the image name
    image_name="comfyui:${comfyui_version}-base-cuda${cuda_version}-pytorch${pytorch_version}"

    # Build the Docker image
    docker build -t "$image_name" -f "$dockerfile_path" "$cuda_pytorch_dir"

    echo "Built image: $image_name"
}

# Function to compare version numbers
version_greater() {
    [ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" ]
}

# Check if a specific directory was provided
if [ $# -eq 1 ]; then
    if [ -f "$1" ]; then
        build_docker_image "$1"
    else
        echo "Error: Dockerfile '$1' does not exist"
        exit 1
    fi
else
    # Original behavior: iterate over each subdirectory
    largest_version=""
    largest_image_name=""

    for dir in "$DOCKERFILES_DIR"/*/; do
        dockerfile_path=$(find "$dir" -name "dockerfile")
        if [ -f "$dockerfile_path" ]; then
            # Extract the comfyui version, cuda version, and pytorch version
            comfyui_version=$(basename "$(dirname "$dir")" | cut -d'-' -f2)
            cuda_version=$(basename "$dir" | cut -d'-' -f1 | sed 's/cuda//')
            pytorch_version=$(basename "$dir" | cut -d'-' -f2 | sed 's/pytorch//')

            build_docker_image "$dockerfile_path"

            # Check if this is the largest version
            if [ -z "$largest_version" ] || version_greater "$comfyui_version" "$largest_version"; then
                largest_version="$comfyui_version"
                largest_image_name="comfyui:${comfyui_version}-base-cuda${cuda_version}-pytorch${pytorch_version}"
            fi
        fi
    done

    # Tag the largest version as latest
    if [ -n "$largest_image_name" ]; then
        docker tag "$largest_image_name" "comfyui:latest"
        echo "Tagged $largest_image_name as comfyui:latest"
    fi
fi