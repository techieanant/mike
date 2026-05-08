# Mike

Open-source release containing the Mike frontend and backend.

## Contents

- `frontend/` - Next.js application
- `backend/` - Express API, Supabase access, document processing, and migrations
- `backend/migrations/000_one_shot_schema.sql` - one-shot schema for fresh databases

## Docker (recommended)

A fully self-hosted stack (no external Supabase, Postgres, or S3/R2 required):

```bash
cp .env.example .env        # fill in your AI key(s)
docker compose up --build
```

Open `http://localhost:3000`.

See the full guides:

- [Local development with Docker](docs/local-development.md)
- [Production deployment](docs/deployment.md)

## Manual setup (without Docker)

Install dependencies:

```bash
npm install --prefix backend
npm install --prefix frontend
```

Create local env files from the examples:

```bash
cp backend/.env.example backend/.env
cp frontend/.env.local.example frontend/.env.local
```

Run `backend/migrations/000_one_shot_schema.sql` against your Supabase or self-hosted Postgres instance.

Start the backend:

```bash
npm run dev --prefix backend
```

Start the frontend:

```bash
npm run dev --prefix frontend
```

Open `http://localhost:3000`.

## Required Services (manual setup)

- Supabase Auth and Postgres (or self-hosted GoTrue + PostgreSQL — see [docs/local-development.md](docs/local-development.md))
- S3-compatible object storage (Cloudflare R2, or self-hosted MinIO)
- At least one supported model provider key, depending on which models you enable
- LibreOffice for DOC/DOCX to PDF conversion

## Checks

```bash
npm run build --prefix backend
npm run build --prefix frontend
npm run lint --prefix frontend
```

## License

AGPL-3.0-only. See `LICENSE`.
