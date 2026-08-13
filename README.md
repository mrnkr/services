# services

Docker Compose services run on this host, each managed as systemd unit via `svc.sh`.

## Layout

```
services/
├── svc.sh                   # generates systemd unit for a compose dir
├── .gitignore               # ignores .env files, generated *.service, data dirs
└── <service>/
    ├── docker-compose.yml
    └── .env                 # not committed
```

## Services

### immich

Self-hosted photo/video backup (https://immich.app).

Containers:
- `immich-server` — main app server, exposes port `2283`
- `immich-machine-learning` — ML features (face/object recognition, CLIP search)
- `redis` — cache/queue
- `database` — Postgres w/ pgvector, stores app data

Required `.env` vars (`immich/.env`, gitignored):

| Var | Purpose |
|---|---|
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

App at `http://<host>:2283`.

### pihole

Network-wide ad blocker + DNS (https://pi-hole.net).

Containers:
- `pihole` — Pi-hole DNS/web app, exposes ports `53` (DNS tcp/udp), `8082` (web UI), `8083` (web UI https)

Required `.env` vars (`pihole/.env`, gitignored):

| Var | Purpose |
|---|---|
| `TZ` | timezone for Pi-hole |
| `WEBSERVER_API_PASSWORD` | web UI password |

Setup:

```bash
cd pihole
cp .env.example .env   # fill in values above
docker compose up -d
```

Web UI at `http://<host>:8082/admin`.

## Exposing services outside the local network (Tailscale)

Tailscale runs on the host itself, not per-service. Since each service publishes its ports on the host (`0.0.0.0`) for LAN access, they're reachable the same way over the tailnet — no per-service Tailscale config needed.

Setup (once per host):

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Then reach any service at `http://<host-tailscale-ip-or-magicdns-name>:<port>` from any device on the tailnet, same port as on the LAN.

## Adding a new service

1. `mkdir <name> && cd <name>`
2. Add `docker-compose.yml` + `.env`
3. `docker compose up -d` to verify it runs
4. Generate systemd unit so it survives reboot:

```bash
sudo ../svc.sh -d . -u <run-as-user>
sudo systemctl daemon-reload
sudo systemctl enable --now <name>.service
```

`-n <name>` overrides service name (default: dir basename). `-f <file>` overrides compose filename (default: `docker-compose.yml`). Run-as user must be in `docker` group.

Unit does `docker compose up -d` on start, `docker compose down` on stop.
