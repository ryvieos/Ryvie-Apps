#!/bin/bash
# ----------------------------------------------------------
# Script: generate_apps_json.sh
# Description: Generate apps.json from ryvie-app.yml metadata,
#              with automatic gallery URL generation.
#              Increments buildId only for modified apps.
#              Synchronizes buildId back to ryvie-app.yml files.
#              apps.json is the source of truth for buildIds.
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

# ------------------------------
# Get list of modified app directories
# ------------------------------
if [ -n "${GITHUB_SHA:-}" ] && [ -n "${GITHUB_EVENT_BEFORE:-}" ]; then
  echo "🔍 Detecting modified apps from git diff..."
  MODIFIED_APPS=$(git diff --name-only "$GITHUB_EVENT_BEFORE" "$GITHUB_SHA" \
    | grep -E '^[^/]+/' \
    | cut -d'/' -f1 \
    | sort -u)
  echo "Modified apps: $MODIFIED_APPS"
else
  echo "⚠️ Running locally - all apps will be considered modified"
  MODIFIED_APPS=""
fi

# ------------------------------
# Load previous apps.json buildIds
# ------------------------------
PREV_APPS_JSON=$(mktemp)
if git show HEAD~1:apps.json > "$PREV_APPS_JSON" 2>/dev/null; then
  echo "✅ Loaded previous apps.json from HEAD~1"
else
  echo "⚠️ No previous apps.json found - starting fresh"
  echo "[]" > "$PREV_APPS_JSON"
fi

# Function to get previous buildId for an app
get_previous_buildid() {
  local app_id="$1"
  jq -r --arg id "$app_id" '.[] | select(.id == $id) | .buildId // "0"' "$PREV_APPS_JSON"
}

# Function to check if app was modified
is_app_modified() {
  local app_dir="$1"
  if [ -z "$MODIFIED_APPS" ]; then
    return 0  # Consider all modified if not in GitHub Actions
  fi
  echo "$MODIFIED_APPS" | grep -qx "$app_dir"
}

# Initialize empty JSON array
echo "[]" > "$OUTPUT_FILE"

# Track if any YAML files were updated
YAML_UPDATED=false

# Loop over all ryvie-app.yml files
for app_file in */ryvie-app.yml; do
  if [ ! -f "$app_file" ]; then
    continue
  fi

  app_dir=$(basename "$(dirname "$app_file")")
  echo "🔹 Processing app: $app_dir"

  # Check required fields (buildId is NOT required anymore)
  required_fields=(manifestVersion id category name port gallery)
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

  # Get app ID
  app_id=$(echo "$app_json" | jq -r '.id')

  # Determine buildId (IGNORE value in YAML)
  prev_buildid=$(get_previous_buildid "$app_id")
  if is_app_modified "$app_dir"; then
    new_buildid=$((prev_buildid + 1))
    echo "  ✏️ App modified - incrementing buildId: $prev_buildid → $new_buildid"
  else
    new_buildid=$prev_buildid
    echo "  ⏭️ App unchanged - keeping buildId: $new_buildid"
  fi

  # Check if buildId in YAML differs from calculated value
  yaml_buildid=$(yq -r '.buildId // "null"' "$app_file")
  if [ "$yaml_buildid" != "$new_buildid" ]; then
    echo "  🔄 Synchronizing buildId in $app_file: $yaml_buildid → $new_buildid"
    yq -i ".buildId = $new_buildid" "$app_file"
    YAML_UPDATED=true
  fi

  # Add buildId to app JSON (overwrite whatever was in YAML)
  app_json=$(echo "$app_json" | jq --arg buildid "$new_buildid" '.buildId = ($buildid | tonumber)')

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

# Cleanup
rm -f "$PREV_APPS_JSON"

echo "✅ apps.json successfully generated!"

if [ "$YAML_UPDATED" = true ]; then
  echo "⚠️ Some ryvie-app.yml files were updated with correct buildIds"
  echo "   These changes need to be committed."
fi