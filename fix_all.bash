#!/bin/bash
# Filename: fix_all.bash
# Fix permissions on ALL executable files

# Use L_SDR_DIR environment variable or fall back to script location
if [ -n "$L_SDR_DIR" ]; then
    SCRIPT_DIR="$L_SDR_DIR"
else
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

cd "$SCRIPT_DIR" || exit 1

echo "Working in: $SCRIPT_DIR"
echo "Fixing all permissions..."
echo ""

# Function to fix permissions in a directory
fix_dir() {
    local dir="$1"
    local pattern="$2"
    local desc="$3"
    
    local count=0
    
    if [ -d "$dir" ] || [ "$dir" = "." ]; then
        while IFS= read -r -d '' file; do
            chmod +x "$file"
            count=$((count + 1))
        done < <(find "$dir" -maxdepth 1 -type f -name "$pattern" -print0 2>/dev/null)
        
        if [ $count -gt 0 ]; then
            echo "✓ Fixed $count file(s): $desc"
        else
            echo "⊘ No files found: $desc"
        fi
    else
        echo "⊘ Directory not found: $desc"
    fi
}

# Fix all executable types
fix_dir "." "*.sh" "Root .sh files"
fix_dir "." "*.bash" "Root .bash files"
fix_dir "scripts" "*.py" "scripts/*.py files"
fix_dir "tests" "*.py" "tests/*.py files"
fix_dir "utils" "*.bash" "utils/*.bash files"
fix_dir "utils" "*.sh" "utils/*.sh files"

echo ""
echo "Done! All scripts should now be executable."