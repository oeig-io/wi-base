#!/usr/bin/env bash

# Generate table of contents with links from markdown file
# Usage: toc.sh <file.md>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <file.md>"
    exit 1
fi

if [ ! -f "$1" ]; then
    echo "Error: File '$1' not found"
    exit 1
fi

sed '/```/,/```/d' "$1" | grep "^#" | grep -v "^####" | tail -n +3 | while IFS= read -r line; do
    # Determine heading level and extract text
    if [[ $line =~ ^###[[:space:]](.+)$ ]]; then
        text="${BASH_REMATCH[1]}"
        indent="  "
    elif [[ $line =~ ^##[[:space:]](.+)$ ]]; then
        text="${BASH_REMATCH[1]}"
        indent=""
    else
        continue
    fi

    # Generate anchor: lowercase, spaces to hyphens, remove special chars
    anchor=$(echo "$text" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')

    # Output with link
    echo "${indent}- [$text](#$anchor)"
done
