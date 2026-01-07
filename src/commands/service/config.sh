require_init --env --repos --compose --config
load_env

# Function to get all enabled services from services.yml
get_enabled_services() {
  local services=()
  local services_file="$DCM_SERVICES_FILE"

  if [ ! -f "$services_file" ]; then
    return
  fi

  # Parse services.yml to extract enabled services
  while IFS= read -r line; do
    if [[ "$line" =~ ../../../repos/([^/]+)/services/([^/]+)/compose.yml ]]; then
      services+=("${BASH_REMATCH[1]}/${BASH_REMATCH[2]}")
    elif [[ "$line" =~ ../../../services/([^/]+)/compose.yml ]]; then
      services+=("_dcm/${BASH_REMATCH[1]}")
    fi
  done < "$services_file"

  echo "${services[@]}"
}

# Get services to configure
services_to_configure=()

if [ -z "${args[services]}" ]; then
  # No services specified, configure all enabled services
  echo "No services specified. Configuring all enabled services..."
  echo ""

  enabled_services=($(get_enabled_services))

  if [ ${#enabled_services[@]} -eq 0 ]; then
    echo "No enabled services found in $DCM_SERVICES_FILE"
    echo "Enable services first using: dcm service enable"
    exit 0
  fi

  services_to_configure=("${enabled_services[@]}")
else
  # Configure specific services
  eval "services_to_configure=(${args[services]})"

  # Verify all specified services are enabled
  for service_name in "${services_to_configure[@]}"; do
    if ! service_config_is_enabled "$service_name"; then
      msg_error "Service '$service_name' is not enabled. Enable it first with: dcm service enable $service_name"
      exit 1
    fi
  done
fi

# Check if config.env exists and ask for confirmation
config_env="$DCM_CONFIG_DIR/config.env"
if [ -f "$config_env" ]; then
  echo "⚠ Warning: $config_env already exists"
  read -p "Do you want to regenerate it? This will overwrite the existing file. [y/N]: " response
  response=${response:-N}

  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Configuration cancelled."
    exit 0
  fi
  echo ""
fi

# Configure each service
configured_count=0
failed_count=0

for service_name in "${services_to_configure[@]}"; do
  if configure_service "$service_name"; then
    configured_count=$((configured_count + 1))
  else
    failed_count=$((failed_count + 1))
  fi
done

echo "---"
echo ""

# Regenerate config.env from all partial files
regenerate_config_env

# Regenerate Caddy snippets for all configured services
for service_name in "${services_to_configure[@]}"; do
  caddy_add_service "$service_name"
done

echo "✓ Partial files saved in $DCM_CONFIG_DIR/<repo>/<service>/config.partial"
echo ""
echo "Summary: $configured_count configured, $failed_count failed"
