require_init
load_env

# Initialize services.yml if it doesn't exist
if [ ! -f "$DCM_SERVICES_FILE" ]; then
  echo "include:" > "$DCM_SERVICES_FILE"
  msg_success "Created $DCM_SERVICES_FILE"
fi

# Function to get all available services
get_all_services() {
  local services=()
  for compose_file in repos/*/services/*/compose.yml; do
    if [ -f "$compose_file" ]; then
      local repo=$(echo "$compose_file" | cut -d'/' -f2)
      local service=$(echo "$compose_file" | cut -d'/' -f4)
      services+=("$repo/$service")
    fi
  done
  for compose_file in $DCM_BUILTIN_SERVICES/*/compose.yml; do
    if [ -f "$compose_file" ]; then
      local service=$(echo "$compose_file" | cut -d'/' -f2)
      services+=("_dcm/$service")
    fi
  done
  echo "${services[@]}"
}

# Function to enable a service
enable_service() {
  local service_name="$1"
  local repo=$(echo "$service_name" | cut -d'/' -f1)
  local service=$(echo "$service_name" | cut -d'/' -f2)

  local compose_path
  if [ "$repo" = "_dcm" ]; then
    compose_path="$DCM_BUILTIN_SERVICES/$service/compose.yml"
  else
    compose_path="repos/$repo/services/$service/compose.yml"
  fi

  # Check if service exists
  if [ ! -f "$compose_path" ]; then
    msg_error "Service '$service_name' not found (expected at $compose_path)"
    return 1
  fi

  # Build include path (relative to .dcm/services/compose/ directory)
  local include_path="${DCM_INCLUDE_PREFIX}$compose_path"

  # Check if already enabled
  if grep -qF "  - $include_path" "$DCM_SERVICES_FILE"; then
    msg_warning "Service '$service_name' is already enabled"
    return 0
  fi

  # Add include to services.yml
  echo "  - $include_path" >> "$DCM_SERVICES_FILE"

  # Extract containers from compose.yml and save to config
  local containers=()
  while IFS= read -r container; do
    if [ -n "$container" ]; then
      containers+=("$container")
    fi
  done < <(grep -A 100 "^services:" "$compose_path" | grep "^  [a-zA-Z0-9_-]\+:" | awk '{print $1}' | sed 's/:$//')

  # Save to configuration
  service_config_enable "$service_name" "${containers[@]}"

  # Add Caddy snippet if the service has a Caddyfile
  caddy_add_service "$service_name"

  # Run service configuration
  configure_service "$service_name"

  msg_success "Enabled service: $service_name"
  return 0
}

# Function to disable a service
disable_service() {
  local service_name="$1"
  local repo=$(echo "$service_name" | cut -d'/' -f1)
  local service=$(echo "$service_name" | cut -d'/' -f2)

  local compose_path="repos/$repo/services/$service/compose.yml"
  local include_path="${DCM_INCLUDE_PREFIX}$compose_path"

  # Remove the include line from services.yml
  local temp_file="${DCM_SERVICES_FILE}.tmp"
  grep -vF "  - $include_path" "$DCM_SERVICES_FILE" > "$temp_file"
  mv "$temp_file" "$DCM_SERVICES_FILE"

  # Remove the partial config directory for this service
  local partial_dir="$DCM_CONFIG_DIR/$repo/$service"
  if [ -d "$partial_dir" ]; then
    rm -rf "$partial_dir"
  fi

  service_config_disable "$service_name"
  msg_success "Disabled service: $service_name"
}

# Get services to enable
if [ -n "${args[--interactive]}" ]; then
  # Interactive mode: prompt for each service, showing current state
  all_services=($(get_all_services))

  if [ ${#all_services[@]} -eq 0 ]; then
    echo "No services found in repos/*/services/"
    exit 0
  fi

  enabled_count=0
  disabled_count=0

  for service_name in "${all_services[@]}"; do
    local_repo=$(echo "$service_name" | cut -d'/' -f1)
    local_svc=$(echo "$service_name" | cut -d'/' -f2)

    # Skip built-in services — they are always enabled automatically
    if [ "$local_repo" = "_dcm" ]; then
      continue
    fi

    if [ "$local_repo" = "_dcm" ]; then
      local_compose_path="$DCM_BUILTIN_SERVICES/$local_svc/compose.yml"
    else
      local_compose_path="repos/$local_repo/services/$local_svc/compose.yml"
    fi
    local_include_path="${DCM_INCLUDE_PREFIX}$local_compose_path"
    currently_enabled=false
    if grep -qF "  - $local_include_path" "$DCM_SERVICES_FILE"; then
      currently_enabled=true
    fi

    if [ "$currently_enabled" = true ]; then
      read -p "Enable service '$service_name'? [Y/n]: " response
      response=${response:-Y}
    else
      read -p "Enable service '$service_name'? [y/N]: " response
      response=${response:-N}
    fi

    if [[ "$response" =~ ^[Yy]$ ]]; then
      if [ "$currently_enabled" = false ]; then
        if enable_service "$service_name"; then
          enabled_count=$((enabled_count + 1))
        fi
      fi
    else
      if [ "$currently_enabled" = true ]; then
        disable_service "$service_name"
        disabled_count=$((disabled_count + 1))
      fi
    fi
    echo ""
  done

  regenerate_config_env
  msg_success "Summary: $enabled_count enabled, $disabled_count disabled"
elif [ -n "${args[services]}" ]; then
  # Enable specific services
  eval "services_to_enable=(${args[services]})"

  enabled_count=0
  failed_count=0

  for service_name in "${services_to_enable[@]}"; do
    if enable_service "$service_name"; then
      enabled_count=$((enabled_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
  done

  echo ""
  regenerate_config_env
  msg_success "Summary: $enabled_count enabled, $failed_count failed"
else
  # No services and no --interactive: enable all available services
  all_services=($(get_all_services))

  if [ ${#all_services[@]} -eq 0 ]; then
    echo "No services found in repos/*/services/"
    exit 0
  fi

  enabled_count=0
  failed_count=0

  for service_name in "${all_services[@]}"; do
    if enable_service "$service_name"; then
      enabled_count=$((enabled_count + 1))
    else
      failed_count=$((failed_count + 1))
    fi
  done

  echo ""
  regenerate_config_env
  msg_success "Summary: $enabled_count enabled, $failed_count failed"
fi
