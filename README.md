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

# 2. Initialize the project
./dcm init

# 3. Fetch the catalog of available repositories
./dcm repo update

# 4. Browse available repos and install one
./dcm repo list --all
./dcm repo install MyRepo

# 5. Enable services, configure and start
./dcm service enable
./dcm service config
./dcm service up
```

---

## Commands

### `dcm init`

Initializes the project structure in the current directory:
- Creates `state/` with config, volumes, compose, and sources directories
- Writes `.env` with absolute paths and current UID/GID
- Downloads built-in `services/` from GitHub if not present
- Auto-enables built-in services (e.g. Caddy reverse proxy)
- Creates `state/sources/sources.official` with the bundled official catalog

```bash
dcm init
```

---

### `dcm repo`

Manages repositories and the source catalog.

#### Catalog (apt-style)

DCM manages source files that list available repositories. `repo update` fetches
the `dcm.yml` manifest from each listed repo and caches it locally.

```bash
dcm repo update                        # Fetch manifests from all sources → cache
dcm repo list                          # List installed repositories
dcm repo list --all                    # List all available repos (installed + catalog)
dcm repo install <name>                # Install a repo from the catalog
dcm repo install <source>/<name>       # Install with explicit source (if name conflicts)
dcm repo register <url> [--branch]     # Add a repo to sources.local and install it
dcm repo add-source <url>              # Add an external source file to sources.d/
dcm repo pull [repos...]               # git pull on installed repos (all or specific)
dcm repo info <name>                   # Show details: status, URL, branch, services, last commit
dcm repo rm <name>                     # Remove an installed repository
```

#### Source files

| File | Description |
|---|---|
| `state/sources/sources.official` | Official repos bundled with DCM (updated by `self-update`) |
| `state/sources/sources.local` | Your own repos added via `repo register` |
| `state/sources/sources.d/*.yml` | Third-party source files added via `repo add-source` |

#### Examples

```bash
# Install from the official catalog
dcm repo update
dcm repo list --all
dcm repo install DCMBase

# Add a private repo (not in any catalog)
dcm repo register git@github.com:myorg/my-services.git
dcm repo register git@github.com:myorg/my-services.git --branch staging

# Add a third-party catalog
dcm repo add-source https://example.com/my-sources.yml
dcm repo update   # refresh index after adding sources

# Keep installed repos up to date
dcm repo pull
dcm repo pull MyRepo OtherRepo
```

#### Conflict resolution

If the same repo name appears in multiple sources, `repo install <name>` will fail
and prompt you to use the explicit namespace:

```
Error: 'DCMBase' found in multiple sources: official, mycorp
Use: dcm repo install official/DCMBase
  or dcm repo install mycorp/DCMBase
```

---

### `dcm service`

Manages Docker services discovered from `repos/*/services/*/compose.yml`.

```bash
dcm service enable [services...]                # Enable services interactively or by name
dcm service enable --all                        # Prompt for all services (including enabled ones)
dcm service enable --yes                        # Non-interactive: enable all disabled services
dcm service disable [services...]               # Disable specific services
dcm service disable --all                       # Disable all services
dcm service config [services...]                # Run config.sh scripts and rebuild config.env
dcm service status                              # Show enabled services and container state
dcm service status --all                        # Show all services including disabled
dcm service up [services...]                    # Start services
dcm service up --remove-orphans [services...]   # Start services, removing orphaned containers
dcm service down [services...]                  # Stop services
dcm service restart [services...]               # Restart services
dcm service restart --recreate [services...]    # Restart with --force-recreate
dcm service logs <services...>                  # Follow service logs
dcm service shell <container>                   # Open a bash/sh shell in a container
dcm service shell <RepoName/ServiceName>        # Shell by service name (resolves first container)
dcm service sync-hosts                          # Regenerate hosts.yml with extra_hosts for all containers
```

Service names use the format `RepoName/ServiceName`:
```bash
dcm service enable MyInfra/Postgres MyInfra/Redis
dcm service disable MyInfra/Redis
dcm service logs Postgres
```

---

### `dcm run`

Runs a command provided by an installed repository. Repositories can expose arbitrary scripts under their `commands/` directory, documented with a `# DESCRIPTION:` comment.

```bash
dcm run <repo> <command> [args...]   # Run a repo command
dcm run <repo> --list                # List available commands for a repo
```

Examples:
```bash
dcm run DcmBase --list
dcm run DcmBase db-dump mydb
```

A command script lives at `repos/<repo>/commands/<command>.sh` and receives DCM environment variables (`DCM_CONFIG_DIR`, `DCM_VOLUMES_DIR`, etc.) automatically.

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

### `dcm completion`

Outputs the shell completion script for bash or zsh. The shell is auto-detected from `$SHELL` if not specified.

```bash
# Print the completion script
dcm completion bash
dcm completion zsh

# Install automatically to the appropriate directory
dcm completion --install
dcm completion bash --install
dcm completion zsh --install
```

Completion is also installed automatically by `dcm init`.

**Bash** — add to `~/.bashrc`:
```bash
source ~/.bash_completion.d/dcm
```

**Zsh** — add to `~/.zshrc`:
```zsh
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

Supports tab completion for:
- Commands, subcommands and flags (static)
- Repository names for `repo info`, `repo rm`, `repo pull`, `run` (dynamic)
- Service names (`RepoName/ServiceName`) for `service enable` (dynamic)
- Enabled service names for `service disable`, `up`, `down`, `restart`, `logs`, `shell`, `config` (dynamic)

The `--dir`/`-d` flag is respected when resolving dynamic completions.

---

### `dcm self-update`

Updates the `dcm` executable to the latest released version and refreshes `sources.official`.

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
    ├── repos.yml                # installed repositories manifest
    ├── sources/
    │   ├── sources.official     # official catalog (managed by DCM)
    │   ├── sources.local        # your registered repos
    │   ├── sources.d/           # third-party source files
    │   └── cache/               # downloaded repo manifests (dcm.yml)
    └── services/
        ├── compose/
        │   ├── services.yml     # active service includes
        │   └── hosts.yml        # generated extra_hosts for all containers
        ├── config/              # generated config per service
        └── volumes/             # persistent docker volumes
```

---

## Service Repository Convention

A compatible repository should expose services under `services/ServiceName/` and
include a `dcm.yml` manifest at the root:

```
my-services-repo/
├── dcm.yml                      # repository manifest (name, summary, services)
└── services/
    └── Postgres/
        ├── compose.yml          # Docker Compose definition
        └── setup/
            ├── config.sh        # generates config.partial (env vars)
            └── Caddyfile        # optional: Caddy route snippet
```

#### `dcm.yml` format

```yaml
name: MyRepo
summary: Short description (shown in repo list)
description: |
  Optional longer description.
services:
  - name: Postgres
    summary: PostgreSQL database
  - name: Redis
    summary: Cache and message broker
```

---

## Requirements

- Bash 4.2+
- Docker with Compose v2
- `curl` and `tar`
- Git
