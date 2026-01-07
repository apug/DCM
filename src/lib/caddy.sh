## Caddy configuration helpers
## Manages per-service Caddyfile snippets and user-defined snippets

# Add a service's Caddy snippet to Caddyfile.Services
caddy_add_service() {
  local service_name="$1"  # format: Repo/Service
  local repo=$(echo "$service_name" | cut -d'/' -f1)
  local service=$(echo "$service_name" | cut -d'/' -f2)
  local caddyfile
  if [ "$repo" = "_dcm" ]; then
    caddyfile="$DCM_BUILTIN_SERVICES/$service/setup/Caddyfile"
  else
    caddyfile="repos/$repo/services/$service/setup/Caddyfile"
  fi
  [ -n "$DCM_PROXY_SERVICE" ] || return 0
  local caddyfile_services="$DCM_CONFIG_DIR/$DCM_PROXY_SERVICE/Caddyfile.Services"

  [ -f "$caddyfile" ] || return 0
  grep -qF "# BEGIN $service_name" "$caddyfile_services" 2>/dev/null && return 0

  {
    echo ""
    echo "# BEGIN $service_name"
    cat "$caddyfile"
    echo "# END $service_name"
  } >> "$caddyfile_services"
}

# Add or update a user-defined snippet in a Caddyfile (Before, Services, or After)
caddy_upsert_snippet() {
  local marker="user/$1"   # e.g. "user/my-snippet"
  local content="$2"
  local target_file="$3"   # absolute path

  # Remove existing block if present
  if grep -qF "# BEGIN $marker" "$target_file" 2>/dev/null; then
    sed -i "/^# BEGIN $marker$/,/^# END $marker$/d" "$target_file"
  fi

  {
    echo ""
    echo "# BEGIN $marker"
    printf '%s\n' "$content"
    echo "# END $marker"
  } >> "$target_file"
}

# Remove a service's Caddy snippet from Caddyfile.Services
caddy_remove_service() {
  local service_name="$1"
  [ -n "$DCM_PROXY_SERVICE" ] || return 0
  local caddyfile_services="$DCM_CONFIG_DIR/$DCM_PROXY_SERVICE/Caddyfile.Services"

  [ -f "$caddyfile_services" ] || return 0
  grep -qF "# BEGIN $service_name" "$caddyfile_services" || return 0

  sed -i "/^# BEGIN $service_name$/,/^# END $service_name$/d" "$caddyfile_services"
}
