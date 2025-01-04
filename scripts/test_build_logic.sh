#!/bin/bash

# Simple script to test Dockerfile path processing and tag generation
if [ $# -ne 1 ]; then
    echo "Usage: $0 <dockerfile_path>"
    exit 1
fi

dockerfile="$1"

# Get the directory of the dockerfile
dir=$(dirname "$dockerfile")
echo "Directory of the Dockerfile: $dir"

# Remove the leading 'dockerfiles/' to get something like 'comfyui-v0.3.9/cudnn-devel'
relpath="${dir#dockerfiles/}"
echo "Relative path: $relpath"

# Grab everything up to the first slash (the version directory, e.g. 'comfyui-v0.3.9')
version_directory=$(echo "$relpath" | cut -d'/' -f1)
echo "Version directory: $version_directory"

# Drop the 'comfyui-' prefix to get the actual version (e.g. 'v0.3.9')
comfyui_version="${version_directory#comfyui-}"
echo "ComfyUI version: $comfyui_version"

# Check if there's anything beyond the version directory (e.g. 'cudnn-devel')
subdirs=$(echo "$relpath" | cut -d'/' -f2-)
if [ "$subdirs" = "$version_directory" ]; then
    subdirs=""
fi
echo "Subdirectories: $subdirs"

# Start your tag with just the version
tag="$comfyui_version"
echo "Tag: $tag"

# Append subdirectories to the tag only if they exist
if [ -n "$subdirs" ]; then
    # Replace any slashes with dashes
    subdirs_tag=$(echo "$subdirs" | tr '/' '-')
    tag="${tag}-${subdirs_tag}"
fi

# Output the generated tag
echo "Generated tag: $tag"
