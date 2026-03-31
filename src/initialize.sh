## Initialize script - runs before command execution
## Sets up global configuration and working directory

# Resolve DCM working directory
# Priority: --dir / -d flag > DCM_CONFIG env var > ~/.local/dcm (default)
_dcm_resolve_workdir() {
  local skip_next=false
  local _arg
  for _arg in "${command_line_args[@]}"; do
    if $skip_next; then
      echo "$_arg"
      return
    fi
    case "$_arg" in
      --dir=*) echo "${_arg#--dir=}"; return ;;
      --dir|-d) skip_next=true ;;
    esac
  done
  echo "${DCM_CONFIG:-${HOME}/.local/share/dcm}"
}

_dcm_workdir="$(_dcm_resolve_workdir)"
unset -f _dcm_resolve_workdir

mkdir -p "$_dcm_workdir"
cd "$_dcm_workdir" || { printf "Error: cannot change to directory '%s'\n" "$_dcm_workdir" >&2; exit 1; }
unset _dcm_workdir

# Set config file path (must be after cd)
declare -g CONFIG_FILE="state/config.ini"

# Create state directory if it doesn't exist
if [ ! -d "state" ]; then
  mkdir -p "state"
fi
