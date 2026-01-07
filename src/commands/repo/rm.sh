# Ensure repos directory exists
if [ ! -d "repos" ]; then
  msg_error "repos directory not found. Please run 'dcm init' first."
  exit 1
fi

# Get arguments from args array
name="${args[name]}"

# Block removal of core repo
if [ "$name" = "_dcm" ]; then
  msg_error "The core repo '_dcm' cannot be removed. Use 'dcm core update' to manage it."
  exit 1
fi

# Check if repository exists
if [ ! -d "repos/$name" ]; then
  msg_error "Repository '$name' not found in repos directory."
  exit 1
fi

# Remove the repository
msg_warning "Removing repository '$name'..."
rm -rf "repos/$name"

if [ $? -eq 0 ]; then
  msg_success "Repository '$name' removed successfully!"
else
  msg_error "Failed to remove repository."
  exit 1
fi

# Remove generated config files for this repository
config_dir="$DCM_CONFIG_DIR/$name"
if [ -d "$config_dir" ]; then
  rm -rf "$config_dir"
  msg_success "Config directory '$config_dir' removed."
fi

# Remove services.yml entries for this repository
if [ -f "$DCM_SERVICES_FILE" ]; then
  removed=0
  while IFS= read -r line; do
    if [[ "$line" =~ repos/$name/services/([^/]+)/compose\.yml ]]; then
      service="${BASH_REMATCH[1]}"
      caddy_remove_service "$name/$service"
      service_config_disable "$name/$service"
      removed=$((removed + 1))
    fi
  done < "$DCM_SERVICES_FILE"

  if [ $removed -gt 0 ]; then
    grep -v "repos/$name/services/" "$DCM_SERVICES_FILE" > "${DCM_SERVICES_FILE}.tmp"
    mv "${DCM_SERVICES_FILE}.tmp" "$DCM_SERVICES_FILE"
    regenerate_config_env
    msg_success "Removed $removed service(s) from services.yml."
  fi
fi
