#!/usr/bin/env bash
set -euo pipefail

REPO="apug/DCM"

info()    { printf '\e[34m[dcm]\e[0m %s\n' "$*"; }
success() { printf '\e[32m[dcm]\e[0m %s\n' "$*"; }
error()   { printf '\e[31m[dcm]\e[0m %s\n' "$*" >&2; exit 1; }

command -v curl &>/dev/null || error "curl is required"

info "Fetching latest release..."
VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
[ -n "$VERSION" ] || error "Could not determine latest version"
info "Latest version: $VERSION"

info "Downloading dcm..."
curl -fsSL "https://github.com/$REPO/releases/download/$VERSION/dcm" -o dcm
chmod +x dcm

success "dcm $VERSION downloaded to $(pwd)/dcm"
success "Run './dcm init' to get started."
