# Local Development with Docker

This guide describes how to run a fully self-hosted Mike stack on your local machine using Docker Compose. No hosted Supabase, Postgres, or S3/R2 account is required.

## Prerequisites

- [Docker Desktop](https://docs.docker.com/get-docker/) (or Docker Engine + Compose v2)
- At least one AI provider API key (Gemini, Anthropic, or OpenRouter)

## Stack overview

| Service | Image | Purpose |
|---------|-------|---------|
| `db` | `supabase/postgres:15.6.1.143` | PostgreSQL with Supabase auth schema (`auth.users`, RLS functions) |
| `auth` | `supabase/gotrue:v2.151.0` | Supabase-compatible auth API (sign-up, sign-in, JWT issuance) |
| `rest` | `postgrest/postgrest:v12.2.3` | Database REST API consumed by the Supabase JS client |
| `kong` | `nginx:1.27-alpine` | API gateway — routes `/auth/v1/*` → GoTrue, `/rest/v1/*` → PostgREST |
| `minio` | `minio/minio` | S3-compatible object storage |
| `minio-init` | `minio/mc` | One-shot bucket initialiser |
| `backend` | built from `./backend` | Mike Express API |
| `frontend` | built from `./frontend` | Mike Next.js app |

## Quick start

### 1. Copy and edit the environment file

```bash
cp .env.example .env
```

Open `.env` and fill in at least one AI key (`GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, or `OPENROUTER_API_KEY`).

The file ships with pre-generated example JWT keys that work with the default `JWT_SECRET`. These are **fine for local development only** — replace them before any production or shared deployment.

### 2. Build and start the stack

```bash
docker compose up --build
```

The first build downloads base images and compiles the frontend/backend, which can take a few minutes. Subsequent starts are much faster.

Wait until you see:

```
frontend-1  | ▲ Next.js 16.x.x
frontend-1  | ✓ Ready
```

### 3. Open the app

Navigate to **http://localhost:3000**.

Create an account using the sign-up page. Because `ENABLE_EMAIL_AUTOCONFIRM=true` is set by default, email verification is skipped in local dev.

## Port assignments

| Port | Service |
|------|---------|
| 3000 | Frontend |
| 3001 | Backend API |
| 8000 | API gateway (Supabase-compatible URL) |
| 5432 | PostgreSQL (direct access) |
| 9000 | MinIO API |
| 9001 | MinIO console (web UI) |

## Persistent storage

Docker named volumes are used for persistence across restarts:

- `db_data` — PostgreSQL data directory
- `minio_data` — MinIO object store

To wipe all local data and start fresh:

```bash
docker compose down -v
```

## Database schema bootstrap

The schema is applied automatically on the **first** container start via Docker's init-script mechanism:

1. `backend/migrations/000_one_shot_schema.sql` → mounted as `/docker-entrypoint-initdb.d/20_app_schema.sql`
2. `db/init/30_permissions.sql` → mounted as `/docker-entrypoint-initdb.d/30_permissions.sql`

These scripts run only when the `db_data` volume is empty (i.e., on a fresh start). To re-apply them, remove the volume first:

```bash
docker compose down -v db
docker compose up db
```

## MinIO object storage

The `minio-init` service runs `scripts/init-minio.sh` once at startup to create the application bucket (`mike` by default). The MinIO web console is available at **http://localhost:9001** (credentials from `.env`: `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`).

## Regenerating JWT keys

The example `.env` ships with demo JWT keys from the Supabase self-hosting documentation. If you want to generate your own:

1. Generate a new secret:

   ```bash
   openssl rand -base64 40
   ```

2. Create the `anon` JWT at [jwt.io](https://jwt.io) using HS256 and this payload:

   ```json
   {
     "role": "anon",
     "iss": "supabase",
     "iat": 1641769200,
     "exp": 1799535600
   }
   ```

3. Create the `service_role` JWT with the same secret and this payload:

   ```json
   {
     "role": "service_role",
     "iss": "supabase",
     "iat": 1641769200,
     "exp": 1799535600
   }
   ```

4. Update `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`, and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY` in your `.env`.

## Auth stack notes

- GoTrue manages `auth.users` in the `auth` Postgres schema.
- The backend's `requireAuth` middleware calls `admin.auth.getUser(token)` which proxies to GoTrue via the nginx gateway. **No auth bypass is introduced.**
- The frontend uses the Supabase JS client pointed at `http://localhost:8000` (the nginx gateway).

## Environment variables reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `POSTGRES_PASSWORD` | ✓ | `postgres` | PostgreSQL superuser password |
| `JWT_SECRET` | ✓ | — | HS256 secret for signing/verifying JWTs |
| `ANON_KEY` | ✓ | (demo) | JWT with `role: anon` |
| `SERVICE_ROLE_KEY` | ✓ | (demo) | JWT with `role: service_role` |
| `SITE_URL` | — | `http://localhost:3000` | Frontend URL (used by GoTrue for auth redirects) |
| `ENABLE_EMAIL_AUTOCONFIRM` | — | `true` | Skip email verification (set `false` to require it) |
| `MINIO_ROOT_USER` | — | `minioadmin` | MinIO credentials |
| `MINIO_ROOT_PASSWORD` | — | `minioadmin` | MinIO credentials |
| `R2_BUCKET_NAME` | — | `mike` | Storage bucket name |
| `GEMINI_API_KEY` | — | — | Google Gemini API key |
| `ANTHROPIC_API_KEY` | — | — | Anthropic API key |
| `OPENROUTER_API_KEY` | — | — | OpenRouter API key |
| `RESEND_API_KEY` | — | — | Resend email API key |

## Common commands

```bash
# Start (foreground)
docker compose up --build

# Start (background)
docker compose up --build -d

# View logs
docker compose logs -f backend
docker compose logs -f frontend

# Stop and remove containers (keep volumes)
docker compose down

# Stop and remove containers AND volumes (full reset)
docker compose down -v

# Rebuild a single service
docker compose up --build backend
```
