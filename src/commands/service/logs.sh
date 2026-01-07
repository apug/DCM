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

# Get services to follow
eval "service_names=(${args[services]})"

# Verify all services are enabled and collect their containers
containers_to_follow=()
for service_name in "${service_names[@]}"; do
  service_config_require_enabled "$service_name"

  # Get containers for this service from config
  while IFS= read -r container; do
    if [ -n "$container" ]; then
      containers_to_follow+=("$container")
    fi
  done < <(service_config_get_containers "$service_name")
done

if [ ${#containers_to_follow[@]} -eq 0 ]; then
  msg_error "No containers found for specified services"
  exit 1
fi

msg_info "Following logs for services: ${service_names[@]}"
echo "Press Ctrl+C to stop"
echo ""

# Execute docker compose logs
docker compose logs -f "${containers_to_follow[@]}"
