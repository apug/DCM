# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DCM (Docker Collection Manager) is a Bash CLI tool built with the **Bashly** framework. It orchestrates multiple Docker Compose services sourced from separate git repositories, managing their lifecycle, configuration, and composition into a unified stack.

## Build Command

```bash
# Regenerate the `dcm` executable from src/
# (use the Docker alias from the global CLAUDE.md — no -it flag)
docker run --rm --user $(id -u):$(id -g) --volume "$PWD:/app:Z" dannyben/bashly generate
```

The compiled output is `./dcm` at the project root. It is git-ignored and must never be committed.

There is no test suite or linter configured.

## Architecture

### Layers

1. **CLI Layer** (`src/bashly.yml` + `src/commands/`) — `bashly.yml` is the single source of truth for all commands, arguments, and flags. Each command maps to a `.sh` file under `src/commands/`.

2. **Library Layer** (`src/lib/`) — Shared functions sourced by all commands:
   - `paths.sh` — Path constants and `require_init()` guard
   - `config.sh` / `ini.sh` — INI read/write for `state/config.ini`
   - `service_config.sh` — Per-service enabled state in `config.ini`
   - `service.sh` — `configure_service()`: runs `setup/config.sh`, collects `config.partial`
   - `helper.sh` — `to_pascal_case()`, `regenerate_config_env()`
   - `caddy.sh` — Caddyfile snippet management
   - `repos.sh` — Helpers for `state/repos.yml`
   - `sources.sh` — Source catalog helpers (apt-style)
   - `hosts.sh` — `hosts.yml` generation (`extra_hosts` for containers)
   - `conflicts.sh` — Port/service conflict detection
   - `compose_template.sh` — `compose.yml` generation

3. **Repository Layer** (`repos/`) — Git-cloned service bundles. Layout: `repos/<RepoName>/services/<ServiceName>/compose.yml` plus optional `setup/`, `before_start/`, `post_start/` lifecycle dirs.

4. **Runtime State** (`state/`, git-ignored) — Generated at runtime:
   - `config.ini` — Enabled state per service
   - `repos.yml` — Manifest of registered repos (name, url, branch)
   - `services/compose/services.yml` — Docker Compose include list
   - `services/compose/hosts.yml` — `extra_hosts` for all containers
   - `services/config/` — Per-service `config.partial` files and merged `config.env`
   - `sources/` — Source catalog files and `dcm.yml` manifest cache

### Working directory resolution

Priority at startup (`src/initialize.sh`):

1. `--dir <path>` / `-d <path>` flag
2. `DCM_CONFIG` env var
3. CWD — if the current directory contains a `.env` with `DCM_ROOT=` (i.e. already initialized)
4. `~/.local/share/dcm` — global default

After resolution, DCM `cd`s into the directory unconditionally; all subsequent paths are relative to it. Uses `command_line_args` (Bashly global) to scan for the flag before `cd`.

### Source catalog (apt-style)

Sources define where repos can be discovered. Three tiers, loaded in order:

| File | Managed by |
|---|---|
| `state/sources/sources.official` | DCM (`init` / `self-update`) — never edit manually |
| `state/sources/sources.local` | `dcm repo register` |
| `state/sources/sources.d/*.yml` | `dcm repo add-source` |

`dcm repo update` performs a sparse `git clone --depth=1 --filter=blob:none` on every listed repo to fetch only its `dcm.yml` manifest, caching it under `state/sources/cache/<source>/`. `dcm repo list --all` reads from the cache.

### Service enable lifecycle

`dcm service enable <Repo/Service>` performs four side effects:

1. Appends an include path to `state/services/compose/services.yml`
2. Writes a `# BEGIN <Repo/Service>` … `# END` block into `Caddyfile.Services` (if `setup/Caddyfile` exists)
3. Sets `service.<Repo/Service>.enabled=true` and records container names in `state/config.ini`
4. Runs `configure_service()` → executes `setup/config.sh` → writes `config.partial` → `regenerate_config_env()` merges all partials into `state/services/config/config.env`

