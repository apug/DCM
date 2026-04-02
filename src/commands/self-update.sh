current=$("$DCM_SELF" --version)

msg_info "Checking for updates (current: $current)..."

latest=$(curl -fsSL "https://api.github.com/repos/$DCM_GITHUB_REPO/releases/latest" \
  | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

if [ -z "$latest" ]; then
  msg_error "Could not fetch latest version from GitHub."
  exit 1
fi

if [ "$current" = "$latest" ]; then
  msg_success "Already up to date ($current)."
  exit 0
fi

msg_info "New version available: $latest. Updating..."

SELF="$DCM_SELF"
TMP=$(mktemp)

if ! curl -fsSL "https://github.com/$DCM_GITHUB_REPO/releases/download/$latest/dcm" -o "$TMP"; then
  rm -f "$TMP"
  msg_error "Failed to download dcm $latest."
  exit 1
fi

chmod +x "$TMP"
mv "$TMP" "$SELF"

msg_success "dcm updated to $latest."

# Overwrite sources.official with the version bundled in the new binary
if [ -d "$DCM_SOURCES_DIR" ]; then
  sources_write_official
  msg_success "sources.official updated."
fi
