# Network configuration
DEFAULT_CADDY_MAIN_DOMAIN=apug.it
printf '%b\n' "--- Network Configuration ---"
read -p "CADDY_MAIN_DOMAIN [$DEFAULT_CADDY_MAIN_DOMAIN]: " caddy_domain
caddy_domain=${caddy_domain:-$DEFAULT_CADDY_MAIN_DOMAIN}
printf '%b\n' "" >&2

if [ ! -f "$SERVICE_CONFIG_DIR/volumes.yml" ]; then
  cat > "$SERVICE_CONFIG_DIR/volumes.yml" <<'EOF'
# Caddy User-defined Volumes
#
# Aggiungi qui i volumi da montare nel container caddy.
# Utile per servire file statici (CSS, JS, immagini) delle tue applicazioni.
#
# Il path host deve corrispondere a quello montato nei container PHP
# in modo che Caddy e PHP vedano gli stessi file.
#
# Esempio (DcmPhp apps):
#
# services:
#   caddy:
#     volumes:
#       - ${DCM_VOLUMES_DIR}/DcmPhp/apps:/var/www/html:z
#
# Dopo ogni modifica: docker compose up -d --force-recreate caddy

services:
  caddy:
    volumes: []
EOF
  printf '%b\n' "✓ volumes.yml creato in $SERVICE_CONFIG_DIR" >&2
fi

# Write partial config file directly to the service config directory
# REPO_NAME, SERVICE_NAME, and SERVICE_CONFIG_DIR are provided by dcm service config
cat >"$SERVICE_CONFIG_DIR/config.partial" <<EOF

# Network Configuration
CADDY_MAIN_DOMAIN=$caddy_domain
EOF
