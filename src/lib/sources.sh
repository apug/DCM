## Source file management — manages state/sources/

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
  [ -f "$DCM_SOURCES_OFFICIAL" ] && echo "$DCM_SOURCES_OFFICIAL"
  [ -f "$DCM_SOURCES_LOCAL" ]    && echo "$DCM_SOURCES_LOCAL"
  if [ -d "$DCM_SOURCES_EXTRA_DIR" ]; then
    for f in "$DCM_SOURCES_EXTRA_DIR"/*.yml; do
      [ -f "$f" ] && echo "$f"
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
      [ "$src" = "$filter_source" ] && [ "$name" = "$filter_name" ] && echo "$src|$name|$url|$branch"
    else
      [ "$name" = "$filter_name" ] && echo "$src|$name|$url|$branch"
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

# Build the raw URL to fetch a file from a git repo.
# Usage: sources_raw_url <git_url> <branch> [file]
sources_raw_url() {
  local url="${1%.git}"
  local branch="${2:-main}"
  local file="${3:-dcm.yml}"

  case "$url" in
    https://github.com/*)
      local path="${url#https://github.com/}"
      echo "https://raw.githubusercontent.com/$path/$branch/$file"
      ;;
    https://gitlab.com/*)
      echo "$url/-/raw/$branch/$file"
      ;;
    *)
      echo ""
      ;;
  esac
}

# Detect the default branch of a remote git repo.
sources_default_branch() {
  local url="$1"
  git ls-remote --symref "$url" HEAD 2>/dev/null \
    | grep '^ref:' \
    | sed 's|.*refs/heads/||; s|[[:space:]].*||'
}

# Fetch and cache the dcm.yml manifest for a repo.
# For installed repos, reads from the local clone.
# For others, fetches via raw URL.
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

  # Resolve branch
  if [ -z "$branch" ]; then
    branch=$(sources_default_branch "$url")
    [ -z "$branch" ] && branch="main"
  fi

  local raw_url
  raw_url=$(sources_raw_url "$url" "$branch")

  if [ -z "$raw_url" ]; then
    msg_warning "Cannot fetch manifest for '$name': unsupported host"
    return 1
  fi

  if curl -fsSL "$raw_url" -o "$cache_dir/$name.yml" 2>/dev/null; then
    return 0
  else
    rm -f "$cache_dir/$name.yml"
    msg_warning "No dcm.yml found for '$name'"
    return 1
  fi
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
