## Source file management — manages state/sources/

# Write (or overwrite) sources.official with the bundled content.
# Called by both init and self-update to keep it in sync with the DCM version.
sources_write_official() {
  mkdir -p "$DCM_SOURCES_DIR"
  cat > "$DCM_SOURCES_OFFICIAL" <<'EOF'
# DCM Official Sources
# This file is managed by DCM. Do not edit manually.
# Add your own repositories with: dcm repo register <url>
# Add third-party sources with:   dcm repo add-source <url>

- name: DcmBase
  url: git@github.com:apug/DcmBase.git

- name: DcmPhp
  url: git@github.com:apug/DcmPhp.git
EOF
}

# Derive source name from file path
sources_name_from_file() {
  local file
  file=$(basename "$1")
  case "$file" in
    sources.official) echo "official" ;;
    sources.local)    echo "local" ;;
    *)                echo "${file%.yml}" ;;
  esac
}

# List all source files in load order: official, local, extras
sources_list_files() {
  if [ -f "$DCM_SOURCES_OFFICIAL" ]; then echo "$DCM_SOURCES_OFFICIAL"; fi
  if [ -f "$DCM_SOURCES_LOCAL" ]; then echo "$DCM_SOURCES_LOCAL"; fi
  if [ -d "$DCM_SOURCES_EXTRA_DIR" ]; then
    for f in "$DCM_SOURCES_EXTRA_DIR"/*.yml; do
      if [ -f "$f" ]; then echo "$f"; fi
    done
  fi
}

# Parse a single source file.
# Outputs one line per entry: source|name|url|branch
sources_parse_file() {
  local source_name="$1"
  local file="$2"
  [ -f "$file" ] || return 0

  local name="" url="" branch=""
  while IFS= read -r line; do
    case "$line" in
      "- name: "*)
        if [ -n "$name" ] && [ -n "$url" ]; then
          echo "$source_name|$name|$url|$branch"
        fi
        name="${line#- name: }"
        url=""
        branch=""
        ;;
      "  url: "*)
        url="${line#  url: }"
        ;;
      "  branch: "*)
        branch="${line#  branch: }"
        ;;
    esac
  done < "$file"
  if [ -n "$name" ] && [ -n "$url" ]; then
    echo "$source_name|$name|$url|$branch"
  fi
  return 0
}

# Get all entries from all source files: source|name|url|branch
sources_get_all_entries() {
  while IFS= read -r file; do
    local src
    src=$(sources_name_from_file "$file")
    sources_parse_file "$src" "$file"
  done < <(sources_list_files)
}

# Find entries for a repo by name (optionally namespaced as source/name).
# Outputs matching lines: source|name|url|branch
sources_find() {
  local query="$1"
  local filter_source="" filter_name=""

  if [[ "$query" == */* ]]; then
    filter_source="${query%%/*}"
    filter_name="${query##*/}"
  else
    filter_name="$query"
  fi

  sources_get_all_entries | while IFS='|' read -r src name url branch; do
    if [ -n "$filter_source" ]; then
      if [ "$src" = "$filter_source" ] && [ "$name" = "$filter_name" ]; then
        echo "$src|$name|$url|$branch"
      fi
    else
      if [ "$name" = "$filter_name" ]; then
        echo "$src|$name|$url|$branch"
      fi
    fi
  done
}

# Add an entry to sources.local (or update if name already present).
# Usage: sources_local_register <name> <url> [branch]
sources_local_register() {
  local name="$1"
  local url="$2"
  local branch="${3:-}"

  mkdir -p "$DCM_SOURCES_DIR"
  touch "$DCM_SOURCES_LOCAL"

  # Remove existing entry for this name
  sources_local_unregister "$name" 2>/dev/null || true

  {
    echo "- name: $name"
    echo "  url: $url"
    [ -n "$branch" ] && echo "  branch: $branch"
  } >> "$DCM_SOURCES_LOCAL"
}

# Remove an entry from sources.local by name.
sources_local_unregister() {
  local name="$1"
  [ -f "$DCM_SOURCES_LOCAL" ] || return 0

  local tmp
  tmp=$(mktemp)
  awk -v name="$name" '
    /^- name: / { skip=($0 == "- name: " name) }
    !skip { print }
  ' "$DCM_SOURCES_LOCAL" > "$tmp"
  mv "$tmp" "$DCM_SOURCES_LOCAL"
}

# Fetch and cache the dcm.yml manifest for a repo.
# For installed repos, reads from the local clone.
# For others, uses a sparse clone (works with any git server and credentials).
# Usage: sources_fetch_manifest <source> <name> <url> [branch]
sources_fetch_manifest() {
  local src="$1"
  local name="$2"
  local url="$3"
  local branch="${4:-}"

  local cache_dir="$DCM_SOURCES_CACHE_DIR/$src"
  mkdir -p "$cache_dir"

  # Prefer local clone if already installed
  if [ -f "repos/$name/dcm.yml" ]; then
    cp "repos/$name/dcm.yml" "$cache_dir/$name.yml"
    return 0
  fi

  # Sparse clone to fetch only dcm.yml — works with any git server
  local tmp_dir
  tmp_dir=$(mktemp -d)

  local clone_cmd="git clone --depth=1 --filter=blob:none --no-checkout --quiet"
  if [ -n "$branch" ]; then
    clone_cmd="$clone_cmd --branch $branch"
  fi

  if ! $clone_cmd "$url" "$tmp_dir" 2>/dev/null; then
    rm -rf "$tmp_dir"
    msg_warning "Cannot reach '$name' ($url)"
    return 1
  fi

  if ! git -C "$tmp_dir" checkout HEAD -- dcm.yml 2>/dev/null; then
    rm -rf "$tmp_dir"
    msg_warning "No dcm.yml found in '$name'"
    return 1
  fi

  cp "$tmp_dir/dcm.yml" "$cache_dir/$name.yml"
  rm -rf "$tmp_dir"
}

# Read a field from a cached manifest.
# Usage: sources_manifest_get <source> <name> <field>
sources_manifest_get() {
  local src="$1"
  local name="$2"
  local field="$3"
  local cache_file="$DCM_SOURCES_CACHE_DIR/$src/$name.yml"
  [ -f "$cache_file" ] || return 1
  grep "^$field:" "$cache_file" | head -1 | sed "s/^$field:[[:space:]]*//"
}

# Check if a repo is installed (cloned in repos/).
sources_is_installed() {
  [ -d "repos/$1" ]
}
