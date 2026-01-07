require_init --env

msg_info "Fetching updates..."
git fetch --tags origin

if [ -n "${args[--branch]}" ]; then
  branch="${args[--branch]}"
  git checkout "$branch"
  git pull origin "$branch"
  msg_success "Updated to latest commit on branch '$branch'."
  exit 0
fi

latest=$(git ls-remote --tags --sort=version:refname origin \
  2>/dev/null | grep -v '\^{}' | tail -1 | sed 's|.*refs/tags/||')

if [ -z "$latest" ]; then
  git pull origin HEAD
  msg_success "Updated to latest commit."
else
  current=$(git describe --tags --abbrev=0 2>/dev/null || echo "untagged")
  if [ "$current" = "$latest" ]; then
    msg_success "Already at latest version: $latest"
    exit 0
  fi
  git checkout "$latest"
  msg_success "Updated to $latest"
fi
