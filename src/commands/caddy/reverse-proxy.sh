require_init --env --config
load_env

[ -n "$DCM_PROXY_SERVICE" ] || { msg_error "DCM_PROXY_SERVICE is not set in .env"; exit 1; }

domain="${args[domain]}"
target="${args[target]}"
file_target="${args[--target]:-after}"

case "$file_target" in
  before) target_file="$DCM_CONFIG_DIR/$DCM_PROXY_SERVICE/Caddyfile.Before" ;;
  after)  target_file="$DCM_CONFIG_DIR/$DCM_PROXY_SERVICE/Caddyfile.After" ;;
  *)      msg_error "Invalid --target '$file_target'. Use 'before' or 'after'."; exit 1 ;;
esac

if [ ! -f "$target_file" ]; then
  display_target="$(echo "${file_target:0:1}" | tr '[:lower:]' '[:upper:]')${file_target:1}"
  msg_error "Caddyfile.$display_target not found: $target_file"
  echo "Run 'dcm service config' to initialize Caddy configuration files."
  exit 1
fi

content="${domain} {
    reverse_proxy ${target} {
        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
}"

caddy_upsert_snippet "$domain" "$content" "$target_file"
display_target="$(echo "${file_target:0:1}" | tr '[:lower:]' '[:upper:]')${file_target:1}"
msg_success "Reverse proxy added to Caddyfile.$display_target: $domain → $target"
