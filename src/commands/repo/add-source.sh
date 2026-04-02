require_init --env

url="${args[url]}"

mkdir -p "$DCM_SOURCES_EXTRA_DIR"

# Derive filename from URL
filename=$(basename "$url")
[[ "$filename" == *.yml ]] || filename="${filename}.yml"
dest="$DCM_SOURCES_EXTRA_DIR/$filename"

msg_info "Fetching source file from $url..."

if ! curl -fsSL "$url" -o "$dest"; then
  msg_error "Failed to download source file from $url"
  exit 1
fi

source_name="${filename%.yml}"
msg_success "Source '$source_name' added: $dest"
msg_info "Run 'dcm repo update' to fetch the package index."
