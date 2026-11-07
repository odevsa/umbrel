set shell := ["bash", "-euo", "pipefail", "-c"]

# Check repositories and update versions in umbrel-app.yml files
update:
    @for manifest in */umbrel-app.yml; do \
        [ -f "$manifest" ] || continue; \
        app_id=$(dirname "$manifest"); \
        current_version=$(grep -E '^[[:space:]]*version:' "$manifest" | head -n1 | sed -E 's/^[[:space:]]*version:[[:space:]]*["'\'']?([^"'\'']+)["'\'']?.*$/\1/'); \
        repo_url=$(grep -E '^[[:space:]]*repo:' "$manifest" | head -n1 | sed -E 's/^[[:space:]]*repo:[[:space:]]*["'\'']?([^"'\'']+)["'\'']?.*$/\1/'); \
        [ -n "$current_version" ] || { echo "[$app_id] No version found in $manifest"; continue; }; \
        [ -n "$repo_url" ] || { echo "[$app_id] No repository found in $manifest"; continue; }; \
        repo_path=$(echo "$repo_url" | sed -E 's#^https?://github\.com/([^/]+/[^/.]+).*#\1#'); \
        echo "Checking $app_id (current: $current_version) -> $repo_path..."; \
        release_json=$(curl -sSL -H "Accept: application/vnd.github+json" -H "User-Agent: umbrel-updater" "https://api.github.com/repos/$repo_path/releases/latest" 2>/dev/null || true); \
        latest_tag=$(echo "$release_json" | jq -r '.tag_name // empty' 2>/dev/null || true); \
        if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then \
            tags_json=$(curl -sSL -H "Accept: application/vnd.github+json" -H "User-Agent: umbrel-updater" "https://api.github.com/repos/$repo_path/tags" 2>/dev/null || true); \
            latest_tag=$(echo "$tags_json" | jq -r '.[0].name // empty' 2>/dev/null || true); \
        fi; \
        if [ -z "$latest_tag" ] || [ "$latest_tag" = "null" ]; then \
            echo "  Warning: Unable to fetch latest version for $repo_path"; \
            continue; \
        fi; \
        clean_version="${latest_tag#v}"; \
        clean_version="${clean_version#V}"; \
        if [ "$clean_version" != "$current_version" ]; then \
            echo "  -> Updating $app_id: $current_version -> $clean_version"; \
            sed -i -E "s/^([[:space:]]*version:[[:space:]]*[\"']?)[^\"']*(.*)$/\1${clean_version}\2/" "$manifest"; \
        else \
            echo "  -> $app_id is already on latest version ($current_version)"; \
        fi; \
    done
