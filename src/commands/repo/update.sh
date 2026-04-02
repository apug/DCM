require_init --env

mkdir -p "$DCM_SOURCES_CACHE_DIR"

source_files=$(sources_list_files)
if [ -z "$source_files" ]; then
  msg_warning "No source files found. Run 'dcm init' to initialize sources."
  exit 0
fi

msg_info "Refreshing package index..."
echo ""

ok=0
fail=0

while IFS= read -r file; do
  src=$(sources_name_from_file "$file")
  msg_info "Reading source: $src"

  while IFS='|' read -r _src name url branch; do
    printf "  %-30s " "$name"
    if sources_fetch_manifest "$src" "$name" "$url" "$branch"; then
      echo "ok"
      ok=$((ok + 1))
    else
      fail=$((fail + 1))
    fi
  done < <(sources_parse_file "$src" "$file")

  echo ""
done <<< "$source_files"

msg_success "Index updated: $ok ok, $fail failed"
