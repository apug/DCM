require_init --env
load_env

url="${args[url]}"
branch="${args[--branch]:-}"

repo_name=$(basename "$url" .git)
name=$(to_pascal_case "$repo_name")

# Add to sources.local
sources_local_register "$name" "$url" "$branch"
msg_success "Registered '$name' in sources.local"

# Install (clone + add to repos.yml)
if [ -d "repos/$name" ]; then
  msg_warning "Repo '$name' is already installed."
  exit 0
fi

msg_info "Installing $name from $url${branch:+ (branch: $branch)}..."

if [ -n "$branch" ]; then
  git clone --branch "$branch" "$url" "repos/$name"
else
  git clone "$url" "repos/$name"
fi

if [ $? -ne 0 ]; then
  msg_error "Failed to clone $url"
  exit 1
fi

repos_register "$name" "$url" "$branch" "local"
msg_success "Installed: $name"

if ! conflicts_check_repo "$name" "warn"; then
  msg_warning "Enabling conflicting services will cause Docker Compose errors."
fi
