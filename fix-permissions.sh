#!/usr/bin/env bash
# Script to fix permissions on bind-mounted volumes with user confirmation
# Must be run as root

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo fix-permissions"
    exit 1
fi

# Get the comfy user's UID/GID (either default or remapped)
COMFY_UID=${WANTED_UID:-1000}
COMFY_GID=${WANTED_GID:-1000}

# Create audit log directory
AUDIT_DIR="/var/log/comfydock"
mkdir -p "$AUDIT_DIR"
AUDIT_LOG="$AUDIT_DIR/permission-fixes-$(date +%Y%m%d-%H%M%S).log"

# Function to log changes
log_change() {
    local action="$1"
    local path="$2"
    local old_owner="$3"
    local new_owner="$4"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $action | $path | $old_owner -> $new_owner" >> "$AUDIT_LOG"
}

# Header
echo -e "${BLUE}=== ComfyDock Permission Fix Tool ===${NC}"
echo "This tool will fix permission issues for the comfy user (UID=$COMFY_UID, GID=$COMFY_GID)"
echo ""

# Run the permission check
echo "Checking for permission issues..."
cp /usr/local/bin/check-permissions.sh /tmp/check-permissions.sh
chmod +x /tmp/check-permissions.sh
/tmp/check-permissions.sh > /tmp/permission-check-output.txt 2>&1 || true

# Save the initial problem lists
cp /tmp/problem-files.txt /tmp/initial-problem-files.txt 2>/dev/null || touch /tmp/initial-problem-files.txt
cp /tmp/problem-dirs.txt /tmp/initial-problem-dirs.txt 2>/dev/null || touch /tmp/initial-problem-dirs.txt

# Check if there are any issues
if [ ! -s /tmp/initial-problem-files.txt ] && [ ! -s /tmp/initial-problem-dirs.txt ]; then
    echo -e "${GREEN}✅ No permission issues found!${NC}"
    echo "All files and directories are accessible by the comfy user."
    exit 0
fi

# Count issues
DIR_COUNT=0
FILE_COUNT=0
if [ -s /tmp/initial-problem-dirs.txt ]; then
    DIR_COUNT=$(wc -l < /tmp/initial-problem-dirs.txt)
fi
if [ -s /tmp/initial-problem-files.txt ]; then
    FILE_COUNT=$(wc -l < /tmp/initial-problem-files.txt)
fi

# Display issues found
echo -e "${YELLOW}⚠️  Permission issues found:${NC}"
echo "   - Directories: $DIR_COUNT"
echo "   - Files: $FILE_COUNT"
echo ""

# Show what will be changed
echo -e "${BLUE}The following items will have their ownership changed to comfy:comfy (${COMFY_UID}:${COMFY_GID}):${NC}"
echo ""

if [ -s /tmp/initial-problem-dirs.txt ]; then
    echo -e "${YELLOW}Directories:${NC}"
    while IFS= read -r dir; do
        if [ -n "$dir" ] && [ -e "$dir" ]; then
            current_owner=$(stat -c "%u:%g" "$dir" 2>/dev/null || echo "unknown")
            echo "  📁 $dir (current: $current_owner)"
        fi
    done < /tmp/initial-problem-dirs.txt
    echo ""
fi

if [ -s /tmp/initial-problem-files.txt ]; then
    echo -e "${YELLOW}Files:${NC}"
    # Show up to 20 files, then summarize if more
    head -20 /tmp/initial-problem-files.txt | while IFS= read -r file; do
        if [ -n "$file" ] && [ -e "$file" ]; then
            current_owner=$(stat -c "%u:%g" "$file" 2>/dev/null || echo "unknown")
            echo "  📄 $file (current: $current_owner)"
        fi
    done
    
    if [ "$FILE_COUNT" -gt 20 ]; then
        echo "  ... and $((FILE_COUNT - 20)) more files"
    fi
    echo ""
fi

# Ask for confirmation
echo -e "${RED}⚠️  WARNING: This will change ownership of the above files and directories!${NC}"
echo -n "Do you want to proceed? (yes/no): "
read -r confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Operation cancelled."
    exit 0
fi

# Start audit log
{
    echo "=== ComfyDock Permission Fix Audit Log ==="
    echo "Date: $(date)"
    echo "User: $(whoami)"
    echo "Target UID:GID: ${COMFY_UID}:${COMFY_GID}"
    echo "==========================================="
    echo ""
} > "$AUDIT_LOG"

