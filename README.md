# PearlHub Pro

Full-stack Sri Lanka travel & lifestyle platform.

## Repository structure

```
.github/workflows/   — CI/CD: web deploy, Flutter APK builds, SDK publish
web/                 — React 19 + TypeScript + Vite + Supabase web app
flutter/
  customer/          — Customer Flutter app (Riverpod + GoRouter)
  provider/          — Provider Flutter app
  admin/             — Admin Flutter app
  pearlhub_shared/   — Shared Dart package (models, services, providers)
sdk-ts/              — @pearlhub/sdk TypeScript SDK
sdk-dart/            — pearlhub_sdk Dart SDK
supabase/            — Shared Supabase config & migrations (symlink/reference)
docs/                — Architecture notes & SQL scripts
```

## Web quick start

```bash
cd web
pnpm install
cp .env.example .env   # fill in VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
pnpm dev
```

## Flutter quick start

```bash
cd flutter/pearlhub_shared && flutter pub get
cd ../customer && flutter pub get && flutter run
```

## Deployment

- **Web**: Vercel — triggered automatically on push to `main` via GitHub Actions
- **Flutter**: APKs built by GitHub Actions on every push/PR to `main`
- **SDK**: Published to npm on `sdk-ts/v*` tag

## Required GitHub secrets

| Secret | Used by |
|--------|---------|
| `VITE_SUPABASE_URL` | web-deploy workflow |
| `VITE_SUPABASE_ANON_KEY` | web-deploy workflow |
| `VERCEL_TOKEN` | web-deploy workflow |
| `VERCEL_ORG_ID` | web-deploy workflow |
| `VERCEL_PROJECT_ID` | web-deploy workflow |
| `SUPABASE_URL` | flutter-build workflow |
| `SUPABASE_ANON_KEY` | flutter-build workflow |
| `NPM_TOKEN` | sdk-ts-publish workflow |
