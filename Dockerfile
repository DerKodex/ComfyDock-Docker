FROM ubuntu:22.04

# 1) Install system dependencies and set up glvnd (as root).
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
        build-essential \
        sudo && \
    mkdir -p /usr/share/glvnd/egl_vendor.d && \
    echo '{"file_format_version":"1.0.0","ICD":{"library_path":"/usr/lib/x86_64-linux-gnu/libEGL_nvidia.so.0"}}' \
        >/usr/share/glvnd/egl_vendor.d/10_nvidia.json && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 2) Create a placeholder user 'comfy' with default UID/GID (1000).
#    We'll adjust it at runtime if needed. Using 1000 as it's the common default for first user.
RUN groupadd -g 1000 comfy \
    && useradd -m -u 1000 -g comfy -s /bin/bash comfy
    # && echo "comfy ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/comfy \
    # && chmod 0440 /etc/sudoers.d/comfy

# 3) Create directories with world-writable permissions (as root)
#    This ensures any user can read/write regardless of ownership
RUN umask 000 && \
    mkdir -p /home/comfy/.cache && \
    chmod -R 777 /home/comfy/.cache && \
    mkdir -p /app && \
    chmod -R 777 /app

# 4) Stay as root for all installations
# Basic environment variables
ENV NVIDIA_DRIVER_CAPABILITIES="all"
ENV NVIDIA_VISIBLE_DEVICES="all"
ENV MESA_D3D12_DEFAULT_ADAPTER_NAME="NVIDIA"
ENV LD_LIBRARY_PATH=/usr/lib/wsl/lib
ENV WINDOW_BACKEND="headless"
ENV DOCKER_RUNTIME="1"

# 5) UV environment variables
# Set XDG_DATA_HOME to install Python in comfy's home directory
ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    UV_CACHE_DIR=/home/comfy/.cache/uv \
    UV_HTTP_TIMEOUT=300 \
    XDG_DATA_HOME=/home/comfy/.local/share \
    UV_PYTHON_INSTALL_DIR=/home/comfy/.local/share/uv/python

# 6) Copy uv from a multi-stage build (as root)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# 7) Create Python virtual environment (as root, with world-writable permissions).
ARG PYTHON_VERSION=3.12
RUN --mount=type=cache,target=/home/comfy/.cache,uid=0,gid=0 \
    umask 000 && \
    # Ensure the Python install directory exists with proper permissions
    mkdir -p /home/comfy/.local/share/uv/python && \
    chmod -R 777 /home/comfy/.local && \
    # Create the virtual environment
    uv venv /app/.venv --python ${PYTHON_VERSION} && \
    chmod -R 777 /app/.venv && \
    chmod +x /app/.venv/bin/* && \
    # Make the uv Python installation accessible
    chmod -R 755 /home/comfy/.local/share/uv/python || true

# 8) Make the virtual environment the default Python environment
ENV PATH="/app/.venv/bin:$PATH"

# 9) Install PyTorch + other Python dependencies in the venv (as root).
ARG CUDA_VERSION=cu124
ARG PYTORCH_VERSION=stable
RUN --mount=type=cache,target=/home/comfy/.cache,uid=0,gid=0 \
    umask 000 && \
    if [ "${PYTORCH_VERSION}" = "stable" ]; then \
        echo "PyTorch stable installed" > /home/comfy/.torch_version.txt && \
        uv pip install torch torchvision torchaudio \
            --index-url "https://download.pytorch.org/whl/cu121"; \
    elif [ "${PYTORCH_VERSION}" = "nightly" ]; then \
        echo "PyTorch nightly installed" > /home/comfy/.torch_version.txt && \
        uv pip install --pre torch torchvision torchaudio \
            --index-url "https://download.pytorch.org/whl/nightly/cu121" \
            --extra-index-url "https://pypi.org/simple"; \
    fi && \
    uv pip install sageattention && \
    uv pip install --upgrade pip && \
    chmod -R 777 /app/.venv && \
    chmod +x /app/.venv/bin/*

USER comfy

# 10) Clone ComfyUI and install its dependencies (as comfy).
ARG COMFYUI_VERSION=master
RUN umask 000 && \
    git clone https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI && \
    cd /app/ComfyUI && \
    # Fetch all branches and tags
    git fetch --all --tags && \
    # Check if COMFYUI_VERSION is a tag or branch
    if git show-ref --verify --quiet "refs/tags/${COMFYUI_VERSION}"; then \
        echo "Checking out tag: ${COMFYUI_VERSION}"; \
        git checkout "tags/${COMFYUI_VERSION}"; \
        # Create a local master branch at this commit
        git checkout -b master; \
    elif git show-ref --verify --quiet "refs/remotes/origin/${COMFYUI_VERSION}"; then \
        echo "Checking out branch: ${COMFYUI_VERSION}"; \
        git checkout -b "${COMFYUI_VERSION}" "origin/${COMFYUI_VERSION}"; \
        # If it's not already master, also create master at this commit
        if [ "${COMFYUI_VERSION}" != "master" ]; then \
            git branch master; \
        fi; \
    else \
        echo "Version ${COMFYUI_VERSION} not found, checking out master"; \
        git checkout -b master origin/master; \
    fi && \
    # Set upstream for the current branch
    git branch --set-upstream-to=origin/master master || true && \
    chown -R comfy:comfy /app/ComfyUI

WORKDIR /app/ComfyUI
RUN --mount=type=cache,target=/home/comfy/.cache,uid=0,gid=0 \
    umask 000 && \
    uv pip install -r requirements.txt && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git /app/ComfyUI/custom_nodes/ComfyUI-Manager && \
    uv pip install -r /app/ComfyUI/custom_nodes/ComfyUI-Manager/requirements.txt && \
    chown -R comfy:comfy /app/ComfyUI/custom_nodes

# 11) Pre-initialize ComfyUI to and test if it works
RUN umask 000 && cd /app/ComfyUI && \
    python main.py --cpu --quick-test-for-ci

USER root

# RUN chmod -R 777 /app/ComfyUI/custom_nodes && \
# chmod -R 777 /app/ComfyUI

# 12) Expose port
EXPOSE 8188

# 13) Copy scripts and set up permissions
COPY entrypoint-with-checks.sh /usr/local/bin/entrypoint-with-checks.sh
COPY check-permissions.sh /usr/local/bin/check-permissions.sh
COPY fix-permissions.sh /usr/local/bin/fix-permissions
RUN chmod +x /usr/local/bin/entrypoint-with-checks.sh && \
    chmod +x /usr/local/bin/check-permissions.sh && \
    chmod +x /usr/local/bin/fix-permissions && \
    # Make fix-permissions available in PATH without .sh extension
    ln -sf /usr/local/bin/fix-permissions /usr/bin/fix-permissions

# 14) Stay as root - the entrypoint will handle user switching
ENTRYPOINT ["/usr/local/bin/entrypoint-with-checks.sh"]
