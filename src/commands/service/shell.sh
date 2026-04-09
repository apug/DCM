input="${args[container]}"

# If input looks like RepoName/ServiceName, resolve to first container
if [[ "$input" == */* ]]; then
  require_init
  service_config_require_enabled "$input"
  container_name=$(service_config_get_containers "$input" | head -1)
  if [ -z "$container_name" ]; then
    msg_error "No containers found for service '$input'"
    exit 1
  fi
else
  container_name="$input"
fi

echo "Opening bash shell in container: $container_name"
echo "Type 'exit' to leave the shell"
echo ""

# Try bash first, fall back to sh if bash is not available
if docker compose exec "$container_name" bash 2>/dev/null; then
  exit 0
else
  echo "Bash not available, trying sh..."
  docker compose exec "$container_name" sh
fi
