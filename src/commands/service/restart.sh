# Check if compose.yml exists in root
if [ ! -f "compose.yml" ]; then
  msg_error "compose.yml not found in root directory. Please run 'dcm init' first."
  exit 1
fi

# Load environment variables from .env
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

# Build docker compose command
if [ -n "${args[--recreate]}" ]; then
  compose_cmd="docker compose up -d --force-recreate"
else
  compose_cmd="docker compose restart"
fi

# Add specific services if provided
if [ -n "${args[services]}" ]; then
  eval "service_names=(${args[services]})"

  # Verify all services are enabled and collect their containers
  containers_to_restart=()
  for service_name in "${service_names[@]}"; do
    service_config_require_enabled "$service_name"

    # Get containers for this service from config
    while IFS= read -r container; do
      if [ -n "$container" ]; then
        containers_to_restart+=("$container")
      fi
    done < <(service_config_get_containers "$service_name")
  done

  if [ ${#containers_to_restart[@]} -eq 0 ]; then
    msg_error "No containers found for specified services"
    exit 1
  fi

  compose_cmd="$compose_cmd ${containers_to_restart[@]}"
  msg_info "Restarting services: ${service_names[@]}"
else
  msg_info "Restarting all enabled services..."
fi

# Execute docker compose
eval "$compose_cmd"
exit_code=$?

if [ $exit_code -eq 0 ]; then
  msg_success "Services restarted successfully"
else
  msg_error "Failed to restart services (exit code: $exit_code)"
  exit $exit_code
fi
