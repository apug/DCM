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

# Clean up all service entries BEFORE removing the directory
# Scan the repo's services directory to find all services (not just enabled ones)
for compose_file in "repos/$name/services/"*/compose.yml; do
  [ -f "$compose_file" ] || continue
  service=$(basename "$(dirname "$compose_file")")
  caddy_remove_service "$name/$service"
  service_config_disable "$name/$service"
done

# Remove services.yml entries for this repository
if [ -f "$DCM_SERVICES_FILE" ]; then
  if grep -q "repos/$name/services/" "$DCM_SERVICES_FILE"; then
    grep -v "repos/$name/services/" "$DCM_SERVICES_FILE" > "${DCM_SERVICES_FILE}.tmp"
    mv "${DCM_SERVICES_FILE}.tmp" "$DCM_SERVICES_FILE"
    regenerate_config_env
    msg_success "Removed service entries from services.yml."
  fi
fi

# Remove the repository
msg_warning "Removing repository '$name'..."
rm -rf "repos/$name"

if [ $? -eq 0 ]; then
  repos_unregister "$name"
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
