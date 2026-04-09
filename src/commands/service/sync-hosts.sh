require_init --env --compose --config
load_env

hosts_sync

if [ ${?} -eq 0 ]; then
  msg_success "hosts.yml regenerated: $DCM_HOSTS_FILE"
  msg_info "Run 'dcm service restart --recreate' to apply changes to running containers."
else
  msg_error "Failed to regenerate hosts.yml"
  exit 1
fi
