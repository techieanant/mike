# Production Deployment

This guide covers deploying Mike to a Linux server (VPS, dedicated, etc.) using Docker Compose and prebuilt images from GitHub Container Registry (GHCR).

## Prerequisites

- A Linux server with Docker Engine and Docker Compose v2 installed
- A domain name pointing to your server (for HTTPS)
- An SMTP provider or transactional email service (required for password-reset emails in production)
- At least one AI provider API key

## Architecture

The production stack uses **GHCR-hosted images** for the Mike frontend and backend:

- `ghcr.io/techieanant/mike-frontend:latest`
- `ghcr.io/techieanant/mike-backend:latest`

Infrastructure services (PostgreSQL, GoTrue, PostgREST, nginx, MinIO) run from upstream public images and are self-hosted alongside the application.

## Step 1 — Clone the repository

The production compose file and config files are in the repository. You do not need to build anything on the server.

```bash
git clone https://github.com/techieanant/mike.git
cd mike
```

## Step 2 — Create the production environment file

```bash
cp .env.prod.example .env.prod
```

Edit `.env.prod` and fill in every value. Key items:

| Variable | What to set |
|----------|-------------|
| `POSTGRES_PASSWORD` | Strong random password (`openssl rand -hex 32`) |
| `JWT_SECRET` | ≥32-character random secret (`openssl rand -base64 40`) |
| `ANON_KEY` | JWT signed with your `JWT_SECRET` (see below) |
| `SERVICE_ROLE_KEY` | JWT signed with your `JWT_SECRET` (see below) |
| `SITE_URL` | Public URL of your Mike instance (e.g. `https://mike.example.com`) |
| `API_EXTERNAL_URL` | Public URL of the API gateway (e.g. `https://api.mike.example.com` or same host on port 8000) |
| `MINIO_ROOT_USER` | Strong username |
| `MINIO_ROOT_PASSWORD` | Strong password |
| `SMTP_*` | SMTP credentials for auth emails |

### Generating JWT keys

```bash
# 1. Generate a secret
openssl rand -base64 40

# 2. Visit https://jwt.io and sign two tokens with HS256:
#
#    ANON_KEY payload:
#    { "role": "anon", "iss": "supabase", "iat": 1641769200, "exp": 1799535600 }
#
#    SERVICE_ROLE_KEY payload:
#    { "role": "service_role", "iss": "supabase", "iat": 1641769200, "exp": 1799535600 }
```

> **Tip:** Update the `exp` field to a date far in the future (Unix timestamp). The example value 1799535600 corresponds to 2027-01-10.

## Step 3 — (Optional) Set up a reverse proxy for HTTPS

It is strongly recommended to place an HTTPS-terminating reverse proxy (Caddy, Nginx, Traefik, etc.) in front of the stack. Configure it to proxy:

| Public path | → | Internal service |
|-------------|---|-----------------|
| `https://mike.example.com` → port 3000 | frontend |
| `https://api.mike.example.com` → port 8000 | API gateway |

A minimal Caddyfile example:

```
mike.example.com {
    reverse_proxy localhost:3000
}

api.mike.example.com {
    reverse_proxy localhost:8000
}
```

## Step 4 — Pull images and start the stack

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod pull
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

On the **first start only**, the database init scripts run automatically:

1. `backend/migrations/000_one_shot_schema.sql` — creates all app tables and RLS policies
2. `db/init/30_permissions.sql` — grants PostgREST role permissions

This takes about 30 seconds. Check progress with:

```bash
docker compose -f docker-compose.prod.yml logs -f db
```

Wait until you see `database system is ready to accept connections`.

## Step 5 — Verify the deployment

```bash
# API gateway health
curl http://localhost:8000/health

# Backend health
curl http://localhost:3001/health

# Frontend (should return HTML)
curl -I http://localhost:3000
```

## Updating to the latest images

```bash
# Pull the new images
docker compose -f docker-compose.prod.yml --env-file .env.prod pull

# Recreate containers with zero downtime (one service at a time)
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --no-deps frontend
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --no-deps backend
```

Or to restart the whole stack:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

## Pinning to a specific image version

In `.env.prod`, set `IMAGE_TAG` to a specific git SHA tag (e.g. `sha-abc1234`) instead of `latest`:

```
IMAGE_TAG=sha-abc1234
```

The GitHub Actions workflow publishes both `sha-<short>` and `latest` tags on every push to `main`.

## Persistent volumes

| Volume | Contents |
|--------|----------|
| `db_data` | PostgreSQL data directory |
| `minio_data` | MinIO object store (all uploaded files) |

**Back these up regularly.** Example backup for the database:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec db pg_dump -U postgres postgres > backup-$(date +%Y%m%d).sql
```

## Environment variables reference

See [`.env.prod.example`](../.env.prod.example) for the full list with descriptions.

### Backend-only variables (not needed in `.env.prod` if set in compose)

The production compose maps backend environment variables directly from `.env.prod`. The following variables from `backend/.env.example` are **not needed** as separate files when using Docker Compose:

- `SUPABASE_URL` — set to `http://kong:8000` (internal Docker network)
- `R2_ENDPOINT_URL` — set to `http://minio:9000` (internal Docker network)
- `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` — sourced from `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`

## Auth stack notes

- **GoTrue** issues JWTs and manages `auth.users`. It is the self-hosted equivalent of Supabase Auth.
- The backend validates tokens by calling GoTrue's `/auth/v1/user` endpoint via the nginx gateway — the same call the hosted Supabase SDK makes. **No auth bypass is present.**
- Email confirmation is controlled by `ENABLE_EMAIL_AUTOCONFIRM`. Set to `false` in production so users must verify their email address.
- Password-reset and invitation emails require a working SMTP configuration (`SMTP_*` variables).

## GHCR image publishing

Images are published automatically by the GitHub Actions workflow (`.github/workflows/docker-publish.yml`) on every push to `main`. Each push produces:

- `ghcr.io/techieanant/mike-frontend:latest`
- `ghcr.io/techieanant/mike-frontend:main`
- `ghcr.io/techieanant/mike-frontend:sha-<short>`
- Same tags for `mike-backend`

To publish images from a fork, fork the repository, enable GitHub Actions, and ensure `GITHUB_TOKEN` has `packages: write` permission (the workflow already requests this).

## Troubleshooting

### Database fails to start

- Check `docker compose logs db` for errors.
- Ensure the `db_data` volume is not corrupted. If needed, run `docker compose down -v` to wipe it and re-initialise.

### Auth fails (`Invalid or expired token`)

- Verify `JWT_SECRET`, `ANON_KEY`, and `SERVICE_ROLE_KEY` are consistent (all signed with the same secret).
- Check GoTrue logs: `docker compose logs auth`.

### MinIO bucket not created

- The `minio-init` service exits 0 on success and logs `MinIO initialisation complete.`
- If it failed, run it again: `docker compose up minio-init`.

### Frontend shows blank page or network error

- Ensure `SITE_URL` and `API_EXTERNAL_URL` match the actual public URLs your browser can reach.
- Remember `NEXT_PUBLIC_*` vars are **baked in at build time**. If your domain changed, rebuild the frontend image with the correct build args and push to GHCR (or build locally with `docker compose -f docker-compose.yml up --build frontend`).
