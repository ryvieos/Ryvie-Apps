#!/bin/bash
# ----------------------------------------------------------
# Script: generate_apps_json.sh
# Description: Generate apps.json from ryvie-app.yml metadata,
#              with automatic gallery URL generation.
#              Skip apps without a gallery.
#              Adapted for GitHub Actions (non-interactive).
# ----------------------------------------------------------

set -euo pipefail

# ------------------------------
# Check dependencies
# ------------------------------
command -v jq >/dev/null 2>&1 || { echo "❌ jq is not installed. Exiting."; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "❌ yq is not installed. Exiting."; exit 1; }

# ------------------------------
# Variables
# ------------------------------
OUTPUT_FILE="apps.json"
GITHUB_REPO="ryvieos/Ryvie-Gallery"
BRANCH="main"

echo "🧩 Generating ${OUTPUT_FILE} from */ryvie-app.yml..."

# Initialize empty JSON array
echo "[]" > "$OUTPUT_FILE"

# Loop over all ryvie-app.yml files
for app_file in */ryvie-app.yml; do
  if [ ! -f "$app_file" ]; then
    continue
  fi

  app_dir=$(basename "$(dirname "$app_file")")
  echo "🔹 Processing app: $app_dir"

# Check required fields
required_fields=(manifestVersion id category buildId name port gallery)
missing=false

for field in "${required_fields[@]}"; do
  if ! yq -e ".${field}" "$app_file" >/dev/null 2>&1; then
    echo "⚠️ Missing required field '$field' in $app_file"
    missing=true
  fi
done

if [ "$missing" = true ]; then
  echo "⚠️ Skipping $app_dir due to missing required fields"
  continue
fi

# Verify gallery images exist
missing_icon=false
for image in $(yq -o=json '.gallery[]' "$app_file" | jq -r '.'); do
  url="https://cdn.jsdelivr.net/gh/$GITHUB_REPO@$BRANCH/$app_dir/$image"
  if ! curl --head --silent --fail "$url" >/dev/null; then
    if [ "$image" = "icon.png" ]; then
      echo "⚠️ Missing icon.png for $app_dir — skipping app"
      missing_icon=true
      break
    else
      echo "⚠️ Missing gallery image: $url"
    fi
  fi
done

if [ "$missing_icon" = true ]; then
  continue
fi

  # Extract YAML content as JSON
  if ! app_json=$(yq -o=json '.' "$app_file"); then
    echo "⚠️ Failed to parse YAML: $app_file — skipping $app_dir"
    continue
  fi

  # Add gallery URLs dynamically
  gallery_json=$(yq -o=json '.gallery' "$app_file" | jq -r --arg repo "$GITHUB_REPO" --arg branch "$BRANCH" --arg app "$app_dir" '
    map("https://cdn.jsdelivr.net/gh/\($repo)@\($branch)/\($app)/" + .)
  ')

  # Merge gallery into app JSON
  app_json=$(echo "$app_json" | jq --argjson gallery "$gallery_json" '.gallery = $gallery')

  # Append to main JSON
  tmp=$(mktemp)
  jq ". + [${app_json}]" "$OUTPUT_FILE" > "$tmp" && mv "$tmp" "$OUTPUT_FILE"
done

echo "✅ apps.json successfully generated!"
