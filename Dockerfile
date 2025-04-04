FROM ubuntu:22.04

# 1) Install system dependencies and set up glvnd (as root).
#    We do this *before* switching to a non-root user, because apt needs root.
WORKDIR /app
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt install -y --no-install-recommends \
        ca-certificates \
        libegl1-mesa-dev \
        libglvnd-dev \
        libglvnd0 \
        git \
        libgl1-mesa-glx \
        libglib2.0-0 \
        ffmpeg \
        sudo && \
    mkdir -p /usr/share/glvnd/egl_vendor.d && \
    echo '{"file_format_version":"1.0.0","ICD":{"library_path":"/usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0"}}' \
        >/usr/share/glvnd/egl_vendor.d/10_nvidia.json && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 2) Create a placeholder user 'comfy' with some default UID/GID (1024).
#    You can pick any default UID/GID. We'll adjust it again at runtime if needed.
RUN umask 000 && groupadd -g 1024 comfy \
    && useradd -m -u 1024 -g comfy -s /bin/bash comfy \
    && mkdir -p /home/comfy/.cache \
    && chmod -R 777 /home/comfy/.cache \
    && mkdir -p /app \
    && chmod -R 777 /app \
    && echo "comfy ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/comfy \
    && chmod 0440 /etc/sudoers.d/comfy

# 3) Switch to the comfy user. From now on, everything we install will belong to comfy by default.
USER comfy
WORKDIR /app

# 4) Basic environment variables
ENV NVIDIA_DRIVER_CAPABILITIES="all"
ENV NVIDIA_VISIBLE_DEVICES="all"
ENV MESA_D3D12_DEFAULT_ADAPTER_NAME="NVIDIA"
ENV LD_LIBRARY_PATH=/usr/lib/wsl/lib
ENV WINDOW_BACKEND="headless"
ENV DOCKER_RUNTIME="1"

# 5) UV environment variables
ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    UV_CACHE_DIR=/home/comfy/.cache/uv \
    UV_HTTP_TIMEOUT=300

# 6) Copy uv from a multi-stage build (still as comfy, that's OK)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# 7) Create Python virtual environment (will belong to 'comfy' user).
ARG PYTHON_VERSION=3.12
RUN --mount=type=cache,target=/home/comfy/.cache,uid=1024,gid=1024 \
    umask 000 && \
    uv venv /app/.venv --python ${PYTHON_VERSION} && \
    sudo chmod -R 777 /app/.venv

# 8) Make the virtual environment the default Python environment
ENV PATH="/app/.venv/bin:$PATH"

# 9) Install PyTorch + other Python dependencies in the venv (still as comfy).
ARG CUDA_VERSION=cu124
ARG PYTORCH_VERSION=stable
RUN --mount=type=cache,target=/home/comfy/.cache,uid=1024,gid=1024 \
    if [ "${PYTORCH_VERSION}" = "stable" ]; then \
        uv pip install torch torchvision torchaudio \
            --index-url "https://download.pytorch.org/whl/${CUDA_VERSION}"; \
    elif [ "${PYTORCH_VERSION}" = "nightly" ]; then \
        uv pip install --pre torch torchvision torchaudio \
            --index-url "https://download.pytorch.org/whl/nightly/${CUDA_VERSION}"; \
    fi && \
    # uv pip install -U xformers --index-url "https://download.pytorch.org/whl/${CUDA_VERSION}" && \
    uv pip install --upgrade pip

# 10) Clone ComfyUI and install its dependencies (still as comfy).
ARG COMFYUI_VERSION=master
RUN umask 000 && git clone --branch "${COMFYUI_VERSION}" https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI

WORKDIR /app/ComfyUI
RUN --mount=type=cache,target=/home/comfy/.cache,uid=1024,gid=1024 \
    umask 000 && \
    uv pip install -r requirements.txt && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git /app/ComfyUI/custom_nodes/ComfyUI-Manager && \
    uv pip install -r /app/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt

# 11) Pre-initialize ComfyUI to create directories with proper permissions
RUN umask 000 && cd /app/ComfyUI && \
    python main.py --cpu --quick-test-for-ci

# 11) Expose port
EXPOSE 8188

# 12) Switch back to root so that, at runtime, we can adjust comfy's UID/GID if the user wants.
# TODO: Use a non-root user with sudo access instead of root
USER root

# 13) Copy an entrypoint script that does the final usermod+su
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN umask 000 && sudo chmod +x /usr/local/bin/entrypoint.sh

# 14) Our default entrypoint is that script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# 15) Default CMD just runs ComfyUI on 0.0.0.0:8188
CMD ["--port", "8188"]
