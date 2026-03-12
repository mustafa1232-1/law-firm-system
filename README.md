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
- `GET /api/v1/constitution/search?q=`
- `GET /api/v1/laws/search?q=`
- `GET /api/v1/decisions/search?q=`
- `POST /api/v1/decisions/ingest`
- `POST /api/v1/ai/case-analysis`
- `POST /api/v1/ai/legal-research`
- `POST /api/v1/ai/argument-builder`
- `POST /api/v1/ai/memo-draft`
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
cd backend && npm run seed:public-data

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
- storage vars (`STORAGE_*`)
- `OPENAI_API_KEY`

Seed curated legal references after setting `MONGODB_URI`:

```bash
cd backend
SEED_REPLACE=true npm run seed:public-data
```

Current seeded legal corpus includes:

- Iraqi Constitution full text (articles 1..144), sourced from: `https://www.sjc.iq/view.77/`
- Curated Iraqi law documents and indexed law articles
- Curated judicial decision records for search and retrieval

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
- Decision ingestion is designed for mixed data quality with review queue support.
- Case-law / constitution / laws / AI cross-linking is scaffolded for iterative expansion.
