#!/usr/bin/env bash
set -e

umask 000

# If user specified a new UID/GID at runtime, adjust user 'comfy' accordingly.
if [ -n "${WANTED_UID}" ] && [ -n "${WANTED_GID}" ]; then
  echo ">> Re-mapping comfy user to UID=${WANTED_UID} GID=${WANTED_GID}"
  groupmod -o -g "${WANTED_GID}" comfy
  usermod  -o -u "${WANTED_UID}" comfy
  # Optionally chown directories to the new UID/GID if necessary:
  # chown -R comfy:comfy /app
  # chmod -R 777 /app/.venv
fi

# Now drop privileges so we do *not* run as root:
echo ">> Switching to user 'comfy'"
exec su comfy -c "umask 000 && /app/.venv/bin/python /app/ComfyUI/main.py --listen 0.0.0.0 --port 8188 $*"
