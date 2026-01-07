## Service configuration helpers
## Manages enabled services and their containers in config.ini

# Mark a service as enabled
service_config_enable() {
  local service="$1"
  shift
  local containers=("$@")

  # Store enabled status
  config_set "service.$service.enabled" "true"

  # Store containers (comma-separated)
  if [ ${#containers[@]} -gt 0 ]; then
    local containers_str=$(IFS=,; echo "${containers[*]}")
    config_set "service.$service.containers" "$containers_str"
  fi
}

# Mark a service as disabled
service_config_disable() {
  local service="$1"

  config_del "service.$service.enabled"
  config_del "service.$service.containers"
}

# Check if a service is enabled
service_config_is_enabled() {
  local service="$1"
  local enabled=$(config_get "service.$service.enabled")

  [ "$enabled" = "true" ]
}

# Get containers for a service
service_config_get_containers() {
  local service="$1"
  local containers_str=$(config_get "service.$service.containers")

  if [ -n "$containers_str" ]; then
    echo "$containers_str" | tr ',' '\n'
  fi
}

# Get all enabled services
service_config_get_all_enabled() {
  for key in $(config_keys); do
    if [[ "$key" =~ ^service\.(.+)\.enabled$ ]]; then
      local service="${BASH_REMATCH[1]}"
      if service_config_is_enabled "$service"; then
        echo "$service"
      fi
    fi
  done
}

# Verify service is enabled, exit with error if not
service_config_require_enabled() {
  local service="$1"

  if ! service_config_is_enabled "$service"; then
    msg_error "Service '$service' is not enabled. Enable it first with: dcm service enable $service"
    exit 1
  fi
}
