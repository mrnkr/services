# services

Docker Compose services run on this host, each managed as systemd unit via `gen-compose-service.sh`.

## Layout

```
services/
├── gen-compose-service.sh   # generates systemd unit for a compose dir
├── .gitignore               # ignores .env files, generated *.service, data dirs
└── <service>/
    ├── docker-compose.yml
    └── .env                 # not committed
```

## Services

### immich

Self-hosted photo/video backup (https://immich.app), reachable over Tailscale.

Containers:
- `tailscale` — Tailscale sidecar, exposes port `2283`, all other containers share its network via `network_mode: service:tailscale`
- `immich-server` — main app server
- `immich-machine-learning` — ML features (face/object recognition, CLIP search)
- `redis` — cache/queue
- `database` — Postgres w/ pgvector, stores app data

Required `.env` vars (`immich/.env`, gitignored):

| Var | Purpose |
|---|---|
| `TS_AUTHKEY` | Tailscale auth key for sidecar |
| `IMMICH_VERSION` | image tag, defaults to `release` |
| `UPLOAD_LOCATION` | host path for photo/video storage |
| `EXTERNAL_LIBRARY_LOCATION` | host path mounted read-only for external libraries |
| `DB_DATA_LOCATION` | host path for Postgres data |
| `DB_PASSWORD` / `DB_USERNAME` / `DB_DATABASE_NAME` | Postgres creds |

Setup:

```bash
cd immich
cp .env.example .env   # fill in values above
docker compose up -d
```

App at `http://<tailscale-hostname>:2283`.

### pihole

Network-wide ad blocker + DNS (https://pi-hole.net), reachable over Tailscale.

Containers:
- `tailscale` — Tailscale sidecar, exposes ports `53` (DNS tcp/udp), `80`, `443`; `pihole` shares its network via `network_mode: service:tailscale`
- `pihole` — Pi-hole DNS/web app

Required `.env` vars (`pihole/.env`, gitignored):

| Var | Purpose |
|---|---|
| `TS_AUTHKEY` | Tailscale auth key for sidecar |
| `TZ` | timezone for Pi-hole |
| `WEBSERVER_API_PASSWORD` | web UI password |

Setup:

```bash
cd pihole
cp .env.example .env   # fill in values above
docker compose up -d
```

Web UI at `http://<tailscale-hostname>/admin`.

## Adding a new service

1. `mkdir <name> && cd <name>`
2. Add `docker-compose.yml` + `.env`
3. `docker compose up -d` to verify it runs
4. Generate systemd unit so it survives reboot:

```bash
sudo ../gen-compose-service.sh -d . -u <run-as-user>
sudo systemctl daemon-reload
sudo systemctl enable --now <name>.service
```

`-n <name>` overrides service name (default: dir basename). `-f <file>` overrides compose filename (default: `docker-compose.yml`). Run-as user must be in `docker` group.

Unit does `docker compose up -d` on start, `docker compose down` on stop.
