# Find and execute config script for a service
configure_service() {
  local service_name="$1"
  local repo=$(echo "$service_name" | cut -d'/' -f1)
  local service=$(echo "$service_name" | cut -d'/' -f2)

  local service_dir
  if [ "$repo" = "_dcm" ]; then
    service_dir="$DCM_BUILTIN_SERVICES/$service"
  else
    service_dir="repos/$repo/services/$service"
  fi

  # Check if service exists
  if [ ! -d "$service_dir" ]; then
    msg_warning "Service '$service_name' not found at $service_dir — skipping (stale entry?)"
    return 0
  fi

  # Look for config.sh in setup/ directory
  local config_script="$service_dir/setup/config.sh"
  if [ ! -f "$config_script" ]; then
    return 0
  fi

  echo "Configuring service: $service_name"
  echo ""

  # Create config directory for this service
  local partial_dir="$DCM_CONFIG_DIR/$repo/$service"
  mkdir -p "$partial_dir"

  # Export REPO_NAME and SERVICE_NAME for the config script to use
  export REPO_NAME="$repo"
  export SERVICE_NAME="$service"
  export SERVICE_CONFIG_DIR="$partial_dir"

  # Execute the config script
  if ! bash "$config_script"; then
    echo "Error: Failed to execute config script for '$service_name'"
    unset REPO_NAME SERVICE_NAME SERVICE_CONFIG_DIR
    return 1
  fi

  unset REPO_NAME SERVICE_NAME SERVICE_CONFIG_DIR

  # Check if partial file was created
  local partial_file="$partial_dir/config.partial"
  if [ ! -f "$partial_file" ]; then
    return 0
  fi

  echo "✓ Configuration for '$service_name' completed"
  echo ""
  return 0
}
