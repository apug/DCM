require_init
load_env

updated=0
failed=0
any_disabled=0

_pull_repo() {
  local repo_name="$1"
  msg_info "Updating $repo_name..."
  if git -C "repos/$repo_name" pull; then
    updated=$((updated + 1))
    CONFLICTS_DISABLED_COUNT=0
    conflicts_check_repo "$repo_name" "disable"
    if [ "$CONFLICTS_DISABLED_COUNT" -gt 0 ]; then
      any_disabled=$((any_disabled + CONFLICTS_DISABLED_COUNT))
    fi
  else
    msg_error "Failed to update $repo_name"
    failed=$((failed + 1))
  fi
}

if [ -n "${args[repos]}" ]; then
  # Update only specified repositories
  eval "repos_to_update=(${args[repos]})"
  for repo_name in "${repos_to_update[@]}"; do
    if [ ! -d "repos/$repo_name" ]; then
      msg_error "Repository '$repo_name' not found in repos directory."
      failed=$((failed + 1))
      continue
    fi
    echo ""
    _pull_repo "$repo_name"
  done
else
  # Sync mode: synchronize filesystem with repos.yml
  msg_info "Syncing repositories from .dcm/repos.yml..."
  echo ""

  # Get registered names
  mapfile -t registered < <(repos_get_names)

  # Clone repos in manifest but not on disk
  for name in "${registered[@]}"; do
    if [ ! -d "repos/$name" ]; then
      url=$(repos_get_url "$name")
      branch=$(repos_get_branch "$name")
      msg_info "Cloning missing repo: $name..."
      if [ -n "$branch" ]; then
        git clone --branch "$branch" "$url" "repos/$name"
      else
        git clone "$url" "repos/$name"
      fi
      if [ $? -eq 0 ]; then
        updated=$((updated + 1))
      else
        msg_error "Failed to clone $name"
        failed=$((failed + 1))
      fi
      echo ""
    fi
  done

  # Remove repos on disk but not in manifest
  for repo_dir in repos/*/; do
    [ -d "$repo_dir" ] || continue
    repo_name=$(basename "$repo_dir")
    found=false
    for name in "${registered[@]}"; do
      [ "$name" = "$repo_name" ] && found=true && break
    done
    if [ "$found" = false ]; then
      msg_warning "Removing '$repo_name' (not in repos.yml)..."
      rm -rf "repos/$repo_name"
      # Clean up config and services.yml entries
      config_dir="$DCM_CONFIG_DIR/$repo_name"
      [ -d "$config_dir" ] && rm -rf "$config_dir"
      if [ -f "$DCM_SERVICES_FILE" ]; then
        while IFS= read -r line; do
          if [[ "$line" =~ repos/$repo_name/services/([^/]+)/compose\.yml ]]; then
            service="${BASH_REMATCH[1]}"
            caddy_remove_service "$repo_name/$service"
            service_config_disable "$repo_name/$service"
            any_disabled=$((any_disabled + 1))
          fi
        done < "$DCM_SERVICES_FILE"
        grep -v "repos/$repo_name/services/" "$DCM_SERVICES_FILE" > "${DCM_SERVICES_FILE}.tmp"
        mv "${DCM_SERVICES_FILE}.tmp" "$DCM_SERVICES_FILE"
      fi
      echo ""
    fi
  done

  # Pull repos present in both
  for name in "${registered[@]}"; do
    [ -d "repos/$name" ] || continue
    echo ""
    _pull_repo "$name"
  done
fi

[ "$any_disabled" -gt 0 ] && regenerate_config_env

echo ""
msg_success "Update complete: $updated updated/cloned, $failed failed"
