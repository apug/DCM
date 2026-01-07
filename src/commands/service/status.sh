# Check if compose.yml exists in root
if [ ! -f "compose.yml" ]; then
  echo "Error: compose.yml not found in root directory. Please run 'dcm init' first."
  exit 1
fi

# Load environment variables from .env
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

# Color codes (respects NO_COLOR standard)
if [[ -z "${NO_COLOR:-}" ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  GREEN=''
  YELLOW=''
  RED=''
  BLUE=''
  NC=''
fi

services_file="$DCM_SERVICES_FILE"

# Function to get all available services (RepoName/ServiceName format)
get_all_services() {
  local services=()
  for compose_file in repos/*/services/*/compose.yml; do
    if [ -f "$compose_file" ]; then
      local repo=$(echo "$compose_file" | cut -d'/' -f2)
      local service_folder=$(echo "$compose_file" | cut -d'/' -f4)
      services+=("$repo/$service_folder")
    fi
  done
  for compose_file in services/*/compose.yml; do
    if [ -f "$compose_file" ]; then
      local service_folder=$(echo "$compose_file" | cut -d'/' -f2)
      services+=("_dcm/$service_folder")
    fi
  done
  echo "${services[@]}"
}

# Function to check if a service is enabled
is_service_enabled() {
  local service_name="$1"
  local repo=$(echo "$service_name" | cut -d'/' -f1)
  local service=$(echo "$service_name" | cut -d'/' -f2)

  local compose_path
  if [ "$repo" = "_dcm" ]; then
    compose_path="services/$service/compose.yml"
  else
    compose_path="repos/$repo/services/$service/compose.yml"
  fi
  local include_path="${DCM_INCLUDE_PREFIX}$compose_path"

  if [ ! -f "$services_file" ]; then
    return 1
  fi

  if grep -qF "  - $include_path" "$services_file"; then
    return 0
  else
    return 1
  fi
}

# Function to get all docker service names from compose file
get_docker_service_names() {
  local compose_file="$1"
  # Extract all service names (lines after "services:" that start with exactly 2 spaces and contain ":")
  # This matches the YAML indentation for service definitions
  grep -A 100 "^services:" "$compose_file" | grep "^  [a-zA-Z0-9_-]\+:" | awk '{print $1}' | sed 's/:$//'
}

# Function to get container name for a docker service
get_container_name() {
  local docker_service="$1"
  local container_id=$(docker compose ps -q "$docker_service" 2>/dev/null)
  if [ -n "$container_id" ]; then
    docker inspect -f '{{.Name}}' "$container_id" 2>/dev/null | sed 's|^/||'
  else
    echo "-"
  fi
}

# Function to get service status
get_service_status() {
  local docker_service="$1"
  local status=$(docker compose ps -q "$docker_service" 2>/dev/null | xargs docker inspect -f '{{.State.Status}}' 2>/dev/null || echo "not found")

  if [ "$status" = "running" ]; then
    echo "${GREEN}● Running${NC}"
  elif [ "$status" = "not found" ]; then
    echo "${YELLOW}○ Not started${NC}"
  else
    echo "${RED}● Stopped${NC}"
  fi
}

# Print decorative header
printf '%b\n' "${BLUE}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
printf '%b\n' "${BLUE}║                    DockManager - Services Status                               ║${NC}"
printf '%b\n' "${BLUE}╚════════════════════════════════════════════════════════════════════════════════╝${NC}"
printf '%b\n' ""

# Get all services
all_services=($(get_all_services))

if [ ${#all_services[@]} -eq 0 ]; then
  echo "No services found in repos/*/services/"
  exit 0
fi

# Collect enabled services data (one row per container)
services_column=()
docker_services_column=()
statuses=()
containers=()
running_count=0
total_containers=0

for service_name in "${all_services[@]}"; do
  if is_service_enabled "$service_name"; then
    # Get all docker service names from compose file
    repo=$(echo "$service_name" | cut -d'/' -f1)
    service_folder=$(echo "$service_name" | cut -d'/' -f2)
    if [ "$repo" = "_dcm" ]; then
      compose_file="services/$service_folder/compose.yml"
    else
      compose_file="repos/$repo/services/$service_folder/compose.yml"
    fi

    # Get all docker services defined in this compose file
    docker_services_list=$(get_docker_service_names "$compose_file")

    # For each docker service, create a row
    while IFS= read -r docker_service; do
      if [ -n "$docker_service" ]; then
        services_column+=("$service_name")
        docker_services_column+=("$docker_service")

        # Get status and container name
        status=$(get_service_status "$docker_service")
        container=$(get_container_name "$docker_service")

        statuses+=("$status")
        containers+=("$container")

        # Count running services
        if [[ "$status" == *"Running"* ]]; then
          running_count=$((running_count + 1))
        fi
        total_containers=$((total_containers + 1))
      fi
    done <<< "$docker_services_list"
  fi
done

# Display mode
if [ "${args[--all]}" = "1" ]; then
  echo "=== Enabled Services ==="
  echo ""
fi

# Print table header (only if there are enabled services)
if [ ${#services_column[@]} -gt 0 ]; then
  # Calculate max lengths for columns
  max_service_len=7  # "SERVICE"
  max_docker_len=14  # "DOCKER SERVICE"

  for service in "${services_column[@]}"; do
    if [ ${#service} -gt $max_service_len ]; then
      max_service_len=${#service}
    fi
  done

  for docker_svc in "${docker_services_column[@]}"; do
    if [ ${#docker_svc} -gt $max_docker_len ]; then
      max_docker_len=${#docker_svc}
    fi
  done

  # Print header
  printf '%b' "${BLUE}SERVICE$(printf ' %.0s' $(seq 1 $((max_service_len - 7))))  "
  printf '%b' "DOCKER SERVICE$(printf ' %.0s' $(seq 1 $((max_docker_len - 14))))  "
  printf '%b\n' "STATUS              CONTAINER NAME${NC}"
  printf '%b\n' "$(printf '%.0s-' $(seq 1 100))"

  # Print each row
  for i in "${!services_column[@]}"; do
    printf "%-${max_service_len}s  %-${max_docker_len}s  %b  %-20s\n" \
      "${services_column[$i]}" \
      "${docker_services_column[$i]}" \
      "${statuses[$i]}" \
      "${containers[$i]}"
  done

  printf '\n'
else
  echo "No enabled services found."
  echo ""
fi

# Show disabled services if --all flag is set
if [ "${args[--all]}" = "1" ]; then
  echo "=== Disabled Services ==="
  echo ""

  disabled_services=()
  for service_name in "${all_services[@]}"; do
    if ! is_service_enabled "$service_name"; then
      disabled_services+=("$service_name")
    fi
  done

  if [ ${#disabled_services[@]} -eq 0 ]; then
    echo "No disabled services"
  else
    printf '%b\n' "${BLUE}SERVICE                          STATUS${NC}"
    printf '%b\n' "$(printf '%.0s-' $(seq 1 80))"
    for service in "${disabled_services[@]}"; do
      printf "%-32s %s\n" "$service" "Disabled"
    done
  fi

  printf '\n'
fi

# Print footer with statistics
if [ $total_containers -gt 0 ]; then
  printf '%b\n' "${GREEN}✓${NC} Running: $running_count/$total_containers containers"
  printf '\n'
fi
