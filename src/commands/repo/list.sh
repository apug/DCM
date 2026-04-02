require_init --env
load_env

if [ -n "${args[--all]}" ]; then
  # Show all repos from sources + mark installed ones
  entries=$(sources_get_all_entries)

  if [ -z "$entries" ]; then
    msg_warning "No source index found. Run 'dcm repo update' to fetch the catalog."
    exit 0
  fi

  printf "%-3s %-25s %-12s %s\n" "" "NAME" "SOURCE" "SUMMARY"
  printf "%-3s %-25s %-12s %s\n" "---" "-------------------------" "------------" "-------"

  echo "$entries" | while IFS='|' read -r src name url _branch; do
    if sources_is_installed "$name"; then
      status="[*]"
    else
      status="   "
    fi
    summary=$(sources_manifest_get "$src" "$name" "summary")
    [ -z "$summary" ] && summary="(run 'dcm repo update' to fetch info)"
    printf "%-3s %-25s %-12s %s\n" "$status" "$name" "$src" "$summary"
  done

  echo ""
  echo "  [*] = installed"
else
  # Show only installed repos
  if [ ! -d "repos" ] || [ -z "$(ls -A repos 2>/dev/null)" ]; then
    echo "No repositories installed."
    exit 0
  fi

  echo "Installed repositories:"
  echo ""
  for repo_dir in repos/*/; do
    [ -d "$repo_dir" ] || continue
    repo_name=$(basename "$repo_dir")
    source=$(repos_get_source "$repo_name")
    [ -n "$source" ] && echo "  - $repo_name  [$source]" || echo "  - $repo_name"
  done
fi