`dcm service disable` reverses all four steps.

### Config script contract (`setup/config.sh`)

DCM injects three env vars when running a service's config script:

| Variable | Value |
|---|---|
| `REPO_NAME` | Repository name (PascalCase) |
| `SERVICE_NAME` | Service name |
| `SERVICE_CONFIG_DIR` | Absolute path to `state/services/config/<Repo>/<Service>/` |

The script must write `$SERVICE_CONFIG_DIR/config.partial` (key=value pairs). All partials are merged into `config.env`.

### Caddyfile structure

Three files under `state/services/config/_dcm/Caddy/`:

| File | Owner | Purpose |
|---|---|---|
| `Caddyfile.Before` | User (manual) | Global options, snippets — loaded before service blocks |
| `Caddyfile.Services` | DCM (auto) | Per-service routes via `# BEGIN`/`# END` markers — do not edit |
| `Caddyfile.After` | User (manual) | Catch-all routes — loaded after service blocks |

User snippets use `# BEGIN user/<name>` … `# END user/<name>` markers and are idempotent.

### Key patterns

- **Service addressing**: `RepoName/ServiceName` (e.g. `DCMBase/Caddy`). Repo names are auto-converted to PascalCase via `to_pascal_case()`.
- **`_dcm` namespace**: built-in services bundled with DCM live under `services/` (not `repos/`). All service functions branch on `repo == "_dcm"` to resolve the correct path.
- **Compose inclusion**: the root `compose.yml` includes `services.yml` and `hosts.yml`; those list individual service compose files via relative paths from `state/services/compose/` using `DCM_INCLUDE_PREFIX` (`../../../`).
- **`require_init()` guard**: called by commands with flags `--env`, `--repos`, `--compose`, `--config`; no flags = checks all three (env, repos, compose).
- **`dcm.yml` manifest**: each compatible repo must have this file at its root (fields: `name`, `summary`, `description`, `services[]`). DCM fetches only this file via sparse clone for the catalog.

### Docker networks

Two bridge networks in the root `compose.yml`: `db` (database tier) and `web` (reverse proxy tier).

### Commands

| Command | Description |
|---|---|
| `dcm init` | Initialize DCM directories and `.env` |
| `dcm repo update` | Fetch `dcm.yml` manifests from all sources into cache |
| `dcm repo list [--all]` | List installed repos; `--all` includes catalog |
| `dcm repo install <name>` | Install a repo from the catalog (alias: `add`) |
| `dcm repo register <url>` | Add to `sources.local` and install |
| `dcm repo add-source <url>` | Add a third-party source file to `sources.d/` |
| `dcm repo pull [names...]` | `git pull` on installed repos |
| `dcm repo info <name>` | Status, URL, branch, services, last commit |
| `dcm repo rm <name>` | Remove a repo and clean up its services |
| `dcm service enable [services...]` | Enable interactively or by name (`--all`, `--yes`) |
| `dcm service disable [services...]` | Disable (`--all`) |
| `dcm service config [services...]` | Run config scripts, rebuild `config.env` |
| `dcm service status [--all]` | Service status table |
| `dcm service up/down/restart` | Start/stop/restart Docker services |
| `dcm service sync-hosts` | Regenerate `hosts.yml` |
| `dcm service logs <services...>` | Follow container logs |
| `dcm service shell <container>` | Open bash in a container |
| `dcm caddy reverse-proxy <domain> <target>` | Add reverse proxy route (alias: `rp`) |
| `dcm caddy add <name>` | Add/update snippet in `Caddyfile.Before` or `.After` |
| `dcm caddy service-add <name>` | Add/update route in `Caddyfile.Services` |
| `dcm caddy list` | List all Caddy sites and snippets |
| `dcm run <repo> <command>` | Run a script from `repos/<repo>/commands/` |
| `dcm self-update` | Update `dcm` binary to the latest GitHub release |
