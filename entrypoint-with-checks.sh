#!/usr/bin/env bash
set -e

# If user specified a new UID/GID at runtime, adjust user 'comfy' accordingly.
if [ -n "${WANTED_UID}" ] && [ -n "${WANTED_GID}" ]; then
  echo ">> Re-mapping comfy user to UID=${WANTED_UID} GID=${WANTED_GID}"
  usermod  -o -u "${WANTED_UID}" comfy
  groupmod -o -g "${WANTED_GID}" comfy

  echo ">> Changing ownership of /app/ComfyUI to comfy:comfy"
  chown -R comfy:comfy /app/ComfyUI

  echo ">> User remapping completed"
fi

# Run permission checks if enabled (default: enabled)
if [ "${SKIP_PERMISSION_CHECK}" != "true" ]; then
  echo ">> Checking permissions on bind-mounted volumes..."
  
  # Copy the check script to a temporary location
  cp /usr/local/bin/check-permissions.sh /tmp/check-permissions.sh
  chmod +x /tmp/check-permissions.sh
  
  # Run the permission check
  /tmp/check-permissions.sh || true
  
  # If there are permission issues, inform the user about the fix-permissions script
  if [ -s /tmp/problem-files.txt ] || [ -s /tmp/problem-dirs.txt ]; then
    echo ">> ⚠️  Permission issues detected!"
    echo ">> To fix these issues run:"
    echo ">>   comfydock dev exec (pick running container)"
    echo ">>   fix-permissions"
    echo ">> This will show you all affected files and ask for confirmation before making changes."
  fi
  
  # If there are permission issues and STRICT_PERMISSIONS is set, exit
  if [ "${STRICT_PERMISSIONS}" = "true" ]; then
    if [ -s /tmp/problem-files.txt ] || [ -s /tmp/problem-dirs.txt ]; then
      echo ">> ERROR: Permission issues detected and STRICT_PERMISSIONS is enabled"
      echo ">> Container will not start. Please fix permissions or set STRICT_PERMISSIONS=false"
      exit 1
    fi
  fi
  
  echo ">> Permission check completed"
else
  echo ">> Skipping permission check (SKIP_PERMISSION_CHECK=true)"
fi

# Now drop privileges so we do *not* run as root:
echo ">> Switching to user 'comfy' (UID=$(id -u comfy), GID=$(id -g comfy))"
exec su comfy -c "umask 000 && uv run python /app/ComfyUI/main.py --listen 0.0.0.0 --port 8188 $*"