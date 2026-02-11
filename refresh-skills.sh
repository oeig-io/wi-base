#!/bin/bash
# refresh-skills.sh - Create symlinks from wi-*/tool files to .opencode/skills/
# 
# Usage: ./wi-base/refresh-skills.sh <wi-directory>
# Example: ./wi-base/refresh-skills.sh wi-idempiere
# 
# Exit codes: 0 = success, non-zero = error

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Error: Usage: $0 <wi-directory>" >&2
    exit 1
fi

TARGET_DIR="$1"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: Directory '$TARGET_DIR' does not exist" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.opencode/skills"

rm -rf "$SKILLS_DIR"
mkdir -p "$SKILLS_DIR"

for file in "$REPO_ROOT/$TARGET_DIR"/*-tool.md; do
    [[ -f "$file" ]] || continue
    
    filename=$(basename "$file")
    
    skill_name=$(sed -n '/^---$/,/^---$/{/^---$/d; /^name: /p}' "$file" | sed 's/^name: //' | head -1)
    
    if [[ -z "$skill_name" ]]; then
        echo "Error: $filename missing frontmatter 'name'" >&2
        exit 1
    fi
    
    if [[ ! "$skill_name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
        echo "Error: $filename has invalid skill name '$skill_name'" >&2
        exit 1
    fi
    
    mkdir -p "$SKILLS_DIR/$skill_name"
    
    rel_path=$(realpath --relative-to="$SKILLS_DIR/$skill_name" "$file")
    ln -s "$rel_path" "$SKILLS_DIR/$skill_name/SKILL.md"
    
    echo "$skill_name ← $filename"
done

echo ""
echo "Skills refreshed in .opencode/skills/"
