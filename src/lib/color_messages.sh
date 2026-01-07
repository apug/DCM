## Color message helpers
## Helper functions for colored output messages

# Set up color codes (respects NO_COLOR standard)
if [[ -z "${NO_COLOR:-}" ]]; then
  __GREEN='\033[0;32m'
  __YELLOW='\033[0;33m'
  __RED='\033[0;31m'
  __BLUE='\033[0;34m'
  __NC='\033[0m'
else
  __GREEN=''
  __YELLOW=''
  __RED=''
  __BLUE=''
  __NC=''
fi

# Success message (green with checkmark)
msg_success() {
  printf '%b\n' "${__GREEN}✓${__NC} $*"
}

# Error message (red with X)
msg_error() {
  printf '%b\n' "${__RED}✗${__NC} $*" >&2
}

# Warning message (yellow with warning symbol)
msg_warning() {
  printf '%b\n' "${__YELLOW}⚠${__NC}  $*"
}

# Info message (blue with info symbol)
msg_info() {
  printf '%b\n' "${__BLUE}ℹ${__NC}  $*"
}

# Colored text inline (without newline)
color_green() {
  printf '%b' "${__GREEN}$*${__NC}"
}

color_red() {
  printf '%b' "${__RED}$*${__NC}"
}

color_yellow() {
  printf '%b' "${__YELLOW}$*${__NC}"
}

color_blue() {
  printf '%b' "${__BLUE}$*${__NC}"
}
