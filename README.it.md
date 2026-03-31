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

# 2. Inizializza il progetto (crea le directory, .env e scarica i servizi built-in)
./dcm init

# 3. Aggiungi un repository contenente servizi
./dcm repo add git@github.com:miaorg/miei-servizi.git

# 4. Abilita i servizi
./dcm service enable MioRepo/Postgres MioRepo/Redis

# 5. Configura e avvia
./dcm service config
./dcm service up
```

---

## Comandi

### `dcm init`

Inizializza la struttura del progetto nella directory corrente:
- Crea `state/` con le directory di configurazione, volumi e compose
- Scrive `.env` con i percorsi assoluti e l'UID/GID corrente
- Scarica i servizi built-in `services/` da GitHub se non presenti
- Abilita automaticamente i servizi built-in (es. reverse proxy Caddy)

```bash
dcm init
```

---

### `dcm repo`

Gestisce i repository Git che contengono servizi.

```bash
dcm repo add <url> [--branch <branch>]   # Clona un repository in repos/
dcm repo rm <nome>                        # Rimuove un repository
dcm repo list                             # Elenca i repository clonati
dcm repo update [repo...]                 # Aggiorna (tutti o specifici)
```

Esempi:
```bash
dcm repo add git@github.com:miaorg/infra.git
dcm repo add git@github.com:miaorg/app.git --branch staging
dcm repo update
dcm repo update MiaInfra MioApp
```

---

### `dcm service`

Gestisce i servizi Docker scoperti in `repos/*/services/*/compose.yml`.

```bash
dcm service enable [servizi...]     # Abilita servizi (tutti se nessuno specificato)
dcm service enable -i               # Interattivo: chiede conferma per ogni servizio
dcm service disable <servizi...>    # Disabilita servizi specifici
dcm service disable --all           # Disabilita tutti i servizi
dcm service config [servizi...]     # Esegue config.sh e ricostruisce config.env
dcm service status                  # Mostra stato dei servizi abilitati
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

### `dcm self-update`

Aggiorna l'eseguibile `dcm` all'ultima versione rilasciata.

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
    └── services/
        ├── compose/
        │   └── services.yml     # include dei servizi attivi
        ├── config/              # configurazione generata per servizio
        └── volumes/             # volumi Docker persistenti
```

---

## Convenzioni per i repository di servizi

Un repository compatibile espone i servizi sotto `services/NomeServizio/`:

```
mio-repo-servizi/
└── services/
    └── Postgres/
        ├── compose.yml          # definizione Docker Compose
        └── setup/
            ├── config.sh        # genera config.partial (variabili d'ambiente)
            └── Caddyfile        # opzionale: snippet di route Caddy
```

---

## Requisiti

- Bash 4.2+
- Docker con Compose v2
- `curl` e `tar`
- Git
