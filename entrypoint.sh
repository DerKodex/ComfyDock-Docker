#!/usr/bin/env bash
set -e

# If user specified a new UID/GID at runtime, adjust user 'comfy' accordingly.
if [ -n "${WANTED_UID}" ] && [ -n "${WANTED_GID}" ]; then
  echo ">> Re-mapping comfy user to UID=${WANTED_UID} GID=${WANTED_GID}"
  groupmod -o -g "${WANTED_GID}" comfy
  usermod  -o -u "${WANTED_UID}" comfy

  # groupmod -o -g "1024" comfy && usermod  -o -u "1024" comfy

  chown -R comfy:comfy /app/ComfyUI

  echo ">> User remapping completed"
fi

# Now drop privileges so we do *not* run as root:
echo ">> Switching to user 'comfy' (UID=$(id -u comfy), GID=$(id -g comfy))"
exec su comfy -c "umask 000 && uv run python /app/ComfyUI/main.py --listen 0.0.0.0 --port 8188 $*"