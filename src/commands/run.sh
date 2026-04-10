require_init --env --repos
load_env

repo="${args[repo]}"
cmd="${args[command]:-}"
repo_dir="repos/$repo"

# Check repo exists
if [ ! -d "$repo_dir" ]; then
  msg_error "Repository '$repo' not found in repos/. Install it first with: dcm repo add"
  exit 1
fi

commands_dir="$repo_dir/commands"

# --list mode
if [[ -n "${args[--list]}" ]]; then
  if [ ! -d "$commands_dir" ] || [ -z "$(ls "$commands_dir"/*.sh 2>/dev/null)" ]; then
    echo "No commands available for '$repo'."
    exit 0
  fi

  echo "Commands available for '$repo':"
  echo ""
  for script in "$commands_dir"/*.sh; do
    name=$(basename "$script" .sh)
    description=$(grep -m1 '^# DESCRIPTION:' "$script" | sed 's/^# DESCRIPTION: *//')
    if [ -n "$description" ]; then
      printf "  %-20s %s\n" "$name" "$description"
    else
      printf "  %s\n" "$name"
    fi
  done
  exit 0
fi

# Command is required when not listing
if [ -z "$cmd" ]; then
  msg_error "No command specified. Use 'dcm run $repo --list' to see available commands."
  exit 1
fi

script="$commands_dir/$cmd.sh"
if [ ! -f "$script" ]; then
  msg_error "Command '$cmd' not found for repo '$repo' (expected at $script)"
  exit 1
fi

# Parse extra args
eval "cmd_args=(${args[args]:-})"

# Export DCM context for the repo script
export REPO_NAME="$repo"
export DCM_REPOS_DIR="$PWD/repos"
export DCM_BIN="$DCM_SELF"
# Export current workdir so child $DCM_BIN calls use the same project
export DCM_CONFIG="$PWD"

# DCM_CONFIG_DIR, DCM_PROXY_SERVICE, DCM_VOLUMES_DIR, DCM_ROOT
# are already exported by load_env (sourced from .env with set -a)

bash "$script" "${cmd_args[@]}"
