# Ensure repos directory exists
if [ ! -d "repos" ]; then
  echo "Error: repos directory not found. Please run 'dcm init' first."
  exit 1
fi

# List repositories
echo "Repositories in repos/:"
echo ""

# Check if repos directory is empty
if [ -z "$(ls -A repos)" ]; then
  echo "  (no repositories found)"
else
  # List all directories in repos/
  for repo in repos/*/; do
    if [ -d "$repo" ]; then
      repo_name=$(basename "$repo")
      echo "  - $repo_name"
    fi
  done
fi
