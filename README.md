# DCM — Docker Collection Manager

A CLI tool for managing Docker services organized across multiple Git repositories.
Services are discovered, enabled, configured, and orchestrated through a single command.

---

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/apug/DCM/main/install.sh | bash
```

This downloads the `dcm` executable into the current directory.

---

## Quick Start

```bash
# 1. Download dcm
curl -fsSL https://raw.githubusercontent.com/apug/DCM/main/install.sh | bash

# 2. Initialize the project (creates directories, .env, and downloads built-in services)
./dcm init

# 3. Add a repository containing services
./dcm repo add git@github.com:myorg/my-services.git

# 4. Enable services
./dcm service enable MyRepo/Postgres MyRepo/Redis

# 5. Configure and start
./dcm service config
./dcm service up
```

---

## Commands

### `dcm init`

Initializes the project structure in the current directory:
- Creates `state/` with config, volumes, and compose directories
- Writes `.env` with absolute paths and current UID/GID
- Downloads built-in `services/` from GitHub if not present
- Auto-enables built-in services (e.g. Caddy reverse proxy)

```bash
dcm init
```

---

### `dcm repo`

Manages Git repositories that contain services.

```bash
dcm repo add <url> [--branch <branch>]   # Clone a repository into repos/
dcm repo rm <name>                        # Remove a repository
dcm repo list                             # List cloned repositories
dcm repo update [repo...]                 # Pull latest changes (all or specific)
```

Examples:
```bash
dcm repo add git@github.com:myorg/infra.git
dcm repo add git@github.com:myorg/apps.git --branch staging
dcm repo update
dcm repo update MyInfra MyApps
```

---

### `dcm service`

Manages Docker services discovered from `repos/*/services/*/compose.yml`.

```bash
dcm service enable [services...]    # Enable services (all if none specified)
dcm service enable -i               # Interactive: prompt for each service
dcm service disable <services...>   # Disable specific services
dcm service disable --all           # Disable all services
dcm service config [services...]    # Run config.sh scripts and rebuild config.env
dcm service status                  # Show enabled services and container state
dcm service status --all            # Show all services including disabled
dcm service up [services...]        # Start services
dcm service down [services...]      # Stop services
dcm service restart [services...]   # Restart services
dcm service logs <services...>      # Follow service logs
dcm service shell <container>       # Open a bash shell in a container
```

Service names use the format `RepoName/ServiceName`:
```bash
dcm service enable MyInfra/Postgres MyInfra/Redis
dcm service disable MyInfra/Redis
dcm service logs Postgres
```

---

### `dcm caddy`

Manages the Caddy reverse proxy configuration. Caddy is a built-in service.

```bash
# Add a reverse proxy route (default: Caddyfile.After)
dcm caddy reverse-proxy <domain> <target>
dcm caddy rp <domain> <target>                    # alias
dcm caddy rp <domain> <target> --target before    # write to Caddyfile.Before

# Add a custom snippet to Caddyfile.Before or Caddyfile.After
dcm caddy add <name> --target <before|after>
dcm caddy add <name> --target before --file snippet.caddy

# Add a custom route to Caddyfile.Services
dcm caddy service-add <name>
dcm caddy service-add <name> --file route.caddy
```

Examples:
```bash
dcm caddy rp app.example.com localhost:8080
dcm caddy rp api.example.com mycontainer:3000
dcm caddy add global-tls --target before --file tls-policy.caddy
```

All snippets use `# BEGIN` / `# END` markers and are idempotent — running the same command again updates the existing snippet.

---

### `dcm self-update`

Updates the `dcm` executable to the latest released version.

```bash
dcm self-update
```

---

## Project Structure

After `dcm init`, the directory looks like:

```
my-project/
├── dcm                          # the CLI executable
├── .env                         # DCM_ROOT, DCM_CONFIG_DIR, DCM_VOLUMES_DIR, DCM_UID, DCM_GID
├── services/                    # built-in services (e.g. Caddy)
├── repos/                       # cloned git repositories
│   └── MyRepo/
│       └── services/
│           └── MyService/
│               ├── compose.yml
│               └── setup/
│                   ├── config.sh
│                   └── Caddyfile
└── state/
    └── services/
        ├── compose/
        │   └── services.yml     # active service includes
        ├── config/              # generated config per service
        └── volumes/             # persistent docker volumes
```

---

## Service Repository Convention

A compatible repository should expose services under `services/ServiceName/`:

```
my-services-repo/
└── services/
    └── Postgres/
        ├── compose.yml          # Docker Compose definition
        └── setup/
            ├── config.sh        # generates config.partial (env vars)
            └── Caddyfile        # optional: Caddy route snippet
```

---

## Requirements

- Bash 4.2+
- Docker with Compose v2
- `curl` and `tar`
- Git
