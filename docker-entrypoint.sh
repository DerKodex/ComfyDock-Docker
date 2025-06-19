#!/usr/bin/env bash
set -euo pipefail

TARGET_UID="${LOCAL_UID:-$(stat -c %u /workspace)}"
TARGET_GID="${LOCAL_GID:-$(stat -c %g /workspace)}"

# Only mutate if needed
if [[ "$TARGET_UID" != "$(id -u comfy)" || "$TARGET_GID" != "$(id -g comfy)" ]]; then
  echo "↻ remapping comfy → ${TARGET_UID}:${TARGET_GID}"
  groupmod  -o -g "${TARGET_GID}" comfy
  usermod   -o -u "${TARGET_UID}" comfy
  # Chown ONLY the dirs comfy must write to
  chown -R "${TARGET_UID}:${TARGET_GID}" /workspace /home/comfy
fi

# Drop root
exec gosu "${TARGET_UID}:${TARGET_GID}" "$@"
