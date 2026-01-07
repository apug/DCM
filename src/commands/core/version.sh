require_init --env

current=$(git describe --tags --abbrev=0 2>/dev/null || echo "untagged")
latest=$(git ls-remote --tags --sort=version:refname origin \
  2>/dev/null | grep -v '\^{}' | tail -1 | sed 's|.*refs/tags/||')

echo "Current version : $current"
echo "Latest version  : ${latest:-unknown}"

if [ -n "$latest" ] && [ "$current" != "$latest" ]; then
  msg_warning "Update available: $latest"
  echo "Run 'dcm core update' to install it."
else
  msg_success "Up to date."
fi
