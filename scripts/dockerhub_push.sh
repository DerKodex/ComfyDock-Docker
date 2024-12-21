#!/bin/bash

# EXAMPLE:
# ./dockerhub_push.sh my_image:latest my_dockerhub_repo:latest
# e.g. ./dockerhub_push.sh comfy-env-clone:depthcrafter-env akatzai/comfy-env-depthcrafter:0.0.1

# Check if the correct number of arguments is passed
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <local_image:tag> <dockerhub_repo:tag>"
  exit 1
fi

# Assign arguments to variables
LOCAL_IMAGE=$1
DOCKERHUB_REPO=$2

# Tag the local image with the Docker Hub repository and tag
echo "Tagging local image '$LOCAL_IMAGE' as '$DOCKERHUB_REPO'..."
docker tag "$LOCAL_IMAGE" "$DOCKERHUB_REPO"

# Push the tagged image to Docker Hub
echo "Pushing '$DOCKERHUB_REPO' to Docker Hub..."
docker push "$DOCKERHUB_REPO"

# Check if the push was successful
if [ $? -eq 0 ]; then
  echo "Image pushed successfully!"
else
  echo "Failed to push the image. Check the Docker Hub repository and your Docker login status."
  exit 2
fi