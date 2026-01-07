## Conflict detection helpers
## Detects Docker service name conflicts across repos

# Extract Docker service names from a compose.yml file
_get_docker_services_from_compose() {
  local compose_file="$1"
  grep -A 1000 "^services:" "$compose_file" \
    | grep "^  [a-zA-Z0-9_-]\+:" \
    | awk '{print $1}' | sed 's/:$//'
}

# Build a map of docker_service_name -> RepoName/ServiceDir for all repos except exclude_repo
# Prints lines: "docker_name RepoName/ServiceDir"
_conflicts_build_other_repos_map() {
  local exclude_repo="$1"

  for compose_file in repos/*/services/*/compose.yml; do
    [ -f "$compose_file" ] || continue

    # Extract RepoName and ServiceDir from path
    local repo_name service_dir
    repo_name=$(echo "$compose_file" | awk -F'/' '{print $2}')
    service_dir=$(echo "$compose_file" | awk -F'/' '{print $4}')

    [ "$repo_name" = "$exclude_repo" ] && continue

    local docker_svc
    while IFS= read -r docker_svc; do
      [ -n "$docker_svc" ] && echo "$docker_svc $repo_name/$service_dir"
    done < <(_get_docker_services_from_compose "$compose_file")
  done
}

# Disable a single DCM service (format: RepoName/ServiceDir)
_conflicts_disable_service() {
  local dcm_service_name="$1"
  local repo service include_path temp_file

  repo=$(echo "$dcm_service_name" | cut -d'/' -f1)
  service=$(echo "$dcm_service_name" | cut -d'/' -f2)
  include_path="${DCM_INCLUDE_PREFIX}repos/$repo/services/$service/compose.yml"

  # Remove from services.yml
  if [ -f "$DCM_SERVICES_FILE" ]; then
    temp_file="${DCM_SERVICES_FILE}.tmp"
    grep -vF "  - $include_path" "$DCM_SERVICES_FILE" > "$temp_file"
    mv "$temp_file" "$DCM_SERVICES_FILE"
  fi

  # Remove partial config directory
  local partial_dir="$DCM_CONFIG_DIR/$repo/$service"
  if [ -d "$partial_dir" ]; then
    rm -rf "$partial_dir"
  fi

  # Remove Caddy snippet and service config entry
  caddy_remove_service "$dcm_service_name"
  service_config_disable "$dcm_service_name"
}

# Check for Docker service name conflicts in repo_name against all other repos.
# mode=warn  : print warnings only
# mode=disable : also disable conflicting services if enabled
# Sets global CONFLICTS_DISABLED_COUNT (incremented per disablement).
# Returns 1 if any conflicts found, 0 otherwise.
conflicts_check_repo() {
  local repo_name="$1"
  local mode="$2"
  local found_conflict=0

  # Build map of other repos' docker service names
  local other_map
  other_map=$(_conflicts_build_other_repos_map "$repo_name")

  declare -A already_disabled

  for compose_file in repos/"$repo_name"/services/*/compose.yml; do
    [ -f "$compose_file" ] || continue

    local service_dir
    service_dir=$(echo "$compose_file" | awk -F'/' '{print $4}')
    local dcm_service="$repo_name/$service_dir"

    local docker_svc
    while IFS= read -r docker_svc; do
      [ -n "$docker_svc" ] || continue

      # Check if this docker service name exists in other repos
      local conflict_owner
      conflict_owner=$(echo "$other_map" | awk -v name="$docker_svc" '$1 == name {print $2; exit}')

      if [ -n "$conflict_owner" ]; then
        found_conflict=1
        msg_warning "Docker service '$docker_svc' in '$dcm_service' conflicts with '$conflict_owner'"

        if [ "$mode" = "disable" ]; then
          if [ -z "${already_disabled[$dcm_service]+x}" ] && service_config_is_enabled "$dcm_service"; then
            msg_warning "Disabling conflicting service: $dcm_service"
            _conflicts_disable_service "$dcm_service"
            already_disabled[$dcm_service]=1
            CONFLICTS_DISABLED_COUNT=$((CONFLICTS_DISABLED_COUNT + 1))
          fi
        fi
      fi
    done < <(_get_docker_services_from_compose "$compose_file")
  done

  return $found_conflict
}
