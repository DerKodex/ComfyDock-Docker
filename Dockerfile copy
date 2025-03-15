FROM ubuntu:22.04

# Set working directory
WORKDIR /app

# Set non-interactive frontend
ENV DEBIAN_FRONTEND=noninteractive

# Basic required configuration
ENV NVIDIA_DRIVER_CAPABILITIES="all"
ENV NVIDIA_VISIBLE_DEVICES="all"

# Don't use llvmpipe (Software Rendering) on WSL
ENV MESA_D3D12_DEFAULT_ADAPTER_NAME="NVIDIA"
ENV LD_LIBRARY_PATH=/usr/lib/wsl/lib
ENV WINDOW_BACKEND="headless"
ENV DOCKER_RUNTIME="1"

# Install system dependencies and set up glvnd
RUN apt update && \
    apt install -y --no-install-recommends \
        ca-certificates \
        libegl1-mesa-dev \
        libglvnd-dev \
        libglvnd0 \
        git \
        libgl1-mesa-glx \
        libglib2.0-0 \
        ffmpeg && \
    mkdir -p /usr/share/glvnd/egl_vendor.d && \
    echo '{"file_format_version":"1.0.0","ICD":{"library_path":"/usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0"}}' > \
        /usr/share/glvnd/egl_vendor.d/10_nvidia.json && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Arguments
ARG COMFYUI_VERSION=master
ARG CUDA_VERSION=cu124
ARG PYTHON_VERSION=3.12
ARG PYTORCH_VERSION=stable

# Labels
LABEL comfui_version=$COMFYUI_VERSION \
    cuda_version=$CUDA_VERSION \
    python_version=$PYTHON_VERSION \
    pytorch_version=$PYTORCH_VERSION

# Set UV environment variables:
# - UV_LINK_MODE=copy: Copy dependencies instead of symlinking
# - UV_COMPILE_BYTECODE=1: Compile Python bytecode during installation
# - UV_PROJECT_ENVIRONMENT: Specify virtual environment location
ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PROJECT_ENVIRONMENT=/app/.venv

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Create Python virtual environment
RUN --mount=type=cache,target=/root/.cache \
    uv venv /app/.venv --python ${PYTHON_VERSION}

# Make the virtual environment the default Python environment
ENV PATH="/app/.venv/bin:$PATH"

# Install Python dependencies
# Use a cache mount to speed up the installation
RUN --mount=type=cache,target=/root/.cache \
    if [ "${PYTORCH_VERSION}" = "stable" ]; then \
        uv pip install torch torchvision torchaudio \
            --index-url "https://download.pytorch.org/whl/${CUDA_VERSION}"; \
    elif [ "${PYTORCH_VERSION}" = "nightly" ]; then \
        uv pip install --pre torch torchvision torchaudio \
            --index-url "https://download.pytorch.org/whl/nightly/${CUDA_VERSION}"; \
    fi && \
    uv pip install -U xformers --index-url "https://download.pytorch.org/whl/${CUDA_VERSION}" && \
    uv pip install --upgrade pip


# Clone and set up ComfyUI
RUN git clone --branch "${COMFYUI_VERSION}" https://github.com/comfyanonymous/ComfyUI.git

# Set working directory for ComfyUI
WORKDIR /app/ComfyUI

# Install ComfyUI dependencies and ComfyUI-Manager
RUN --mount=type=cache,target=/root/.cache \
    uv pip install -r requirements.txt && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git \
        /app/ComfyUI/custom_nodes/ComfyUI-Manager && \
    uv pip install -r /app/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt

# Expose port 8188
EXPOSE 8188

# Set entrypoint with required arguments
ENTRYPOINT ["uv", "run", "python", "/app/ComfyUI/main.py", "--listen", "0.0.0.0"]
CMD ["--port", "8188"]
