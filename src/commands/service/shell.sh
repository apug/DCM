# Get container name
container_name="${args[container]}"

echo "Opening bash shell in container: $container_name"
echo "Type 'exit' to leave the shell"
echo ""

# Try bash first, fall back to sh if bash is not available
if docker exec -it "$container_name" bash 2>/dev/null; then
  exit 0
else
  echo "Bash not available, trying sh..."
  docker exec -it "$container_name" sh
fi
