# PearlHub Pro

Production-focused monorepo for PearlHub, covering the web app, Flutter apps, SDKs, and Supabase backend.

## Current launch branch

Active hardening work is on `production-hardening`.

## Primary documentation

- [Production hardening and launch guide](docs/PRODUCTION_HARDENING_AND_LAUNCH.md)
- [Web app guide](web/README.md)

## Repository structure

```text
.github/workflows/   GitHub Actions for web deploy, Flutter builds, SDK publish
web/                 React 19 + TypeScript + Vite frontend
flutter/             Customer, provider, admin, and shared Flutter packages
sdk-ts/              TypeScript SDK
sdk-dart/            Dart SDK
supabase/            Edge Functions, migrations, and project config
docs/                Launch, security, and architecture documentation
```

## Quick start

```bash
git clone https://github.com/anasbikes1992-ui/PearlHubcode.git
cd PearlHubcode
git checkout production-hardening
cd web
npm install --legacy-peer-deps
npm run dev
```

## Security note

Client-safe variables belong in `web/.env.local`.
Server secrets belong in Supabase Edge Function secrets or the ignored `supabase/.env.local` file for local development.

## Required GitHub secrets

| Secret | Used by |
| --- | --- |
| `VERCEL_TOKEN` | web deploy workflow |
| `VERCEL_ORG_ID` | web deploy workflow |
| `VERCEL_PROJECT_ID` | web deploy workflow |
| `NPM_TOKEN` | sdk ts publish workflow |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Edge Functions deployment |
| `PAYHERE_MERCHANT_ID` | create-payhere-session, payment-webhook |
| `PAYHERE_MERCHANT_SECRET` | create-payhere-session, payment-webhook |
| `WEBXPAY_MERCHANT_ID` | next payment phase |
| `WEBXPAY_SECRET` | next payment phase |

