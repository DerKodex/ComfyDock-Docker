#!/usr/bin/env bash
# Script to check permissions on bind-mounted volumes
# Creates /tmp/problem-files.txt and /tmp/problem-dirs.txt for problematic permissions

set -e

# Get the comfy user's UID/GID (either default or remapped)
COMFY_UID=${WANTED_UID:-1000}
COMFY_GID=${WANTED_GID:-1000}

echo "Checking permissions for user comfy (UID=$COMFY_UID, GID=$COMFY_GID)"

# Clear previous problem files
> /tmp/problem-files.txt
> /tmp/problem-dirs.txt

# Function to detect bind mounts
detect_bind_mounts() {
    # Parse /proc/self/mountinfo to find bind mounts
    # Format: mount_id parent_id major:minor root mount_point options...
    while IFS= read -r line; do
        # Extract mount point (5th field after splitting by space)
        mount_point=$(echo "$line" | awk '{print $5}')
        
        # Skip system mounts
        if [[ "$mount_point" =~ ^/(proc|sys|dev|etc|usr|bin|sbin|lib|lib64|var|run|tmp)(/|$) ]]; then
            continue
        fi
        
        # Check if it's inside /app (where ComfyUI lives) or /home
        if [[ "$mount_point" =~ ^/app/ ]] || [[ "$mount_point" =~ ^/home/ ]]; then
            echo "$mount_point"
        fi
    done < /proc/self/mountinfo
}

# Function to check if a path is readable/writable by comfy user
check_permissions() {
    local path="$1"
    local type="$2"  # "file" or "dir"
    
    # Use su to test as the comfy user
    if ! su comfy -c "test -r '$path' && test -w '$path'" 2>/dev/null; then
        if [ "$type" = "file" ]; then
            echo "$path" >> /tmp/problem-files.txt
        else
            echo "$path" >> /tmp/problem-dirs.txt
        fi
        return 1
    fi
    return 0
}

# Function to recursively check directory permissions
check_directory() {
    local dir="$1"
    local max_depth="${2:-5}"  # Limit recursion depth
    local current_depth="${3:-0}"
    
    if [ "$current_depth" -ge "$max_depth" ]; then
        return
    fi
    
    # Check the directory itself
    if ! check_permissions "$dir" "dir"; then
        echo "  ❌ Directory not accessible: $dir"
    fi
    
    # Check files and subdirectories
    if [ -r "$dir" ]; then
        find "$dir" -maxdepth 1 -mindepth 1 2>/dev/null | while read -r item; do
            if [ -f "$item" ]; then
                if ! check_permissions "$item" "file"; then
                    echo "  ❌ File not accessible: $item"
                fi
            elif [ -d "$item" ]; then
                # Recurse into subdirectory
                check_directory "$item" "$max_depth" $((current_depth + 1))
            fi
        done
    fi
}

# Main execution
echo "Detecting bind-mounted volumes..."
BIND_MOUNTS=$(detect_bind_mounts | sort -u)

if [ -z "$BIND_MOUNTS" ]; then
    echo "No bind mounts detected in /app or /home directories"
else
    echo "Found bind mounts:"
    echo "$BIND_MOUNTS"
    echo ""
    echo "Checking permissions..."
    
    # Check each bind mount
    while IFS= read -r mount; do
        if [ -d "$mount" ]; then
            echo "Checking: $mount"
            check_directory "$mount"
        fi
    done <<< "$BIND_MOUNTS"
fi

# Report results
echo ""
echo "Permission check complete!"

if [ -s /tmp/problem-files.txt ]; then
    echo "❌ Found $(wc -l < /tmp/problem-files.txt) files with permission issues"
    echo "   See: /tmp/problem-files.txt"
else
    echo "✅ No file permission issues found"
    rm -f /tmp/problem-files.txt
fi

if [ -s /tmp/problem-dirs.txt ]; then
    echo "❌ Found $(wc -l < /tmp/problem-dirs.txt) directories with permission issues"
    echo "   See: /tmp/problem-dirs.txt"
else
    echo "✅ No directory permission issues found"
    rm -f /tmp/problem-dirs.txt
fi

# Optional: Create a summary file
if [ -s /tmp/problem-files.txt ] || [ -s /tmp/problem-dirs.txt ]; then
    {
        echo "Permission Issues Summary"
        echo "========================="
        echo "User: comfy (UID=$COMFY_UID, GID=$COMFY_GID)"
        echo "Timestamp: $(date)"
        echo ""
        
        if [ -s /tmp/problem-dirs.txt ]; then
            echo "Problematic Directories:"
            cat /tmp/problem-dirs.txt | sed 's/^/  - /'
            echo ""
        fi
        
        if [ -s /tmp/problem-files.txt ]; then
            echo "Problematic Files:"
            cat /tmp/problem-files.txt | sed 's/^/  - /'
        fi
    } > /tmp/permission-issues-summary.txt
    
    echo ""
    echo "📄 Full summary available at: /tmp/permission-issues-summary.txt"
fi