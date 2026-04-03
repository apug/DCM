name="${args[name]}"

# Resolve source and URL from repos.yml (installed) or sources catalog
source=""
url=""
branch=""
installed=false

if [ -d "repos/$name" ]; then
  installed=true
  url=$(repos_get_url "$name")
  source=$(repos_get_source "$name")
  branch=$(repos_get_branch "$name")
fi

# Try to find in sources catalog if not installed or missing url
if [ -z "$url" ]; then
  while IFS='|' read -r src n u b; do
    if [ "$n" = "$name" ]; then
      source="$src"
      url="$u"
      branch="$b"
      break
    fi
  done <<< "$(sources_get_all_entries)"
fi

if [ -z "$url" ] && [ "$installed" = false ]; then
  msg_error "Repository '$name' not found (not installed and not in any source)."
  exit 1
fi

# Read manifest fields from cache
summary=$(sources_manifest_get "$source" "$name" "summary" 2>/dev/null || true)
description=$(sources_manifest_get "$source" "$name" "description" 2>/dev/null || true)

# Print header
echo ""
printf "  \033[1m%s\033[0m\n" "$name"
echo ""

# Status
if [ "$installed" = true ]; then
  printf "  %-14s %s\n" "Status:"   "installed"
else
  printf "  %-14s %s\n" "Status:"   "not installed"
fi

[ -n "$source" ]      && printf "  %-14s %s\n" "Source:"      "$source"
[ -n "$url" ]         && printf "  %-14s %s\n" "URL:"         "$url"
[ -n "$branch" ]      && printf "  %-14s %s\n" "Branch:"      "$branch"
[ -n "$summary" ]     && printf "  %-14s %s\n" "Summary:"     "$summary"
[ -n "$description" ] && [ "$description" != "|" ] && printf "  %-14s %s\n" "Description:" "$description"

# Services list from manifest cache
if [ -n "$source" ]; then
  cache_file="$DCM_SOURCES_CACHE_DIR/$source/$name.yml"
  if [ -f "$cache_file" ]; then
    services=$(awk '/^services:/{found=1; next} found && /^  - name:/{print "  " $0} found && /^[^ ]/{found=0}' "$cache_file")
    if [ -n "$services" ]; then
      echo ""
      printf "  %-14s\n" "Services:"
      echo "$services" | while IFS= read -r line; do
        svc_name="${line#*name: }"
        svc_summary=$(awk -v svc="$svc_name" '
          /^  - name: / { found=($0 == "  - name: " svc) }
          found && /^    summary: / { sub(/^    summary: */, ""); print; exit }
        ' "$cache_file")
        if [ -n "$svc_summary" ]; then
          printf "    %-20s %s\n" "$svc_name" "$svc_summary"
        else
          printf "    %s\n" "$svc_name"
        fi
      done
    fi
  fi
fi

# If installed, show git info
if [ "$installed" = true ] && [ -d "repos/$name/.git" ]; then
  echo ""
  git_branch=$(git -C "repos/$name" rev-parse --abbrev-ref HEAD 2>/dev/null)
  git_commit=$(git -C "repos/$name" log --oneline -1 2>/dev/null)
  [ -n "$git_branch" ] && printf "  %-14s %s\n" "Git branch:"  "$git_branch"
  [ -n "$git_commit" ] && printf "  %-14s %s\n" "Last commit:" "$git_commit"
fi

echo ""
