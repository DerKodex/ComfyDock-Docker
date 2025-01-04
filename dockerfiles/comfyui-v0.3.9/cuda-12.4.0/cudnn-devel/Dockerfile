FROM nvidia/cuda:12.4.0-cudnn-devel-ubuntu22.04

# Labels
LABEL comfui_version="v0.3.9"
LABEL cuda_version="12.4.0"
LABEL pytorch_version="2.5.1"
LABEL comfyui_manager_version="2.55.5"

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

# Install system dependencies and set up glvnd
RUN apt update && \
    apt install -y --no-install-recommends \
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

# Install uv and create a virtual environment
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
RUN uv venv --python 3.12
ENV VIRTUAL_ENV=/app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# Install Python dependencies
RUN uv pip install --upgrade pip && \
    uv pip install torch==2.5.1 \
        torchvision==0.20.1 \
        torchaudio==2.5.1 \
        --index-url https://download.pytorch.org/whl/cu124 && \
    uv pip install -U xformers==0.0.28.post3

# Signal Python we're in Docker
ENV WINDOW_BACKEND="headless"
ENV DOCKER_RUNTIME="1"

# Clone and set up ComfyUI
RUN git clone --branch v0.3.9 https://github.com/comfyanonymous/ComfyUI.git

# Set working directory for ComfyUI
WORKDIR /app/ComfyUI

# Install ComfyUI dependencies and ComfyUI-Manager
RUN uv pip install -r requirements.txt && \
    git clone --branch 2.55.5 \
        https://github.com/ltdrdata/ComfyUI-Manager.git \
        /app/ComfyUI/custom_nodes/ComfyUI-Manager && \
    uv pip install -r /app/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt && \
    uv cache clean

# Expose port 8188
EXPOSE 8188

# Set entrypoint with required arguments
ENTRYPOINT ["uv", "run", "python", "/app/ComfyUI/main.py", "--listen", "0.0.0.0"]
CMD ["--port", "8188"]
