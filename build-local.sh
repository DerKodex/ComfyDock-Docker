#!/bin/bash
set -e

# Default values
COMFYUI_VERSION=${COMFYUI_VERSION:-"master"}
PYTHON_VERSION=${PYTHON_VERSION:-"3.12"}
CUDA_VERSION=${CUDA_VERSION:-"12.4"}
PYTORCH_VERSION=${PYTORCH_VERSION:-"stable"}
TAG_NAME="local"
DOCKERFILE=${DOCKERFILE:-"Dockerfile"}
# Help function
function show_help {
    echo "Build a local ComfyDock Docker image"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --comfyui VERSION   ComfyUI version/branch (default: master)"
    echo "  -p, --python VERSION    Python version (default: 3.12)"
    echo "  -g, --cuda VERSION      CUDA version (default: 12.4)"
    echo "  -t, --pytorch VERSION   PyTorch version (default: stable)"
    echo "  -n, --name TAG          Custom tag name (default: local)"
    echo "  -f, --file FILE         Dockerfile name (default: Dockerfile)"
    echo "  -h, --help              Show this help"
    echo ""
    echo "Example:"
    echo "  $0 --comfyui 1.3.0 --python 3.10 --cuda 11.8 --pytorch nightly"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--comfyui)
            COMFYUI_VERSION="$2"
            shift 2
            ;;
        -p|--python)
            PYTHON_VERSION="$2"
            shift 2
            ;;
        -g|--cuda)
            CUDA_VERSION="$2"
            shift 2
            ;;
        -t|--pytorch)
            PYTORCH_VERSION="$2"
            shift 2
            ;;
        -n|--name)
            TAG_NAME="$2"
            shift 2
            ;;
        -f|--file)
            DOCKERFILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Convert CUDA version to expected format (e.g., 12.4 -> cu124)
CU_STRIPPED="${CUDA_VERSION//./}"
CUDA_ARG="cu${CU_STRIPPED}"

# Format the tag name
if [ "$TAG_NAME" = "local" ]; then
    TAG="${COMFYUI_VERSION}-py${PYTHON_VERSION}-cuda${CUDA_VERSION}-pt${PYTORCH_VERSION}"
else
    TAG="$TAG_NAME"
fi

IMAGE_NAME="comfydock-env:${TAG}"

echo "Building ComfyDock image with the following configuration:"
echo "ComfyUI Version: $COMFYUI_VERSION"
echo "Python Version:  $PYTHON_VERSION"
echo "CUDA Version:    $CUDA_VERSION (formatted as $CUDA_ARG)"
echo "PyTorch Version: $PYTORCH_VERSION"
echo "Image tag:       $IMAGE_NAME"
echo ""
echo "Starting build..."

# Build the Docker image
docker build \
  --build-arg COMFYUI_VERSION="${COMFYUI_VERSION}" \
  --build-arg CUDA_VERSION="${CUDA_ARG}" \
  --build-arg PYTHON_VERSION="${PYTHON_VERSION}" \
  --build-arg PYTORCH_VERSION="${PYTORCH_VERSION}" \
  -t "$IMAGE_NAME" -f "$DOCKERFILE" .

echo ""
echo "Build complete! Your image is available as: $IMAGE_NAME"
echo ""
echo "You can run it with: docker run --gpus all -p 8188:8188 $IMAGE_NAME"