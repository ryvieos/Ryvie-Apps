#!/bin/bash

# Script to increment version in x-app.yml for modified directories

# Get the list of changed files from the environment variable
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

# Function to increment patch version
increment_version() {
    local version=$1
    local major minor patch
    IFS='.' read -r major minor patch <<< "$version"
    patch=$((patch + 1))
    echo "$major.$minor.$patch"
}

# Process each changed directory
for dir in $CHANGED_DIRS; do
    APP_FILE="$dir/ryvie-app.yml"
    
    if [ -f "$APP_FILE" ]; then
        echo "Processing $APP_FILE"
        
        # Extract current version
        CURRENT_VERSION=$(grep -E '^version:' "$APP_FILE" | sed 's/version:[[:space:]]*//' | tr -d '"' | tr -d "'")
        
        if [ -n "$CURRENT_VERSION" ]; then
            NEW_VERSION=$(increment_version "$CURRENT_VERSION")
            
            # Update version in file
            sed -i "s/^version:.*/version: $NEW_VERSION/" "$APP_FILE"
            
            echo "  $CURRENT_VERSION -> $NEW_VERSION"
        else
            echo "  No version found in $APP_FILE"
        fi
    else
        echo "No app file found: $APP_FILE"
    fi
done

echo "Version increment complete"
