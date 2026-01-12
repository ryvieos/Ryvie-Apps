#!/bin/bash

# Script to increment buildId in ryvie-app.yml for modified directories
# Improved: robust parsing of changed files, trims CRs/whitespace, logs directories processed

set -euo pipefail

CHANGED_FILES_RAW="$1"

if [ -z "$CHANGED_FILES_RAW" ]; then
    echo "No changed files provided"
    exit 0
fi

echo "Changed files raw: <$CHANGED_FILES_RAW>"

# Normalize to newline-separated list, remove CR, drop empty lines
mapfile -t FILES_ARRAY < <(echo "$CHANGED_FILES_RAW" | tr ' ' '\n' | tr -d '\r' | sed '/^$/d')

declare -A DIRS
for file in "${FILES_ARRAY[@]}"; do
    # Remove leading ./ if present, then take top-level directory
    file_clean=$(echo "$file" | sed 's|^\./||')
    dir=$(echo "$file_clean" | cut -d'/' -f1)

    if [ -n "$dir" ] && [ "$dir" != "." ] && [ "$dir" != ".github" ]; then
        DIRS["$dir"]=1
    fi
done

if [ ${#DIRS[@]} -eq 0 ]; then
    echo "No relevant directories changed"
    exit 0
fi

# Sort directory names for deterministic behavior
CHANGED_DIRS_SORTED=$(printf "%s\n" "${!DIRS[@]}" | sort)

echo "Detected changed directories: $CHANGED_DIRS_SORTED"

# Process each changed directory
while IFS= read -r dir; do
    APP_FILE="$dir/ryvie-app.yml"

    if [ -f "$APP_FILE" ]; then
        echo "Processing $APP_FILE"

        # Extract current buildId using awk (robust against spaces)
        CURRENT_BUILD_ID=$(awk -F":" '/^buildId[[:space:]]*:/{gsub(/^[ \\t]+|[ \\t]+$/,"",$2); print $2; exit}' "$APP_FILE" | tr -d '[:space:]') || true

        if [[ "$CURRENT_BUILD_ID" =~ ^[0-9]+$ ]]; then
            NEW_BUILD_ID=$((CURRENT_BUILD_ID + 1))

            # Update buildId in file using a precise regex (only replaces numeric buildId)
            sed -i -E "s/^(buildId[[:space:]]*:[[:space:]]*)[0-9]+/\1$NEW_BUILD_ID/" "$APP_FILE"

            echo "  buildId: $CURRENT_BUILD_ID -> $NEW_BUILD_ID"
        else
            echo "  No valid buildId found in $APP_FILE"
        fi
    else
        echo "No app file found: $APP_FILE"
    fi

done <<< "$CHANGED_DIRS_SORTED"

echo "buildId increment complete"
