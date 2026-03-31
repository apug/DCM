## Repository manifest helpers — manages state/repos.yml

# Ensure repos.yml exists
repos_file_init() {
  [ -f "$DCM_REPOS_FILE" ] || touch "$DCM_REPOS_FILE"
}

# Add or update a repo entry in repos.yml
# Usage: repos_register <name> <url> [branch]
repos_register() {
  local name="$1"
  local url="$2"
  local branch="${3:-}"

  repos_file_init

  # Remove existing entry for this name (if any)
  repos_unregister "$name" 2>/dev/null || true

  {
    echo "- name: $name"
    echo "  url: $url"
    [ -n "$branch" ] && echo "  branch: $branch"
  } >> "$DCM_REPOS_FILE"
}

# Remove a repo entry by name
# Usage: repos_unregister <name>
repos_unregister() {
  local name="$1"
  [ -f "$DCM_REPOS_FILE" ] || return 0

  # Build a temp file without the block for this name
  local tmp
  tmp=$(mktemp)
  awk -v name="$name" '
    /^- name: / {
      if ($0 == "- name: " name) { skip=1 } else { skip=0 }
    }
    /^- name: / && skip==0 { print; next }
    !skip { print }
  ' "$DCM_REPOS_FILE" > "$tmp"
  mv "$tmp" "$DCM_REPOS_FILE"
}

# List all registered repo names
repos_get_names() {
  [ -f "$DCM_REPOS_FILE" ] || return 0
  grep '^- name:' "$DCM_REPOS_FILE" | sed 's/^- name: *//'
}

# Get the URL for a registered repo
# Usage: repos_get_url <name>
repos_get_url() {
  local name="$1"
  [ -f "$DCM_REPOS_FILE" ] || return 0
  awk -v name="$name" '
    /^- name: / { found=($0 == "- name: " name) }
    found && /^  url: / { sub(/^  url: */, ""); print; exit }
  ' "$DCM_REPOS_FILE"
}

# Get the branch for a registered repo (empty if not set)
# Usage: repos_get_branch <name>
repos_get_branch() {
  local name="$1"
  [ -f "$DCM_REPOS_FILE" ] || return 0
  awk -v name="$name" '
    /^- name: / { found=($0 == "- name: " name) }
    found && /^- name: / && $0 != "- name: " name { exit }
    found && /^  branch: / { sub(/^  branch: */, ""); print; exit }
  ' "$DCM_REPOS_FILE"
}
