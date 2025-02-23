# Base Dockerfiles for ComfyUI

This repo contains a collection of dockerfiles for running ComfyUI with a particular version and flavor of CUDA.

It is meant to be used alongside my [ComfyUI Environment Manager tool](https://github.com/akatz-ai/ComfyUI-Environment-Manager)

Docker images built and pushed to Dockerhub and can be [found here](https://hub.docker.com/repository/docker/akatzai/comfyui-env/tags)

**Note:** I am not a security expert and am open to Issues and PRs that can help to harden the Images included in this repo.

## Testing

To build the image locally, run the following command:
```bash
docker build \
  --build-arg COMFYUI_VERSION=master \
  --build-arg CUDA_VERSION=12.4 \
  --build-arg PYTHON_VERSION=3.12 \
  --build-arg PYTORCH_VERSION=stable \
  --tag comfydock-env:master-py3.12-cuda12.4 \
  --file Dockerfile \
  .
```

To run the image, run the following command:
```bash
docker run -it --rm --gpus all comfydock-env:master-py3.12-cuda12.4
```

