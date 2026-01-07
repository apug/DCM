require_init --env --config
load_env

[ -n "$DCM_PROXY_SERVICE" ] || { msg_error "DCM_PROXY_SERVICE is not set in .env"; exit 1; }

name="${args[name]}"

# Determine target file
target="${args[--target]}"
if [ -z "$target" ]; then
  echo "Where do you want to add the snippet?"
  echo "  1) Caddyfile.Before  (global options, before server block)"
  echo "  2) Caddyfile.After   (after server block)"
  read -p "Choose [1/2]: " choice
  case "$choice" in
    1) target="before" ;;
    2) target="after" ;;
    *) msg_error "Invalid choice. Use 1 or 2."; exit 1 ;;
  esac
fi

case "$target" in
  before) target_file="$DCM_CONFIG_DIR/$DCM_PROXY_SERVICE/Caddyfile.Before" ;;
  after)  target_file="$DCM_CONFIG_DIR/$DCM_PROXY_SERVICE/Caddyfile.After" ;;
  *)      msg_error "Invalid --target '$target'. Use 'before' or 'after'."; exit 1 ;;
esac

if [ ! -f "$target_file" ]; then
  msg_error "Target file not found: $target_file"
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
  echo "# Enter your Caddyfile snippet below. Save and exit to continue." > "$tmp_file"
  ${EDITOR:-nano} "$tmp_file"
  # Strip comment lines added as instructions
  content=$(grep -v '^#' "$tmp_file" | sed '/^[[:space:]]*$/d' | head -c 65536)
  rm -f "$tmp_file"
  if [ -z "$content" ]; then
    msg_error "No content provided. Aborting."
    exit 1
  fi
fi

caddy_upsert_snippet "$name" "$content" "$target_file"

# Capitalize target for display
display_target="$(echo "${target:0:1}" | tr '[:lower:]' '[:upper:]')${target:1}"
msg_success "Snippet '$name' added to Caddyfile.$display_target"
