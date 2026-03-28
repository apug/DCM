require_init --env
load_env

url="${args[url]}"
branch="${args[--branch]:-}"

repo_name=$(basename "$url" .git)
name=$(to_pascal_case "$repo_name")

repos_register "$name" "$url" "$branch"

msg_success "Registered '$name' → $url${branch:+ (branch: $branch)}"
