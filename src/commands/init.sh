# Create DockManager directories
BASEDIR=$PWD/state/services
mkdir -p repos "$BASEDIR/config" "$BASEDIR/volumes" "$BASEDIR/compose" \
  "$DCM_SOURCES_DIR" "$DCM_SOURCES_EXTRA_DIR" "$DCM_SOURCES_CACHE_DIR"

# Resolve real UID/GID (UID is read-only in bash, use id command)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Create .env file with DCM_* variables (absolute paths)
cat >.env <<EOF
DCM_ROOT=$BASEDIR
DCM_CONFIG_DIR=$BASEDIR/config
DCM_VOLUMES_DIR=$BASEDIR/volumes
DCM_UID=$CURRENT_UID
DCM_GID=$CURRENT_GID
DCM_PROXY_SERVICE=_dcm/Caddy
EOF

# Always regenerate compose.yml to keep it in sync with DCM paths
write_compose_yml
msg_success "compose.yml updated."

msg_success "DockManager initialized successfully!"
echo ""
msg_info "Created directories:"
echo "  - $PWD/repos/             (for git repositories)"
echo "  - $BASEDIR/config/   (for configuration files)"
echo "  - $BASEDIR/volumes/  (for docker volumes)"
echo "  - $BASEDIR/compose/  (for compose files and services.yml)"
echo ""
msg_info "Created .env file with:"
echo "  - DCM_ROOT=$BASEDIR"
echo "  - DCM_CONFIG_DIR=$BASEDIR/config"
echo "  - DCM_VOLUMES_DIR=$BASEDIR/volumes"
echo "  - DCM_UID=$CURRENT_UID"
echo "  - DCM_GID=$CURRENT_GID"
echo "  - DCM_PROXY_SERVICE=_dcm/Caddy"
echo ""

# Always overwrite sources.official to keep it in sync with this DCM version
sources_write_official
msg_success "sources.official updated."

# Download built-in services if missing
if [ ! -d "$DCM_BUILTIN_SERVICES" ]; then
  DCM_VERSION=$("$0" --version)
  SERVICES_URL="https://github.com/$DCM_GITHUB_REPO/releases/download/$DCM_VERSION/services.tgz"
  msg_info "Built-in services not found. Downloading $DCM_VERSION..."
  if ! curl -fsSL "$SERVICES_URL" | tar -xz; then
    msg_error "Failed to download services from $SERVICES_URL"
    exit 1
  fi
  msg_success "Built-in services downloaded."
  echo ""
fi

# Initialize services.yml and auto-enable all built-in services
if [ ! -f "$DCM_SERVICES_FILE" ]; then
  echo "include:" > "$DCM_SERVICES_FILE"
fi

echo ""
msg_info "Enabling built-in services..."

for compose_file in $DCM_BUILTIN_SERVICES/*/compose.yml; do
  [ -f "$compose_file" ] || continue
  service=$(basename "$(dirname "$compose_file")")
  service_name="_dcm/$service"
  include_path="${DCM_INCLUDE_PREFIX}$DCM_BUILTIN_SERVICES/$service/compose.yml"

  if grep -qF "  - $include_path" "$DCM_SERVICES_FILE" 2>/dev/null; then
    msg_warning "Built-in service '$service_name' already enabled"
    continue
  fi

  echo "  - $include_path" >> "$DCM_SERVICES_FILE"

  containers=()
  while IFS= read -r container; do
    [ -n "$container" ] && containers+=("$container")
  done < <(grep -A 100 "^services:" "$compose_file" | grep "^  [a-zA-Z0-9_-]\+:" | awk '{print $1}' | sed 's/:$//')

  service_config_enable "$service_name" "${containers[@]}"
  caddy_add_service "$service_name"
  configure_service "$service_name"
  msg_success "Enabled built-in service: $service_name"
done

echo ""
msg_info "Run 'dcm service enable' to enable your services, then 'dcm service up' to start them."

# Install shell completion based on current shell
echo ""
case "${SHELL##*/}" in
  bash)
    if "$0" completion --install bash &>/dev/null; then
      msg_success "Bash completion installed (~/.bash_completion.d/dcm)"
      msg_info "Add 'source ~/.bash_completion.d/dcm' to your ~/.bashrc to activate."
    fi
    ;;
  zsh)
    if "$0" completion --install zsh &>/dev/null; then
      msg_success "Zsh completion installed (~/.zsh/completions/_dcm)"
      msg_info "Ensure your ~/.zshrc has: fpath=(~/.zsh/completions \$fpath) && autoload -Uz compinit && compinit"
    fi
    ;;
esac
