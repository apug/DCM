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

# Ensure Caddy config files exist before Docker tries to bind-mount them
caddy_init_files

# Build docker compose command
compose_cmd="docker compose up -d"
if [[ "${args[--build]}" == "1" ]]; then
  compose_cmd="$compose_cmd --build"
fi
if [[ "${args[--remove-orphans]}" == "1" ]]; then
  compose_cmd="$compose_cmd --remove-orphans"
fi

# Add specific services if provided
if [ -n "${args[services]}" ]; then
  eval "service_names=(${args[services]})"

  # Verify all services are enabled and collect their containers
  containers_to_start=()
  for service_name in "${service_names[@]}"; do
    service_config_require_enabled "$service_name"

    # Get containers for this service from config
    while IFS= read -r container; do
      if [ -n "$container" ]; then
        containers_to_start+=("$container")
      fi
    done < <(service_config_get_containers "$service_name")
  done

  if [ ${#containers_to_start[@]} -eq 0 ]; then
    msg_error "No containers found for specified services"
    exit 1
  fi

  compose_cmd="$compose_cmd ${containers_to_start[@]}"
  msg_info "Starting services: ${service_names[@]}"
else
  msg_info "Starting all enabled services..."
fi

# Execute docker compose
eval "$compose_cmd"
exit_code=$?

if [ $exit_code -eq 0 ]; then
  msg_success "Services started successfully"
else
  msg_error "Failed to start services (exit code: $exit_code)"
  exit $exit_code
fi
