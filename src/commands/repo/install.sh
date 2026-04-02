require_init --env
load_env

query="${args[name]}"

# Find repo in source files
matches=$(sources_find "$query")
count=$(echo "$matches" | grep -c '.' 2>/dev/null || echo 0)
[ -z "$matches" ] && count=0

if [ -z "$matches" ] || [ "$count" -eq 0 ]; then
  msg_error "Repo '$query' not found in any source."
  msg_info "Run 'dcm repo update' to refresh the index, or 'dcm repo register <url>' to add it manually."
  exit 1
fi

if [ "$count" -gt 1 ]; then
  sources_list=$(echo "$matches" | cut -d'|' -f1 | paste -sd', ')
  msg_error "'$query' found in multiple sources: $sources_list"
  echo ""
  echo "$matches" | while IFS='|' read -r src name url _branch; do
    echo "  dcm repo install $src/$name"
  done
  exit 1
fi

IFS='|' read -r src name url branch <<< "$matches"

if [ -d "repos/$name" ]; then
  msg_warning "Repo '$name' is already installed."
  exit 0
fi

msg_info "Installing $name from [$src] $url${branch:+ (branch: $branch)}..."

if [ -n "$branch" ]; then
  git clone --branch "$branch" "$url" "repos/$name"
else
  git clone "$url" "repos/$name"
fi

if [ $? -ne 0 ]; then
  msg_error "Failed to clone $url"
  exit 1
fi

repos_register "$name" "$url" "$branch" "$src"
msg_success "Installed: $name"

if ! conflicts_check_repo "$name" "warn"; then
  msg_warning "Enabling conflicting services will cause Docker Compose errors."
fi
