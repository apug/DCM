# Ensure repos directory exists
if [ ! -d "repos" ]; then
  msg_error "repos directory not found. Please run 'dcm init' first."
  exit 1
fi

# Get arguments from args array
url="${args[url]}"
branch="${args[--branch]}"

# Extract repo name from URL and convert to PascalCase
repo_name=$(basename "$url" .git)
directory=$(to_pascal_case "$repo_name")

# Clone the repository
msg_info "Cloning $url into repos/$directory..."
if [ -n "$branch" ]; then
  git clone --branch "$branch" "$url" "repos/$directory"
else
  git clone "$url" "repos/$directory"
fi

if [ $? -eq 0 ]; then
  msg_success "Repository cloned successfully!"
  if ! conflicts_check_repo "$directory" "warn"; then
    msg_warning "Enabling conflicting services will cause Docker Compose errors."
  fi
else
  msg_error "Failed to clone repository."
  exit 1
fi
