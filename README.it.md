# DCM — Docker Collection Manager

Uno strumento CLI per gestire servizi Docker organizzati in più repository Git.
I servizi vengono scoperti, abilitati, configurati e orchestrati con un unico comando.

---

## Installazione

```bash
curl -fsSL https://raw.githubusercontent.com/apug/DCM/main/install.sh | bash
```

Scarica l'eseguibile `dcm` nella directory corrente.

---

## Avvio rapido

```bash
# 1. Scarica dcm
curl -fsSL https://raw.githubusercontent.com/apug/DCM/main/install.sh | bash

# 2. Inizializza il progetto
./dcm init

# 3. Aggiorna il catalogo dei repository disponibili
./dcm repo update

# 4. Sfoglia il catalogo e installa un repo
./dcm repo list --all
./dcm repo install MioRepo

# 5. Abilita i servizi, configura e avvia
./dcm service enable
./dcm service config
./dcm service up
```

---

## Comandi

### `dcm init`

Inizializza la struttura del progetto nella directory corrente:
- Crea `state/` con le directory di configurazione, volumi, compose e sources
- Scrive `.env` con i percorsi assoluti e l'UID/GID corrente
- Scarica i servizi built-in `services/` da GitHub se non presenti
- Abilita automaticamente i servizi built-in (es. reverse proxy Caddy)
- Crea `state/sources/sources.official` con il catalogo ufficiale incluso in DCM

```bash
dcm init
```

---

### `dcm repo`

Gestisce i repository e il catalogo delle sorgenti.

#### Catalogo in stile apt

DCM gestisce file source che elencano i repository disponibili. `repo update` scarica
il manifest `dcm.yml` da ogni repo elencato e lo salva nella cache locale.

```bash
dcm repo update                        # Scarica i manifest da tutte le sorgenti → cache
dcm repo list                          # Elenca i repository installati
dcm repo list --all                    # Elenca tutti i repo disponibili (installati + catalogo)
dcm repo install <nome>                # Installa un repo dal catalogo
dcm repo install <sorgente>/<nome>     # Installa con namespace esplicito (in caso di conflitti)
dcm repo register <url> [--branch]     # Aggiunge un repo a sources.local e lo installa
dcm repo add-source <url>              # Aggiunge un file source esterno in sources.d/
dcm repo pull [repos...]               # git pull sui repo installati (tutti o specifici)
dcm repo rm <nome>                     # Rimuove un repository installato
```

#### File source

| File | Descrizione |
|---|---|
| `state/sources/sources.official` | Repo ufficiali inclusi in DCM (aggiornati da `self-update`) |
| `state/sources/sources.local` | Repo personali aggiunti con `repo register` |
| `state/sources/sources.d/*.yml` | File source di terze parti aggiunti con `repo add-source` |

#### Esempi

```bash
# Installa dal catalogo ufficiale
dcm repo update
dcm repo list --all
dcm repo install DCMBase

# Aggiungi un repo privato (non in nessun catalogo)
dcm repo register git@github.com:miaorg/miei-servizi.git
dcm repo register git@github.com:miaorg/miei-servizi.git --branch staging

# Aggiungi un catalogo di terze parti
dcm repo add-source https://example.com/my-sources.yml
dcm repo update   # aggiorna l'indice dopo aver aggiunto sorgenti

# Mantieni aggiornati i repo installati
dcm repo pull
dcm repo pull MioRepo AltroRepo
```

#### Gestione conflitti di nome

Se lo stesso nome appare in più sorgenti, `repo install <nome>` fallisce
e chiede di usare il namespace esplicito:

```
Error: 'DCMBase' found in multiple sources: official, mycorp
Use: dcm repo install official/DCMBase
  or dcm repo install mycorp/DCMBase
```

---

### `dcm service`

Gestisce i servizi Docker scoperti in `repos/*/services/*/compose.yml`.

```bash
dcm service enable [servizi...]     # Abilita servizi (interattivo o per nome)
dcm service enable --all            # Chiede conferma per tutti i servizi
dcm service enable --yes            # Non interattivo: abilita tutti i servizi disabilitati
dcm service disable [servizi...]    # Disabilita servizi specifici
dcm service disable --all           # Disabilita tutti i servizi
dcm service config [servizi...]     # Esegue config.sh e ricostruisce config.env
dcm service status                  # Mostra lo stato dei servizi abilitati
dcm service status --all            # Mostra tutti i servizi inclusi i disabilitati
dcm service up [servizi...]         # Avvia i servizi
dcm service down [servizi...]       # Ferma i servizi
dcm service restart [servizi...]    # Riavvia i servizi
dcm service logs <servizi...>       # Segue i log dei servizi
dcm service shell <container>       # Apre una shell bash nel container
```

