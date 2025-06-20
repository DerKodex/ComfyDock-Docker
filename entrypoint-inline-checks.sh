#!/usr/bin/env bash
set -e

#  Environment Variables:
#   - WANTED_UID/WANTED_GID: Remap comfy user
#   - SKIP_PERMISSION_CHECK: Disable permission checking
#   - STRICT_PERMISSIONS: Exit if permission issues found
#   - FIX_PERMISSIONS: Attempt to auto-fix permissions

# Function to check permissions inline
check_volume_permissions() {
  local comfy_uid="${WANTED_UID:-1000}"
  local comfy_gid="${WANTED_GID:-1000}"
  
  echo ">> Checking volume permissions for comfy user (UID=$comfy_uid, GID=$comfy_gid)..."
  
  # Clear previous problem files
  > /tmp/problem-files.txt
  > /tmp/problem-dirs.txt
  
  # Check common ComfyUI directories
  local dirs=(
    "/app/ComfyUI/models"
    "/app/ComfyUI/input"
    "/app/ComfyUI/output"
    "/app/ComfyUI/custom_nodes"
    "/app/ComfyUI/web/extensions"
  )
  
  local has_issues=false
  
  for dir in "${dirs[@]}"; do
    if [ -d "$dir" ]; then
      # Check if directory is writable by comfy
      if ! su comfy -c "test -w '$dir'" 2>/dev/null; then
        echo "$dir" >> /tmp/problem-dirs.txt
        has_issues=true
        echo "  ⚠️  Directory not writable: $dir"
      fi
      
      # Quick check on a few files (not recursive to keep it fast)
      find "$dir" -maxdepth 1 -type f 2>/dev/null | head -10 | while read -r file; do
        if ! su comfy -c "test -r '$file' && test -w '$file'" 2>/dev/null; then
          echo "$file" >> /tmp/problem-files.txt
          has_issues=true
        fi
      done
    fi
  done
  
  if [ "$has_issues" = true ]; then
    echo ">> ⚠️  Permission issues detected! Check /tmp/problem-*.txt for details"
    
    # Optionally try to fix permissions if FIX_PERMISSIONS is set
    if [ "${FIX_PERMISSIONS}" = "true" ]; then
      echo ">> Attempting to fix permissions (FIX_PERMISSIONS=true)..."
      for dir in "${dirs[@]}"; do
        if [ -d "$dir" ] && grep -q "^$dir$" /tmp/problem-dirs.txt; then
          echo "   Fixing: $dir"
          chown -R comfy:comfy "$dir" 2>/dev/null || echo "   Failed to fix: $dir"
        fi
      done
    fi
  else
    echo ">> ✅ All checked directories have proper permissions"
  fi
}

# If user specified a new UID/GID at runtime, adjust user 'comfy' accordingly.
if [ -n "${WANTED_UID}" ] && [ -n "${WANTED_GID}" ]; then
  echo ">> Re-mapping comfy user to UID=${WANTED_UID} GID=${WANTED_GID}"
  usermod  -o -u "${WANTED_UID}" comfy
  groupmod -o -g "${WANTED_GID}" comfy

  echo ">> Changing ownership of /app/ComfyUI to comfy:comfy"
  chown -R comfy:comfy /app/ComfyUI

  echo ">> User remapping completed"
fi

# Run permission checks unless disabled
if [ "${SKIP_PERMISSION_CHECK}" != "true" ]; then
  check_volume_permissions
fi

# Now drop privileges so we do *not* run as root:
echo ">> Switching to user 'comfy' (UID=$(id -u comfy), GID=$(id -g comfy))"
exec su comfy -c "umask 000 && uv run python /app/ComfyUI/main.py --listen 0.0.0.0 --port 8188 $*"