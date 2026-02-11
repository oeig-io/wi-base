#!/bin/bash
# refresh-skills.sh - Create symlinks from wi-*/tool files to .opencode/skills/
# 
# Usage: ./wi-base/refresh-skills.sh [wi-directory...]
# Examples:
#   ./wi-base/refresh-skills.sh                    # Auto-discover all wi-* directories
#   ./wi-base/refresh-skills.sh wi-idempiere       # Single directory
#   ./wi-base/refresh-skills.sh wi-incus wi-metabase wi-idempiere  # Multiple directories
# 
# Exit codes: 0 = success, non-zero = error

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.opencode/skills"

# Get directories to process
if [[ $# -eq 0 ]]; then
    # Auto-discover all wi-* directories (excluding wi-base), sorted
    mapfile -t TARGET_DIRS < <(find "$REPO_ROOT" -maxdepth 1 -type d -name 'wi-*' ! -name 'wi-base' | sort)
else
    TARGET_DIRS=("$@")
fi

# PHASE 1: Pre-validation - Check all directories exist
for dir in "${TARGET_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo "Error: Directory '$dir' does not exist" >&2
        exit 1
    fi
done

# PHASE 2: Duplicate detection - Collect all skill names
# Use an associative array: skill_name -> directory
skill_map=()
for dir in "${TARGET_DIRS[@]}"; do
    # Skip if directory has no tool files
    if ! compgen -G "$dir"/*-tool.md >/dev/null 2>&1; then
        continue
    fi
    
    for file in "$dir"/*-tool.md; do
        [[ -f "$file" ]] || continue
        
        # Extract skill name from frontmatter
        skill_name=$(sed -n '/^---$/,/^---$/{/^---$/d; /^name: /p}' "$file" | sed 's/^name: //' | head -1)
        
        if [[ -z "$skill_name" ]]; then
            echo "Error: $(basename "$file") missing frontmatter 'name'" >&2
            exit 1
        fi
        
        if [[ ! "$skill_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
            echo "Error: $(basename "$file") has invalid skill name '$skill_name'" >&2
            exit 1
        fi
        
        # Check for duplicate skill names
        for entry in "${skill_map[@]}"; do
            # entry format is "skill_name:directory:filename"
            existing_skill="${entry%%:*}"
            if [[ "$existing_skill" == "$skill_name" ]]; then
                existing_dir="${entry#*:}"
                existing_dir="${existing_dir%%:*}"
                echo "Error: Duplicate skill name '$skill_name' found in" >&2
                echo "  $existing_dir and $dir" >&2
                exit 1
            fi
        done
        
        skill_map+=("$skill_name:$(dirname "$file"):$(basename "$file")")
    done
done

# PHASE 3: Processing - Create symlinks
rm -rf "$SKILLS_DIR"
mkdir -p "$SKILLS_DIR"

for dir in "${TARGET_DIRS[@]}"; do
    # Skip if directory has no tool files (silent skip)
    if ! compgen -G "$dir"/*-tool.md >/dev/null 2>&1; then
        continue
    fi
    
    for file in "$dir"/*-tool.md; do
        [[ -f "$file" ]] || continue
        
        filename=$(basename "$file")
        
        # Extract skill name (already validated, so we know it exists and is valid)
        skill_name=$(sed -n '/^---$/,/^---$/{/^---$/d; /^name: /p}' "$file" | sed 's/^name: //' | head -1)
        
        mkdir -p "$SKILLS_DIR/$skill_name"
        
        rel_path=$(realpath --relative-to="$SKILLS_DIR/$skill_name" "$file")
        ln -s "$rel_path" "$SKILLS_DIR/$skill_name/SKILL.md"
        
        echo "$skill_name ← $filename"
    done
done

echo ""
echo "Skills refreshed in .opencode/skills/"
