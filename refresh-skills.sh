#!/bin/bash
# refresh-skills.sh - Create symlinks from wi-*/tool files to .opencode/skills/ and .pi/skills/
# 
# Prerequisites for a file to be deployed as a skill:
#   - Filename must match pattern: *-tool.md (e.g., idempiere-process-tool.md)
#   - File must have frontmatter with a 'name' field (e.g., `name: idempiere-process`)
#   - Skill name must match pattern: lowercase letters, numbers, hyphens only
#
# Usage: ./wi-base/refresh-skills.sh [options] [wi-directory...]
# Options:
#   --opencode-only    Create symlinks only for opencode (default: both opencode and pi)
#   --pi-only          Create symlinks only for pi
#   --both             Create symlinks for both opencode and pi (default)
# Examples:
#   ./wi-base/refresh-skills.sh                    # Auto-discover all wi-* directories, both harnesses
#   ./wi-base/refresh-skills.sh --pi-only          # Pi only
#   ./wi-base/refresh-skills.sh wi-idempiere       # Single directory, both harnesses
#   ./wi-base/refresh-skills.sh --opencode-only wi-idempiere  # Opencode only
# 
# Exit codes: 0 = success, non-zero = error

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPENCODE_SKILLS_DIR="$REPO_ROOT/.opencode/skills"
PI_SKILLS_DIR="$REPO_ROOT/.pi/skills"

# Determine which harnesses to target
TARGET_HARNESS="both"
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --opencode-only)
            TARGET_HARNESS="opencode"
            shift
            ;;
        --pi-only)
            TARGET_HARNESS="pi"
            shift
            ;;
        --both)
            TARGET_HARNESS="both"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options] [wi-directory...]"
            echo "Options:"
            echo "  --opencode-only    Create symlinks only for opencode"
            echo "  --pi-only          Create symlinks only for pi"
            echo "  --both             Create symlinks for both (default)"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"

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
# Clean up existing skill directories
[[ "$TARGET_HARNESS" == "opencode" || "$TARGET_HARNESS" == "both" ]] && rm -rf "$OPENCODE_SKILLS_DIR"
[[ "$TARGET_HARNESS" == "pi" || "$TARGET_HARNESS" == "both" ]] && rm -rf "$PI_SKILLS_DIR"

# Create skill directories for enabled harnesses
[[ "$TARGET_HARNESS" == "opencode" || "$TARGET_HARNESS" == "both" ]] && mkdir -p "$OPENCODE_SKILLS_DIR"
[[ "$TARGET_HARNESS" == "pi" || "$TARGET_HARNESS" == "both" ]] && mkdir -p "$PI_SKILLS_DIR"

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
        
        # Create symlink for opencode
        if [[ "$TARGET_HARNESS" == "opencode" || "$TARGET_HARNESS" == "both" ]]; then
            mkdir -p "$OPENCODE_SKILLS_DIR/$skill_name"
            rel_path=$(realpath --relative-to="$OPENCODE_SKILLS_DIR/$skill_name" "$file")
            ln -s "$rel_path" "$OPENCODE_SKILLS_DIR/$skill_name/SKILL.md"
        fi
        
        # Create symlink for pi
        if [[ "$TARGET_HARNESS" == "pi" || "$TARGET_HARNESS" == "both" ]]; then
            mkdir -p "$PI_SKILLS_DIR/$skill_name"
            rel_path=$(realpath --relative-to="$PI_SKILLS_DIR/$skill_name" "$file")
            ln -s "$rel_path" "$PI_SKILLS_DIR/$skill_name/SKILL.md"
        fi
        
        echo "$skill_name ← $filename"
    done
done

echo ""
case "$TARGET_HARNESS" in
    opencode)
        echo "Skills refreshed in .opencode/skills/"
        ;;
    pi)
        echo "Skills refreshed in .pi/skills/"
        ;;
    both)
        echo "Skills refreshed in .opencode/skills/ and .pi/skills/"
        ;;
esac