# Perform the fixes
echo ""
echo "Fixing permissions..."

# Fix directories
if [ -s /tmp/initial-problem-dirs.txt ]; then
    echo "Fixing directories..."
    while IFS= read -r dir; do
        if [ -n "$dir" ] && [ -e "$dir" ]; then
            old_owner=$(stat -c "%u:%g" "$dir" 2>/dev/null || echo "unknown")
            if chown "${COMFY_UID}:${COMFY_GID}" "$dir" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Fixed: $dir"
                log_change "DIR" "$dir" "$old_owner" "${COMFY_UID}:${COMFY_GID}"
            else
                echo -e "  ${RED}✗${NC} Failed: $dir"
                log_change "DIR_FAILED" "$dir" "$old_owner" "unchanged"
            fi
        fi
    done < /tmp/initial-problem-dirs.txt
fi

# Fix files
if [ -s /tmp/initial-problem-files.txt ]; then
    echo "Fixing files..."
    fixed=0
    failed=0
    total=$(wc -l < /tmp/initial-problem-files.txt)
    
    while IFS= read -r file; do
        if [ -n "$file" ] && [ -e "$file" ]; then
            old_owner=$(stat -c "%u:%g" "$file" 2>/dev/null || echo "unknown")
            if chown "${COMFY_UID}:${COMFY_GID}" "$file" 2>/dev/null; then
                ((fixed++))
                log_change "FILE" "$file" "$old_owner" "${COMFY_UID}:${COMFY_GID}"
                # Show progress for large file counts
                if [ $((fixed % 100)) -eq 0 ]; then
                    echo -e "  ${GREEN}✓${NC} Fixed $fixed/$total files..."
                fi
            else
                ((failed++))
                log_change "FILE_FAILED" "$file" "$old_owner" "unchanged"
                # Show individual failures for first few files
                if [ $failed -le 10 ]; then
                    echo -e "  ${RED}✗${NC} Failed: $file"
                fi
            fi
        fi
    done < /tmp/initial-problem-files.txt
    
    echo -e "  ${GREEN}✓${NC} Fixed $fixed files"
    if [ "$failed" -gt 0 ]; then
        echo -e "  ${RED}✗${NC} Failed to fix $failed files"
    fi
fi

# Add summary to audit log
{
    echo ""
    echo "=== Summary ==="
    echo "Directories fixed: $(grep -c "^.*| DIR |" "$AUDIT_LOG" 2>/dev/null || echo 0)"
    echo "Directories failed: $(grep -c "^.*| DIR_FAILED |" "$AUDIT_LOG" 2>/dev/null || echo 0)"
    echo "Files fixed: $(grep -c "^.*| FILE |" "$AUDIT_LOG" 2>/dev/null || echo 0)"
    echo "Files failed: $(grep -c "^.*| FILE_FAILED |" "$AUDIT_LOG" 2>/dev/null || echo 0)"
    echo "==============="
} >> "$AUDIT_LOG"

# Verify the fixes
echo ""
echo "Verifying permissions..."
/tmp/check-permissions.sh > /tmp/permission-check-verify.txt 2>&1 || true

# Check if verification found any remaining issues
remaining_dirs=0
remaining_files=0
if [ -s /tmp/problem-dirs.txt ]; then
    remaining_dirs=$(wc -l < /tmp/problem-dirs.txt)
fi
if [ -s /tmp/problem-files.txt ]; then
    remaining_files=$(wc -l < /tmp/problem-files.txt)
fi

if [ "$remaining_dirs" -eq 0 ] && [ "$remaining_files" -eq 0 ]; then
    echo -e "${GREEN}✅ All permissions successfully fixed!${NC}"
else
    echo -e "${YELLOW}⚠️  Some permission issues remain:${NC}"
    if [ "$remaining_dirs" -gt 0 ]; then
        echo "   - Directories: $remaining_dirs"
    fi
    if [ "$remaining_files" -gt 0 ]; then
        echo "   - Files: $remaining_files"
    fi
    echo "Please check the audit log for details."
fi

# Show audit log location
echo ""
echo -e "${BLUE}📄 Audit log saved to: ${AUDIT_LOG}${NC}"
echo "To download the audit log, run:"
echo "  docker cp <container_name>:${AUDIT_LOG} ./permission-fixes.log"

# Cleanup
rm -f /tmp/permission-check-output.txt /tmp/permission-check-verify.txt /tmp/initial-problem-files.txt /tmp/initial-problem-dirs.txt