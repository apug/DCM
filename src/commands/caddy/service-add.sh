require_init --env --config
load_env

[ -n "$DCM_PROXY_SERVICE" ] || { msg_error "DCM_PROXY_SERVICE is not set in .env"; exit 1; }

name="${args[name]}"
target_file="$DCM_CONFIG_DIR/$DCM_PROXY_SERVICE/Caddyfile.Services"

if [ ! -f "$target_file" ]; then
  msg_error "Caddyfile.Services not found: $target_file"
  echo "Run 'dcm service config' to initialize Caddy configuration files."
  exit 1
fi

# Read content
if [ -n "${args[--file]}" ]; then
  input_file="${args[--file]}"
  if [ ! -f "$input_file" ]; then
    msg_error "File not found: $input_file"
    exit 1
  fi
  content=$(cat "$input_file")
else
  tmp_file=$(mktemp /tmp/dcm-caddy-snippet-XXXXXX.caddy)
  echo "# Enter your Caddyfile route below. Save and exit to continue." > "$tmp_file"
  ${EDITOR:-nano} "$tmp_file"
  content=$(grep -v '^#' "$tmp_file" | sed '/^[[:space:]]*$/d' | head -c 65536)
  rm -f "$tmp_file"
  if [ -z "$content" ]; then
    msg_error "No content provided. Aborting."
    exit 1
  fi
fi

caddy_upsert_snippet "$name" "$content" "$target_file"
msg_success "Route snippet '$name' added to Caddyfile.Services"
