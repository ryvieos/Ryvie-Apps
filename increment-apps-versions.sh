#!/bin/bash

# Script to increment buildId in ryvie-app.yml for modified directories

CHANGED_FILES="$1"

if [ -z "$CHANGED_FILES" ]; then
    echo "No changed files provided"
    exit 0
fi

# Extract unique directories (excluding .github)
CHANGED_DIRS=$(echo "$CHANGED_FILES" | tr ' ' '\n' | while read -r file; do
    dir=$(dirname "$file" | cut -d'/' -f1)
    if [ "$dir" != "." ] && [ "$dir" != ".github" ]; then
        echo "$dir"
    fi
done | sort -u)

if [ -z "$CHANGED_DIRS" ]; then
    echo "No relevant directories changed"
    exit 0
fi

# Process each changed directory
for dir in $CHANGED_DIRS; do
    APP_FILE="$dir/ryvie-app.yml"

    if [ -f "$APP_FILE" ]; then
        echo "Processing $APP_FILE"

        # Extract current buildId
        CURRENT_BUILD_ID=$(grep -E '^buildId:' "$APP_FILE" | sed 's/buildId:[[:space:]]*//')

        if [[ "$CURRENT_BUILD_ID" =~ ^[0-9]+$ ]]; then
            NEW_BUILD_ID=$((CURRENT_BUILD_ID + 1))

            # Update buildId in file
            sed -i "s/^buildId:.*/buildId: $NEW_BUILD_ID/" "$APP_FILE"

            echo "  buildId: $CURRENT_BUILD_ID -> $NEW_BUILD_ID"
        else
            echo "  No valid buildId found in $APP_FILE"
        fi
    else
        echo "No app file found: $APP_FILE"
    fi
done

echo "buildId increment complete"
