#!/usr/bin/env python3

import os
import json
from jinja2 import Environment, FileSystemLoader

# Path to the JSON file with image definitions
VERSIONS_JSON_PATH = "versions.json"

# Directory in which to place the generated Dockerfiles
OUTPUT_DIRECTORY = "dockerfiles"

# Directory containing our Jinja2 template file
TEMPLATE_DIR = "."
TEMPLATE_FILENAME = "Dockerfile.template"

def main():
    # Load JSON data
    with open(VERSIONS_JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Initialize Jinja2 environment
    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))
    template = env.get_template(TEMPLATE_FILENAME)

    # We'll assume `data` has the shape: { "docker_images": [...] }
    docker_images = data.get("docker_images", [])

    for image_def in docker_images:
        # Example fields from the JSON
        comfyui_version = image_def.get("comfyui_version")
        cuda_version    = image_def.get("cuda_version")
        flavor          = image_def.get("flavor", "runtime")  # default "runtime"
        
        # We build a directory structure like:
        # dockerfiles/comfyui-v0.3.9/cuda-12.4.0/runtime/Dockerfile
        version_folder = f"comfyui-{comfyui_version}"
        cuda_folder    = f"cuda-{cuda_version}"
        flavor_folder  = flavor

        output_path = os.path.join(
            OUTPUT_DIRECTORY,
            version_folder,
            cuda_folder,
            flavor_folder
        )
        os.makedirs(output_path, exist_ok=True)

        # Render the template with the entire dictionary
        rendered_dockerfile = template.render(**image_def)

        # Write Dockerfile to the output folder
        dockerfile_path = os.path.join(output_path, "Dockerfile")
        with open(dockerfile_path, "w", encoding="utf-8") as df:
            df.write(rendered_dockerfile)

        print(f"Generated {dockerfile_path}")

if __name__ == "__main__":
    main()
