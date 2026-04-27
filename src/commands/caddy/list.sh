require_init --env --config
load_env

[ -n "$DCM_PROXY_SERVICE" ] || { msg_error "DCM_PROXY_SERVICE is not set in .env"; exit 1; }

caddy_dir="$DCM_CONFIG_DIR/$DCM_PROXY_SERVICE"

if [ ! -d "$caddy_dir" ]; then
  msg_error "Caddy config directory not found: $caddy_dir"
  echo "Run 'dcm service config' to initialize Caddy configuration files."
  exit 1
fi

config_env="$DCM_CONFIG_DIR/config.env"
if [ -f "$config_env" ]; then
  set -a; source "$config_env"; set +a
fi

# Extract https:// URLs from a BEGIN/END block in a Caddyfile.
# Matches non-indented lines like: hostname.domain.com { or hostname.{$VAR} {
extract_hosts_from_block() {
  local file="$1"
  local begin_name="$2"
  local in_block=false

  while IFS= read -r line; do
    if [[ "$line" == "# BEGIN $begin_name" ]]; then
      in_block=true
      continue
    fi
    if [[ "$line" == "# END $begin_name" ]]; then
      break
    fi
    if $in_block && [[ "$line" =~ ^[a-zA-Z0-9*_.-][^[:space:]]*[[:space:]]*[{] ]]; then
      local host
      host=$(awk '{print $1}' <<< "$line")
      host=$(echo "$host" | sed "s/{\\\$CADDY_MAIN_DOMAIN}/${CADDY_MAIN_DOMAIN}/g")
      echo "https://$host"
    fi
  done < "$file"
}

rows=()

collect_from_file() {
  local file="$1"
  local file_label="$2"
  [ -f "$file" ] || return 0

  while IFS= read -r line; do
    [[ "$line" == "# BEGIN "* ]] || continue
    local name="${line#\# BEGIN }"
    local type display_name
    if [[ "$name" == user/* ]]; then
      type="user"
      display_name="${name#user/}"
    else
      type="service"
      display_name="$name"
    fi

    local hosts_str=""
    while IFS= read -r url; do
      if [ -z "$hosts_str" ]; then
        hosts_str="$url"
      else
        hosts_str+=$'\x01'"$url"
      fi
    done < <(extract_hosts_from_block "$file" "$name")

    rows+=("$type|$display_name|$file_label|$hosts_str")
  done < "$file"
}

collect_from_file "$caddy_dir/Caddyfile.Before"   "Before"
collect_from_file "$caddy_dir/Caddyfile.Services" "Services"
collect_from_file "$caddy_dir/Caddyfile.After"    "After"

if [ ${#rows[@]} -eq 0 ]; then
  echo "No Caddy sites configured."
  exit 0
fi

printf "%-10s %-30s %-10s %s\n" "TYPE" "NAME" "FILE" "URL"
printf "%-10s %-30s %-10s %s\n" "----------" "------------------------------" "----------" "---"

for row in "${rows[@]}"; do
  IFS='|' read -r type name file_label hosts_str <<< "$row"

  if [ -z "$hosts_str" ]; then
    printf "%-10s %-30s %-10s\n" "$type" "$name" "$file_label"
    continue
  fi

  first=true
  IFS=$'\x01' read -ra urls <<< "$hosts_str"
  for url in "${urls[@]}"; do
    if $first; then
      printf "%-10s %-30s %-10s %s\n" "$type" "$name" "$file_label" "$url"
      first=false
    else
      printf "%-10s %-30s %-10s %s\n" "" "" "" "$url"
    fi
  done
done
