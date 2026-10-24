# Phase 4B: Final Pre-Deployment Validation Checklist

**Project:** Equilibrium — Student Workload, Focus & Sleep Balancing System  
**Artifact:** `render.staging.yaml` Validation & Deployment Readiness  
**Date:** 2026-10-24  
**Author:** Antigravity Agentic Pair Programmer  
**Validation Status:** SCHEMA VERIFIED (Manual Operator Deployment Pending)

---

## 1. Executive Summary & Validation Scope

This document provides the final pre-deployment audit of the Equilibrium staging Blueprint ([render.staging.yaml](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/render.staging.yaml)).

### Provider Validation Tooling Disclosure
> [!IMPORTANT]
> **Render CLI and Render API Validation Status**:
> The Render CLI (`render blueprints validate`) and Render API validation endpoint (`POST /v1/blueprints/validate`) were **unavailable** in the local operating environment because the CLI binary was not installed and no `RENDER_API_KEY` credential is configured locally.
>
> Therefore, this assessment was performed via an **exhaustive schema-based and relationship review** against the official Render Blueprint Specification (v1) and parsed directly using `js-yaml`. It has **NOT** been submitted to or validated by Render's remote API.

---

## 2. Resource Naming & Production Non-Interference Audit

An automated diff between the production Blueprint ([render.yaml](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/render.yaml)) and staging Blueprint ([render.staging.yaml](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/render.staging.yaml)) confirmed complete physical isolation:

| Property | Production (`render.yaml`) | Staging (`render.staging.yaml`) | Isolation Verified? |
| :--- | :--- | :--- | :---: |
| **Web Service Name** | `equilibrium-api` | `equilibrium-api-staging` | **YES** (Unique) |
| **Database Resource Name** | `equilibrium-db` | `equilibrium-db-staging` | **YES** (Unique) |
| **Database Instance Name** | `equilibrium` | `equilibrium_staging` | **YES** (Unique) |
| **Database User** | `equilibrium` | `equilibrium_staging` | **YES** (Unique) |
| **Database Binding Reference** | `fromDatabase: name: equilibrium-db` | `fromDatabase: name: equilibrium-db-staging` | **YES** (Distinct target) |
| **Public Hostname Reference** | `https://equilibrium-42g8.onrender.com` | `https://equilibrium-api-staging.onrender.com` | **YES** (Distinct target) |

**Verification Result**: `render.staging.yaml` does not reference, modify, or replace any production resources. There is zero namespace collision.

---

## 3. Free-Tier Compliance & Provider Compatibility

Both services defined in `render.staging.yaml` explicitly declare `plan: free`:

```yaml
services:
  - type: web
    name: equilibrium-api-staging
    plan: free
    ...

databases:
  - name: equilibrium-db-staging
    plan: free
```

### Free-Tier Quota & Behavior Specifications

1. **Web Service (`equilibrium-api-staging`)**:
   - **Cost**: $0.00 / month.
   - **Hardware Allocation**: 512 MB RAM, 0.1 vCPU.
   - **Spin-Down (Sleep)**: Automatically sleeps after **15 minutes of inactivity**.
   - **Cold Start**: Container wake-up takes **30–60 seconds** on the next inbound request.
   - **Monthly Usage**: 750 free instance hours per workspace per month (sufficient for continuous 24/7 staging operation).
2. **PostgreSQL Database (`equilibrium-db-staging`)**:
   - **Cost**: $0.00 / month.
   - **Storage Limit**: 1 GB SSD, 256 MB RAM, max 100 connections.
   - **Critical Provider Limitation A (30-Day Expiry)**: Render automatically expires free databases **30 days** after creation.
   - **Critical Provider Limitation B (Workspace Limit)**: Render permits **only ONE free database per workspace**.
   - *Impact*: If the user's Render workspace already contains `equilibrium-db` (production), Render Blueprint creation will halt with an error stating the free database limit has been reached.

---

## 4. Startup Command & Database Migration Safety

