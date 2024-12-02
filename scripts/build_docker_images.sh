#!/bin/bash

# Directory containing the Dockerfiles
DOCKERFILES_DIR="dockerfiles"
IMAGE_NAME="comfyui-env"

build_docker_image() {
    local dockerfile_path=$1
    echo $dockerfile_path
    # Extract the comfyui version from the parent directory
    comfyui_version=$(basename "$(dirname "$dockerfile_path")" | sed 's/comfyui-//')
    echo $comfyui_version
    comfyui_version_dir=$(dirname "$dockerfile_path")
    echo $comfyui_version_dir

    # Construct the image name
    image_name="${IMAGE_NAME}:${comfyui_version}"

    # Build the Docker image
    docker build -t "$image_name" -f "$dockerfile_path" "$comfyui_version_dir"

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
            # Extract the comfyui version
            comfyui_version=$(basename "$(dirname "$dir")" | cut -d'-' -f2)

            build_docker_image "$dockerfile_path"

            # Check if this is the largest version
            if [ -z "$largest_version" ] || version_greater "$comfyui_version" "$largest_version"; then
                largest_version="$comfyui_version"
                largest_image_name="${IMAGE_NAME}:${comfyui_version}"
            fi
        fi
    done

    # Tag the largest version as latest
    if [ -n "$largest_image_name" ]; then
        docker tag "$largest_image_name" "${IMAGE_NAME}:latest"
        echo "Tagged $largest_image_name as ${IMAGE_NAME}:latest"
    fi
fi