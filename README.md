# LexIQ Iraq

Production-ready foundation for an Iraqi legal intelligence platform.

## What is included

- `backend/` NestJS + TypeScript + MongoDB (Mongoose)
- `lib/` Flutter multi-platform app (Android / iOS / Web / Windows)
- JWT auth + refresh tokens + RBAC guard foundation
- Full module scaffold for law-firm operations + legal knowledge + AI copilot + ingest pipeline
- Swagger docs, health endpoint, Dockerfile, Railway-ready config
- Arabic-first runtime support: RTL direction, Arabic locale, Arabic-capable typography stack, localization delegates

## Monorepo structure

- `backend/src/common`
- `backend/src/config`
- `backend/src/modules/*`
- `lib/core`
- `lib/theme`
- `lib/shared`
- `lib/features/*`

## Backend modules

Implemented modules:

- `auth`
- `users`
- `firms`
- `clients`
- `cases` (includes `POST /cases/:id/analyze` Case Genome foundation)
- `hearings`
- `tasks`
- `documents`
- `billing`
- `constitution`
- `laws`
- `decisions`
- `courts`
- `research`
- `ai`
- `ingest`
- `notifications`
- `admin`
- `health`
- `audit`
- `legal-taxonomy`

## Core backend endpoints

- `POST /api/v1/auth/register`
- `POST /api/v1/firms/register-company`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/cases`
- `POST /api/v1/cases`
- `POST /api/v1/cases/:id/analyze`
- `POST /api/v1/documents/upload` (multipart upload)
- `GET /api/v1/courts?q=...`
- `GET /api/v1/constitution/search?q=`
- `GET /api/v1/laws/search?q=`
- `GET /api/v1/decisions/search?q=`
- `POST /api/v1/decisions/ingest`
- `POST /api/v1/ai/case-analysis`
- `POST /api/v1/ai/legal-research`
- `POST /api/v1/ai/argument-builder`
- `POST /api/v1/ai/memo-draft`
- `POST /api/v1/ai/analyses/save`
- `POST /api/v1/ai/analyses/:id/attach-case`
- `GET /api/v1/ai/analyses`
- `GET /api/v1/ai/sessions`
- `GET /api/v1/constitution/article-number/:articleNumber`
- `GET /api/v1/health`

Swagger:

- `http://localhost:4000/docs`

## Local run

### 1. Backend

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

### 2. Frontend

```bash
flutter pub get
flutter run -d chrome
```

Optional (set custom app name and API URL at runtime):

```bash
flutter run -d chrome \
  --dart-define=APP_NAME="LexIQ Iraq" \
  --dart-define=API_BASE_URL="http://localhost:4000/api/v1"
```

## Quality checks

```bash
# Backend
cd backend && npm run build
cd backend && npm run sync:constitution
cd backend && npm run verify:constitution
cd backend && npm run seed:public-data
cd backend && npm run reset:production

# Frontend
flutter analyze
flutter test
```

## AI safety notes

AI outputs are intentionally review-aware:

- They are preliminary legal suggestions.
- They are not final legal advice.
- Responses are citation-aware and confidence-scored from indexed sources.

## Railway deployment

This repository includes `railway.json` for deploying backend from monorepo root.

### Variables to set in Railway service

Use `backend/.env.example` as the canonical source and set at least:

- `PORT`
- `MONGODB_URI`
- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`
- `CORS_ORIGINS`

Optional:

- `REDIS_URL`
- storage vars (`STORAGE_*`) including:
  - `STORAGE_PROVIDER=local|s3|r2`
  - `STORAGE_BUCKET`, `STORAGE_ENDPOINT`, `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY`
  - `STORAGE_PROJECT_PREFIX=lexiq-iraq` (isolates this project in one bucket folder)
  - `STORAGE_LOCAL_ROOT=uploads`
  - `STORAGE_PUBLIC_BASE_URL=https://your-domain`
- `OPENAI_API_KEY`
- `OPENAI_MODEL`
- `OPENAI_EMBEDDING_MODEL`
- `EMBEDDINGS_PROVIDER=openai` (to use OpenAI embeddings)

Seed curated legal references after setting `MONGODB_URI`:

```bash
cd backend
SEED_REPLACE=true npm run seed:public-data
```

Current seeded legal corpus includes:

- Iraqi Constitution full text (articles 1..144)
  - Searchable extraction source: `https://www.sjc.iq/view.77/`
  - Official PDF reference: `https://mofa.gov.iq/wp-content/uploads/sites/85/2019/11/%D8%AF%D8%B3%D8%AA%D9%88%D8%B1-%D8%AC%D9%85%D9%87%D9%88%D8%B1%D9%8A%D8%A9-%D8%A7%D9%84%D8%B9%D8%B1%D8%A7%D9%82.pdf`
- Constitution records include article ordering and extracted paragraph chunks for full-article reading views
- Curated Iraqi law documents and indexed law articles
- Expanded curated judicial decision records for search and retrieval
- Iraqi courts directory (seeded from publicly available OSM courthouse data) with searchable location metadata

Constitution import/encoding safety:

- `npm run sync:constitution` rebuilds `backend/data/public/constitution_articles.seed.json` with strict 1..144 validation.
- `npm run verify:constitution` fails if any article is missing, empty, or has broken encoding markers.

## Production reset and super admin

To wipe all existing MongoDB data and keep only one super-admin account:

```bash
cd backend
MONGODB_URI=... npm run reset:production
```

Default seeded super-admin credentials:

- Email: `mustafa@1.net`
- Password: `12345678`

You can override via env vars:

- `SUPER_ADMIN_EMAIL`
- `SUPER_ADMIN_PASSWORD`
- `SUPER_ADMIN_NAME`

The reset script also re-seeds:

- Constitution: 144 articles
- Laws: seeded law docs + indexed articles
- Judicial decisions: expanded public reference set
- Courts directory: searchable Iraqi courts with governorate/city/district/area metadata

### Deploy with Railway CLI

```bash
railway login
railway link
railway up
```

After deploy:

- Health: `/api/v1/health`
- Swagger: `/docs`

## Notes

- Large files are not stored in MongoDB, only metadata + storage path.
- `local` storage provider serves files under `/storage/*` from backend disk.
- For durable production storage, use `STORAGE_PROVIDER=s3` or `r2`.
- Decision ingestion is designed for mixed data quality with review queue support.
- Case-law / constitution / laws / AI cross-linking is scaffolded for iterative expansion.
