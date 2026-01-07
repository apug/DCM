## Initialize script - runs before command execution
## Sets up global configuration

# Set config file path
declare -g CONFIG_FILE=".dcm/config.ini"

# Create .dcm directory if it doesn't exist
if [ ! -d ".dcm" ]; then
  mkdir -p ".dcm"
fi
