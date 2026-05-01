#!/bin/bash
# refresh-skills.sh - Create symlinks from wi-*/tool files to .opencode/skills/ and .pi/skills/
# 
# Skill Structure Support:
#   1. Single file:   wi-*/name-tool.md              → symlink to SKILL.md
#   2. Directory:     wi-*/name-tool/ (with SKILL.md) → symlink to directory
#
# Prerequisites:
#   - File or directory name must match pattern: *-tool.md or *-tool/
#   - SKILL.md must have frontmatter with a 'name' field (e.g., `name: name`)
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
# Track whether this is a full refresh (no args) or partial refresh (specific dirs).
# Full refresh wipes the entire skills directory; partial refresh only touches targeted skills.
if [[ $# -eq 0 ]]; then
    IS_FULL_REFRESH=true
    # Auto-discover all wi-* directories (excluding wi-base), sorted
    mapfile -t TARGET_DIRS < <(find "$REPO_ROOT" -maxdepth 1 -type d -name 'wi-*' ! -name 'wi-base' | sort)
else
    IS_FULL_REFRESH=false
    TARGET_DIRS=("$@")
fi

# PHASE 1: Pre-validation - Check all directories exist
for dir in "${TARGET_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        echo "Error: Directory '$dir' does not exist" >&2
        exit 1
    fi
done

# PHASE 2: Duplicate detection - Collect all skill names and sources
# Use an associative array: skill_name -> source_type:directory:path
# source_type is either "file" or "directory"
skill_map=()

find_skill_source() {
    local dir="$1"
    local tool_dir=""
    local tool_file=""
    
    # Check for directory structure first (preferred)
    # Use find to avoid globbing issues
    if find "$dir" -maxdepth 1 -type d -name '*-tool' -print -quit | grep -q .; then
        tool_dir=$(find "$dir" -maxdepth 1 -type d -name '*-tool' -print -quit)
        echo "directory:$dir:$tool_dir"
        return
    fi
    
    # Check for single file structure
    if find "$dir" -maxdepth 1 -type f -name '*-tool.md' -print -quit | grep -q .; then
        tool_file=$(find "$dir" -maxdepth 1 -type f -name '*-tool.md' -print -quit)
        echo "file:$dir:$tool_file"
        return
    fi
    
    echo ""
}

for dir in "${TARGET_DIRS[@]}"; do
    # Find skill source (file or directory)
    source_info=$(find_skill_source "$dir")
    [[ -z "$source_info" ]] && continue  # No tool found in this directory
    
    source_type="${source_info%%:*}"
    source_path="${source_info#*:}"
    source_path="${source_path#*:}"  # Remove dir part, keep actual path
    
    # Determine SKILL.md location and extract skill name
    if [[ "$source_type" == "directory" ]]; then
        skill_file="$source_path/SKILL.md"
    else
        skill_file="$source_path"
    fi
    
    if [[ ! -f "$skill_file" ]]; then
        echo "Error: SKILL.md not found in $source_path" >&2
        exit 1
    fi
    
    # Extract skill name from frontmatter
    skill_name=$(sed -n '/^---$/,/^---$/{/^---$/d; /^name: /p}' "$skill_file" | sed 's/^name: //' | head -1)
    
    if [[ -z "$skill_name" ]]; then
        echo "Error: $(basename "$skill_file") missing frontmatter 'name'" >&2
        exit 1
    fi
    
    if [[ ! "$skill_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
        echo "Error: $(basename "$skill_file") has invalid skill name '$skill_name'" >&2
        exit 1
    fi
    
    # Check for duplicate skill names
    for entry in "${skill_map[@]}"; do
        existing_skill="${entry%%:*}"
        if [[ "$existing_skill" == "$skill_name" ]]; then
            existing_dir="${entry#*:}"
            existing_dir="${existing_dir%%:*}"
            echo "Error: Duplicate skill name '$skill_name' found in" >&2
            echo "  $existing_dir and $dir" >&2
            exit 1
        fi
    done
    
    skill_map+=("$skill_name:$source_type:$dir:$source_path")
done

# PHASE 3: Processing - Create symlinks
#
# Cleanup behavior:
#   - Full refresh (no args):  wipe entire skills dir, then regenerate all skills.
#                              This removes orphaned skills whose source was deleted.
#   - Partial refresh (args):  only remove per-skill entries that will be regenerated,
#                              leaving unrelated skills intact.
if $IS_FULL_REFRESH; then
    [[ "$TARGET_HARNESS" == "opencode" || "$TARGET_HARNESS" == "both" ]] && rm -rf "$OPENCODE_SKILLS_DIR"
    [[ "$TARGET_HARNESS" == "pi" || "$TARGET_HARNESS" == "both" ]] && rm -rf "$PI_SKILLS_DIR"
fi

# Ensure skill root directories exist for enabled harnesses
[[ "$TARGET_HARNESS" == "opencode" || "$TARGET_HARNESS" == "both" ]] && mkdir -p "$OPENCODE_SKILLS_DIR"
[[ "$TARGET_HARNESS" == "pi" || "$TARGET_HARNESS" == "both" ]] && mkdir -p "$PI_SKILLS_DIR"

for entry in "${skill_map[@]}"; do
    skill_name="${entry%%:*}"
    rest="${entry#*:}"
    source_type="${rest%%:*}"
    rest="${rest#*:}"
    source_dir="${rest%%:*}"
    source_path="${rest#*:}"
    
    # Remove any existing entry for this skill name before recreating.
    # On full refresh this is a no-op (parent was wiped). On partial refresh
    # this handles both forms (symlink to dir, or directory containing SKILL.md)
    # and transitions between the two forms cleanly.
    [[ "$TARGET_HARNESS" == "opencode" || "$TARGET_HARNESS" == "both" ]] && rm -rf "$OPENCODE_SKILLS_DIR/$skill_name"
    [[ "$TARGET_HARNESS" == "pi" || "$TARGET_HARNESS" == "both" ]] && rm -rf "$PI_SKILLS_DIR/$skill_name"
    
    if [[ "$source_type" == "directory" ]]; then
        # Directory structure: symlink to the directory itself
        if [[ "$TARGET_HARNESS" == "opencode" || "$TARGET_HARNESS" == "both" ]]; then
            rel_path=$(realpath --relative-to="$OPENCODE_SKILLS_DIR" "$source_path")
            ln -s "$rel_path" "$OPENCODE_SKILLS_DIR/$skill_name"
        fi
        
        if [[ "$TARGET_HARNESS" == "pi" || "$TARGET_HARNESS" == "both" ]]; then
            rel_path=$(realpath --relative-to="$PI_SKILLS_DIR" "$source_path")
            ln -s "$rel_path" "$PI_SKILLS_DIR/$skill_name"
        fi
        
        echo "$skill_name ← $(basename "$source_path")/"
    else
        # Single file structure: symlink to SKILL.md
        if [[ "$TARGET_HARNESS" == "opencode" || "$TARGET_HARNESS" == "both" ]]; then
            mkdir -p "$OPENCODE_SKILLS_DIR/$skill_name"
            rel_path=$(realpath --relative-to="$OPENCODE_SKILLS_DIR/$skill_name" "$source_path")
            ln -s "$rel_path" "$OPENCODE_SKILLS_DIR/$skill_name/SKILL.md"
        fi
        
        if [[ "$TARGET_HARNESS" == "pi" || "$TARGET_HARNESS" == "both" ]]; then
            mkdir -p "$PI_SKILLS_DIR/$skill_name"
            rel_path=$(realpath --relative-to="$PI_SKILLS_DIR/$skill_name" "$source_path")
            ln -s "$rel_path" "$PI_SKILLS_DIR/$skill_name/SKILL.md"
        fi
        
        echo "$skill_name ← $(basename "$source_path")"
    fi
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