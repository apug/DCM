require_init --env --compose --config
load_env

if [ ! -f "$DCM_SERVICES_FILE" ]; then
  msg_error "$DCM_SERVICES_FILE not found. No services are enabled."
  exit 1
fi

# Function to disable a service
disable_service() {
  local service_name="$1"
  local repo=$(echo "$service_name" | cut -d'/' -f1)

  if [ "$repo" = "_dcm" ]; then
    msg_error "Core services cannot be disabled."
    return 1
  fi
  local service=$(echo "$service_name" | cut -d'/' -f2)

  local compose_path="repos/$repo/services/$service/compose.yml"
  local include_path="${DCM_INCLUDE_PREFIX}$compose_path"

  # Check if service is enabled
  if ! grep -qF "  - $include_path" "$DCM_SERVICES_FILE"; then
    echo "Service '$service_name' is not enabled"
    return 1
  fi

  # Remove the include line from services.yml
  # Use a temporary file to ensure atomicity
  local temp_file="${DCM_SERVICES_FILE}.tmp"
  grep -vF "  - $include_path" "$DCM_SERVICES_FILE" > "$temp_file"
  mv "$temp_file" "$DCM_SERVICES_FILE"

  # Remove the partial config directory for this service
  local partial_dir="$DCM_CONFIG_DIR/$repo/$service"
  if [ -d "$partial_dir" ]; then
    rm -rf "$partial_dir"
    echo "Removed configuration for: $service_name"
  fi

  # Remove Caddy snippet if present
  caddy_remove_service "$service_name"

  # Remove from configuration
  service_config_disable "$service_name"

  echo "Disabled service: $service_name"
  return 0
}

# Get services to disable
services_to_disable=()

if [ -n "${args[--all]}" ]; then
  # Parse services.yml to find all enabled services
  while IFS= read -r line; do
    if [[ "$line" =~ ${DCM_INCLUDE_PREFIX}repos/([^/]+)/services/([^/]+)/compose.yml ]]; then
      services_to_disable+=("${BASH_REMATCH[1]}/${BASH_REMATCH[2]}")
    fi
  done < "$DCM_SERVICES_FILE"

  if [ ${#services_to_disable[@]} -eq 0 ]; then
    msg_warning "No enabled services found"
    exit 0
  fi
elif [ -n "${args[services]}" ]; then
  eval "services_to_disable=(${args[services]})"
else
  msg_error "Specify service names or use --all to disable all services"
  exit 1
fi

disabled_count=0
failed_count=0

for service_name in "${services_to_disable[@]}"; do
  if disable_service "$service_name"; then
    disabled_count=$((disabled_count + 1))
  else
    failed_count=$((failed_count + 1))
  fi
done

echo ""

# Regenerate config.env if any service was disabled
if [ $disabled_count -gt 0 ]; then
  echo "Regenerating configuration file..."
  regenerate_config_env
  echo ""
fi

echo "Summary: $disabled_count disabled, $failed_count failed"