I nomi dei servizi usano il formato `NomeRepo/NomeServizio`:
```bash
dcm service enable MiaInfra/Postgres MiaInfra/Redis
dcm service disable MiaInfra/Redis
dcm service logs Postgres
```

---

### `dcm caddy`

Gestisce la configurazione del reverse proxy Caddy. Caddy è un servizio built-in.

```bash
# Aggiunge una route reverse proxy (default: Caddyfile.After)
dcm caddy reverse-proxy <dominio> <target>
dcm caddy rp <dominio> <target>                     # alias
dcm caddy rp <dominio> <target> --target before     # scrive in Caddyfile.Before

# Aggiunge uno snippet personalizzato in Caddyfile.Before o Caddyfile.After
dcm caddy add <nome> --target <before|after>
dcm caddy add <nome> --target before --file snippet.caddy

# Aggiunge una route personalizzata in Caddyfile.Services
dcm caddy service-add <nome>
dcm caddy service-add <nome> --file route.caddy
```

Esempi:
```bash
dcm caddy rp app.example.com localhost:8080
dcm caddy rp api.example.com miocontainer:3000
dcm caddy add global-tls --target before --file tls-policy.caddy
```

Tutti gli snippet usano marcatori `# BEGIN` / `# END` e sono idempotenti: eseguire lo stesso comando aggiorna lo snippet esistente senza duplicarlo.

---

### `dcm completion`

Stampa lo script di completamento per bash o zsh. La shell viene rilevata automaticamente da `$SHELL` se non specificata.

```bash
# Stampa lo script di completamento
dcm completion bash
dcm completion zsh

# Installa automaticamente nella directory appropriata
dcm completion --install
dcm completion bash --install
dcm completion zsh --install
```

Il completamento viene installato automaticamente anche da `dcm init`.

**Bash** — aggiungere a `~/.bashrc`:
```bash
source ~/.bash_completion.d/dcm
```

**Zsh** — aggiungere a `~/.zshrc`:
```zsh
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

Supporta il tab completion per:
- Comandi, sottocomandi e flag (statico)
- Nomi repo per `repo info`, `repo rm`, `repo pull`, `run` (dinamico)
- Nomi servizi (`RepoName/ServiceName`) per `service enable` (dinamico)
- Nomi servizi abilitati per `service disable`, `up`, `down`, `restart`, `logs`, `shell`, `config` (dinamico)

Il flag `--dir`/`-d` viene rispettato nella risoluzione dinamica dei completamenti.

---

### `dcm self-update`

Aggiorna l'eseguibile `dcm` all'ultima versione rilasciata e sovrascrive `sources.official`.

```bash
dcm self-update
```

---

## Struttura del progetto

Dopo `dcm init`, la directory avrà questa struttura:

```
mio-progetto/
├── dcm                          # l'eseguibile CLI
├── .env                         # DCM_ROOT, DCM_CONFIG_DIR, DCM_VOLUMES_DIR, DCM_UID, DCM_GID
├── services/                    # servizi built-in (es. Caddy)
├── repos/                       # repository Git clonati
│   └── MioRepo/
│       └── services/
│           └── MioServizio/
│               ├── compose.yml
│               └── setup/
│                   ├── config.sh
│                   └── Caddyfile
└── state/
    ├── repos.yml                # manifest dei repository installati
    ├── sources/
    │   ├── sources.official     # catalogo ufficiale (gestito da DCM)
    │   ├── sources.local        # repo personali registrati
    │   ├── sources.d/           # file source di terze parti
    │   └── cache/               # manifest scaricati (dcm.yml)
    └── services/
        ├── compose/
        │   └── services.yml     # include dei servizi attivi
        ├── config/              # configurazione generata per servizio
        └── volumes/             # volumi Docker persistenti
```

---

## Convenzioni per i repository di servizi

Un repository compatibile espone i servizi sotto `services/NomeServizio/` e
include un manifest `dcm.yml` nella root:

```
mio-repo-servizi/
├── dcm.yml                      # manifest del repository (nome, summary, servizi)
└── services/
    └── Postgres/
        ├── compose.yml          # definizione Docker Compose
        └── setup/
            ├── config.sh        # genera config.partial (variabili d'ambiente)
            └── Caddyfile        # opzionale: snippet di route Caddy
```

#### Formato `dcm.yml`

```yaml
name: MioRepo
summary: Descrizione breve (mostrata in repo list)
description: |
  Descrizione lunga opzionale.
services:
  - name: Postgres
    summary: Database PostgreSQL
  - name: Redis
    summary: Cache e message broker
```

---

## Requisiti

- Bash 4.2+
- Docker con Compose v2
- `curl` e `tar`
- Git
