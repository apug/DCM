# Ensure repos directory exists
if [ ! -d "repos" ]; then
  msg_error "repos directory not found. Please run 'dcm init' first."
  exit 1
fi

load_env

# If no repos specified, update all repositories
if [ -z "${args[repos]}" ]; then
  msg_info "Updating all repositories..."
  updated=0
  failed=0
  any_disabled=0

  for repo_dir in repos/*/; do
    if [ -d "$repo_dir" ]; then
      repo_name=$(basename "$repo_dir")
      echo ""
      msg_info "Updating $repo_name..."
      if git -C "$repo_dir" pull; then
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
    fi
  done

  if [ "$any_disabled" -gt 0 ]; then
    regenerate_config_env
  fi

  echo ""
  msg_success "Update complete: $updated updated, $failed failed"
else
  # Update only specified repositories
  updated=0
  failed=0
  any_disabled=0

  # Convert escaped space-separated string to array
  eval "repos_to_update=(${args[repos]})"

  for repo_name in "${repos_to_update[@]}"; do
    if [ ! -d "repos/$repo_name" ]; then
      msg_error "Repository '$repo_name' not found in repos directory."
      failed=$((failed + 1))
      continue
    fi

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
  done

  if [ "$any_disabled" -gt 0 ]; then
    regenerate_config_env
  fi

  echo ""
  msg_success "Update complete: $updated updated, $failed failed"
fi