### Build and Start Pipeline
In `render.staging.yaml`:
```yaml
buildCommand: npm ci && node scripts/use-pg-schema.js && npm run build
startCommand: npm start
```

1. **Build Step**:
   - `npm ci`: Installs exact locked dependencies.
   - `node scripts/use-pg-schema.js`: Verifies `prisma/schema.prisma` is configured with `provider = "postgresql"`.
   - `npm run build`: Executes `npx prisma generate && tsc`, building TypeScript to `dist/server.js`.
2. **Start Step (`npm start`)**:
   - In `server/package.json`, line 9:
     ```json
     "start": "npx prisma migrate deploy && node dist/server.js"
     ```
   - `npx prisma migrate deploy` executes before the server begins listening on the port.
   - `DATABASE_URL` is sourced exclusively from `fromDatabase: name: equilibrium-db-staging`.
   - Pending migrations applied:
     - `20261006090000_user_timezone_default_ist`
     - `20261024143000_add_task_actual_and_remaining_minutes`
     - `20261024150000_add_task_progress_operation`
   - Migrations **cannot** target production because `DATABASE_URL` is bound strictly to `equilibrium-db-staging`.

---

## 5. Environment Variables & Secret Configuration Strategy

Every required environment variable is managed without embedding secrets into repository files:

| Environment Variable | Source / Strategy in Staging | Secret Value Stored in Git? | Safety Analysis |
| :--- | :--- | :---: | :--- |
| `NODE_ENV` | Explicit `production` | No | Enables production security middleware and rate limiting. |
| `DATABASE_URL` | Injected via Render internal `fromDatabase: name: equilibrium-db-staging` | No | Connection string generated dynamically by Render platform. |
| `JWT_SECRET` | Render `generateValue: true` | No | Render automatically generates a unique 32-character cryptographically secure string. |
| `ALLOWED_ORIGINS` | Explicit `*` | No | Allows staging test harnesses and Flutter web staging clients to access API. |
| `APP_PUBLIC_URL` | Explicit `https://equilibrium-api-staging.onrender.com` | No | Pointers and redirect links point exclusively to staging. |
| `PORT` | Injected dynamically by Render (defaults to 10000) | No | Bound automatically to web server listener. |
| `RESEND_API_KEY` | Server fallback default (`re_test`) | No | Email delivery is stubbed; prevents unintended outbound emails during tests. |

---

## 6. Alternative Staging Database: Render vs. Supabase

Because Render enforces a strict **1-free-database per workspace** quota, the Blueprint configuration assumes Render PostgreSQL, which may trigger a quota conflict if `equilibrium-db` already exists.

### Minimal Safe Configuration for Supabase Staging Database

If a separate free **Supabase** project is selected for staging:
1. In `render.staging.yaml`:
   - Delete the entire `databases:` section (lines 26–31).
   - In `services[0].envVars`, replace the `DATABASE_URL` definition with:
     ```yaml
           - key: DATABASE_URL
             sync: false
     ```
2. In the Render Dashboard (Web Service > Environment):
   - Set `DATABASE_URL` to the Supabase pooled connection string:
     ```text
     postgresql://postgres.[staging-project-ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres?pgbouncer=true&connection_limit=1
     ```
3. **Safety Benefit**:
   - Zero cost ($0.00).
   - No 30-day automatic database deletion.
   - Bypasses Render's 1-free-database workspace limit.
   - Connection strings remain strictly inside dashboard secrets, never committed to Git.

---

## 7. Smoke-Test Workflow Wiring Audit

Inspected [.github/workflows/staging-smoke.yml](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/.github/workflows/staging-smoke.yml):

