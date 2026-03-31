#!/usr/bin/env bash
set -euo pipefail

REPO="apug/DCM"

info()    { printf '\e[34m[dcm]\e[0m %s\n' "$*"; }
success() { printf '\e[32m[dcm]\e[0m %s\n' "$*"; }
error()   { printf '\e[31m[dcm]\e[0m %s\n' "$*" >&2; exit 1; }

command -v curl &>/dev/null || error "curl is required"

# Choose install location
USER_BIN="${HOME}/.local/bin"
SYSTEM_BIN="/usr/local/bin"
CURRENT_DIR="$(pwd)"

printf '\n'
printf '\e[1mWhere do you want to install dcm?\e[0m\n'
printf '  1) %s  (system-wide, requires sudo)\n' "$SYSTEM_BIN"
printf '  2) %s  (current user)\n' "$USER_BIN"
printf '  3) %s  (current directory)\n' "$CURRENT_DIR"
printf '\n'
printf 'Choice [1/2/3] (default: 2): '
read -r choice </dev/tty
choice="${choice:-2}"

case "$choice" in
  1) INSTALL_DIR="$SYSTEM_BIN";  USE_SUDO=true  ;;
  2) INSTALL_DIR="$USER_BIN";    USE_SUDO=false ;;
  3) INSTALL_DIR="$CURRENT_DIR"; USE_SUDO=false ;;
  *) error "Invalid choice: $choice" ;;
esac

info "Fetching latest release..."
VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
[ -n "$VERSION" ] || error "Could not determine latest version"
info "Latest version: $VERSION"

info "Downloading dcm..."
TMP_FILE="$(mktemp)"
curl -fsSL "https://github.com/$REPO/releases/download/$VERSION/dcm" -o "$TMP_FILE"
chmod +x "$TMP_FILE"

mkdir -p "$INSTALL_DIR"

if [ "$USE_SUDO" = true ]; then
  sudo mv "$TMP_FILE" "$INSTALL_DIR/dcm"
else
  mv "$TMP_FILE" "$INSTALL_DIR/dcm"
fi

success "dcm $VERSION installed to $INSTALL_DIR/dcm"

if [ "$choice" = "2" ] && [[ ":$PATH:" != *":$USER_BIN:"* ]]; then
  printf '\n'
  info "Add the following to your shell profile to use dcm from anywhere:"
  printf '  export PATH="%s:$PATH"\n' "$USER_BIN"
fi

success "Run 'dcm init' to get started."
