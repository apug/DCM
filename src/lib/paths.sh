## Path constants and initialization checks for DockManager

DCM_GITHUB_REPO="apug/DCM"
DCM_BUILTIN_SERVICES="services"

DCM_DIR="state"
DCM_SERVICES_DIR="$DCM_DIR/services"
DCM_COMPOSE_DIR="$DCM_SERVICES_DIR/compose"
DCM_CONFIG_DIR="$DCM_SERVICES_DIR/config"
DCM_VOLUMES_DIR="$DCM_SERVICES_DIR/volumes"
DCM_SERVICES_FILE="$DCM_COMPOSE_DIR/services.yml"
DCM_HOSTS_FILE="$DCM_COMPOSE_DIR/hosts.yml"
DCM_REPOS_FILE="$DCM_DIR/repos.yml"
# Relative path from state/services/compose/ back to project root
DCM_INCLUDE_PREFIX="../../../"

# Sources
DCM_SOURCES_DIR="$DCM_DIR/sources"
DCM_SOURCES_OFFICIAL="$DCM_SOURCES_DIR/sources.official"
DCM_SOURCES_LOCAL="$DCM_SOURCES_DIR/sources.local"
DCM_SOURCES_EXTRA_DIR="$DCM_SOURCES_DIR/sources.d"
DCM_SOURCES_CACHE_DIR="$DCM_SOURCES_DIR/cache"

# Verify that dcm has been initialized, exit with error if not.
# Usage: require_init [--env] [--repos] [--compose] [--config]
# With no flags, checks .env, repos/ and state/services/compose/.
require_init() {
  local check_env=false
  local check_repos=false
  local check_compose=false
  local check_config=false
  local has_flags=false

  for arg in "$@"; do
    has_flags=true
    case "$arg" in
      --env)     check_env=true ;;
      --repos)   check_repos=true ;;
      --compose) check_compose=true ;;
      --config)  check_config=true ;;
    esac
  done

  # Default: check env, repos, compose
  if [ "$has_flags" = false ]; then
    check_env=true
    check_repos=true
    check_compose=true
  fi

  if [ "$check_env" = true ] && [ ! -f ".env" ]; then
    msg_error ".env file not found. Please run 'dcm init' first."
    exit 1
  fi

  if [ "$check_repos" = true ] && [ ! -d "repos" ]; then
    msg_error "repos directory not found. Please run 'dcm init' first."
    exit 1
  fi

  if [ "$check_compose" = true ] && [ ! -d "$DCM_COMPOSE_DIR" ]; then
    msg_error "$DCM_COMPOSE_DIR directory not found. Please run 'dcm init' first."
    exit 1
  fi

  if [ "$check_config" = true ] && [ ! -d "$DCM_CONFIG_DIR" ]; then
    msg_error "$DCM_CONFIG_DIR directory not found. Please run 'dcm init' first."
    exit 1
  fi
}

# Source .env file to load DCM_* variables
load_env() {
  if [ -f ".env" ]; then
    set -a
    source .env
    set +a
  fi
}