```yaml
name: Staging Smoke Test

on:
  workflow_dispatch:
    inputs:
      staging_url:
        description: 'Staging API Base URL (e.g. https://staging-api.equilibrium.app/api/v1)'
        required: true
        type: string
      staging_allowed_host:
        description: 'Explicit Approved Staging Hostname (e.g. staging-api.equilibrium.app)'
        required: true
        type: string
      test_email:
        description: 'Dedicated Staging Test Account Email (leave blank to use secret or default)'
        required: false
        type: string

jobs:
  smoke-test:
    name: Staging Verification Suite
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: server
    steps:
      ...
      - name: Preflight Secrets & Safety Check
        run: |
          if [ -z "${{ secrets.STAGING_TEST_PASSWORD }}" ]; then
            echo "::error::Missing repository secret STAGING_TEST_PASSWORD. Test halted before network activity."
            exit 1
          fi
          if [ -z "${{ inputs.staging_allowed_host }}" ]; then
            echo "::error::Missing staging_allowed_host input. Target validation is fail-closed."
            exit 1
          fi

      - name: Run Staging Smoke Test Harness
        run: npm run smoke:staging
        env:
          STAGING_API_URL: ${{ inputs.staging_url }}
          STAGING_ALLOWED_HOST: ${{ inputs.staging_allowed_host }}
          STAGING_TEST_EMAIL: ${{ inputs.test_email || secrets.STAGING_TEST_EMAIL }}
          STAGING_TEST_PASSWORD: ${{ secrets.STAGING_TEST_PASSWORD }}
          ALLOW_LOCALHOST: 'false'
```

### Invariants Confirmed
1. **Manual Trigger Only**: Gated behind `workflow_dispatch`. Cannot execute unexpectedly.
2. **Fail-Closed Target Gating**: Both `staging_url` and `staging_allowed_host` are required.
3. **No Embedded Credentials**: Password must be provided via GitHub Actions secret `STAGING_TEST_PASSWORD`. Missing secrets fail before any network call.
4. **Localhost Prohibited**: `ALLOW_LOCALHOST: 'false'` is hardcoded in the workflow.
5. **Exact Match with Harness**: Parameter names (`STAGING_API_URL`, `STAGING_ALLOWED_HOST`, `STAGING_TEST_EMAIL`, `STAGING_TEST_PASSWORD`) map 1:1 with `server/scripts/staging-smoke-test.ts`.

---

## 8. Dashboard Deployment Checklist

Follow this checklist to deploy the staging environment safely:

```mermaid
flowchart TD
    A[Log in to dashboard.render.com] --> B[Click New + > Blueprint]
    B --> C[Select repo: shreeK05/Equilibrium]
    C --> D{Render Workspace has existing free DB?}
    D -- Yes --> E[Option A: Create separate free Staging Workspace in Render<br/>OR Option B: Use Supabase Staging DB]
    D -- No --> F[Set Blueprint Path: render.staging.yaml]
    E --> F
    F --> G[Click Apply Blueprint]
    G --> H[Wait for build: npm ci && npm run build && npm start]
    H --> I[Copy assigned URL: https://equilibrium-api-staging-xxxx.onrender.com]
    I --> J[Set GitHub Secret: STAGING_TEST_PASSWORD]
    J --> K[Trigger GitHub Actions workflow: staging-smoke.yml]
```

### Pre-Deployment Verification Tasks
- [x] `render.staging.yaml` uses valid YAML syntax (verified with `js-yaml`).
- [x] Staging services and databases have unique names suffixed `-staging`.
- [x] `plan: free` is explicitly configured for all resources.
- [x] Start command executes `npx prisma migrate deploy` on staging database.
- [x] `JWT_SECRET` uses `generateValue: true` (no shared secrets).
- [x] Zero changes committed to Git.
- [x] Production database and API remain untouched.

### Operator Actions Required
1. Log into [dashboard.render.com](https://dashboard.render.com).
2. Create Blueprint pointing to `render.staging.yaml`.
3. If free database quota is reached on Render, set `DATABASE_URL` to a free Supabase staging database in service settings.
4. Add `STAGING_TEST_PASSWORD` to GitHub Actions secrets.
5. Execute `staging-smoke.yml` workflow via GitHub Actions UI.
