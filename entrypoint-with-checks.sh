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

# Function to run the actual permission check
run_permission_check() {
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
}

# Run permission checks based on configuration
PERMISSION_CHECK_MODE="${PERMISSION_CHECK_MODE:-once}"  # startup, once, never

case "$PERMISSION_CHECK_MODE" in
  "never")
    echo ">> Skipping permission check (PERMISSION_CHECK_MODE=never)"
    ;;
  "once")
    PERMISSION_CHECK_MARKER="/tmp/.permission-check-done"
    if [ ! -f "$PERMISSION_CHECK_MARKER" ]; then
      echo ">> Running one-time permission check on bind-mounted volumes..."
      run_permission_check
      # Mark as completed
      touch "$PERMISSION_CHECK_MARKER"
    else
      echo ">> Skipping permission check (already completed once)"
      echo ">> To re-run: delete $PERMISSION_CHECK_MARKER or set PERMISSION_CHECK_MODE=startup"
    fi
    ;;
  "startup"|*)
    echo ">> Checking permissions on bind-mounted volumes..."
    run_permission_check
    ;;
esac

# Now drop privileges so we do *not* run as root:
echo ">> Switching to user 'comfy' (UID=$(id -u comfy), GID=$(id -g comfy))"
exec su comfy -c "umask 000 && uv run python /app/ComfyUI/main.py --listen 0.0.0.0 --port 8188 $*"