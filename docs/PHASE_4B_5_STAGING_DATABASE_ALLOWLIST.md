# Equilibrium — Phase 4B.5: Explicit Staging Database Allowlist & Hardened Safety Gate

**Date:** October 24, 2026  
**Auditor / Infrastructure Engineer:** Senior Technical Architect & Security Lead  
**Branch:** `equilibrium-staging`  
**Status:** **CLOUD PROVISIONING BLOCKED** (Pending creation of dedicated Supabase staging project & dashboard variable population)  
**Safety Stance:** Explicit Allowlist + Unconditional Blocklist (Fail-Closed) | Zero Secret Exposure

---

## 1. Executive Summary & Objective

Following the Phase 4B.4 audit—which revealed an ambiguity between the Render Blueprint database (`equilibrium-db`) and the active Supabase project (`rlqphunokjkxzqetondw`)—Phase 4B.5 transitions the staging safety architecture from a **negative blocklist model** to an **explicit positive allowlist + negative blocklist defense-in-depth model**.

Before any hosted staging deployment, build, or Prisma migration (`npx prisma migrate deploy`) can run, the staging environment must explicitly prove:
1. It is running on the dedicated hosted staging service (`RENDER_SERVICE_NAME === 'equilibrium-api-staging'`).
2. It has been provided an explicit, non-secret environment variable: **`STAGING_SUPABASE_PROJECT_REF`**.
3. Its `DATABASE_URL` connects strictly to a Supabase shared **Session Pooler** (`*.pooler.supabase.com`) on port **5432**.
4. Its database username strictly adheres to the Supabase shared-pooler format (`postgres.<STAGING_SUPABASE_PROJECT_REF>`), guaranteeing an exact match with the configured staging reference.
5. It does **not** connect to Render-managed databases (`equilibrium-db`, `*.render.com`, `dpg-*`).
6. It does **not** connect to direct database endpoints (`*.supabase.co`).
7. It does **not** connect to Supabase Transaction Poolers (port `6543`), which break PostgreSQL advisory locks required by Prisma migrations.
8. It does **not** reference any confirmed or candidate production database (`rlqphunokjkxzqetondw`, `cazlrtmmsikikexmepoc`, `equilibrium-db`), even if `STAGING_SUPABASE_PROJECT_REF` was mistakenly populated with one.
9. Local rehearsal (`ALLOW_LOCAL_START=true`) remains isolated, permitting localhost testing while **never** bypassing production target blocks.

---

## 2. Architecture & Safety Gate Implementation

### 2.1 Explicit Allowlist & Verification Rules (`server/scripts/prestart-check.js`)

The staging pre-start script executes in the staging container lifecycle before `npx prisma migrate deploy` and `node dist/server.js`.

```
Hosted Staging Startup Flow (server/scripts/prestart-check.js):
┌────────────────────────────────────────────────────────┐
│ 1. Fail-Closed Service Identity                        │
│    RENDER_SERVICE_NAME === 'equilibrium-api-staging'  │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 2. Unconditional Production Collision Blocklist        │
│    Host/User contains 'rlqphunokjkxzqetondw'          │
│    or 'cazlrtmmsikikexmepoc' or 'equilibrium-db'       │
│    (Runs in BOTH hosted and local rehearsal modes)     │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 3. Explicit Staging Project Reference Check            │
│    STAGING_SUPABASE_PROJECT_REF is present &           │
│    does not match any known production reference       │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 4. Hostname Allowlist Check                            │
│    - Rejects Render-managed hosts (*.render.com, dpg-*)│
│    - Rejects direct Supabase hosts (*.supabase.co)     │
│    - Requires Supabase shared Session Pooler           │
│      (^([a-z0-9-]+\.)*pooler\.supabase\.com$)         │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 5. Pooler Port Check                                   │
│    - Port === 5432 (Session Pooler)                   │
│    - Rejects Port 6543 (Transaction Pooler - lock err) │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 6. Database Username & Project Reference Match         │
│    Username === 'postgres.<STAGING_SUPABASE_PROJECT_REF>'
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 7. Sanitized CORS & JWT Validation                     │
│    - ALLOWED_ORIGINS present without wildcard '*'      │
│    - JWT_SECRET length >= 32 characters                │
└──────────────────────────┬─────────────────────────────┘
                           ▼
                  [PRESTART PASS: EXIT 0]
             Proceeds to `npx prisma migrate deploy`
```

### 2.2 Rejection Rules Detail

| Threat / Misconfiguration Vector | Error Code / Behavior | Error Message |
| :--- | :---: | :--- |
| **Missing or Mismatched Service Name** | Exit `1` | `FATAL: Service identity mismatch. Expected "equilibrium-api-staging"...` |
| **Production DB Target (`rlqphunokjkxzqetondw`)** | Exit `1` | `CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference.` |
| **Candidate Production Target (`cazlrtmmsikikexmepoc`)** | Exit `1` | `CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference.` |
| **Render-Managed Target (`equilibrium-db` / `dpg-*`)** | Exit `1` | `FATAL: Render-managed database target "..." is rejected for staging.` |
| **Direct Supabase Host (`*.supabase.co`)** | Exit `1` | `FATAL: Direct Supabase database URL ("...") is rejected. Staging requires the Supabase shared Session Pooler (*.pooler.supabase.com:5432).` |
| **Missing `STAGING_SUPABASE_PROJECT_REF`** | Exit `1` | `FATAL: Missing STAGING_SUPABASE_PROJECT_REF in hosted staging environment.` |
| **Mismatched Project Reference in Username** | Exit `1` | `FATAL: Database username mismatch. Expected "postgres.<ref>", received "postgres.<other>".` |
| **Production Ref in `STAGING_SUPABASE_PROJECT_REF`** | Exit `1` | `CRITICAL SAFETY BLOCK: STAGING_SUPABASE_PROJECT_REF matches a known production database reference.` |
| **Transaction Pooler Port (`6543`)** | Exit `1` | `FATAL: DATABASE_URL uses port 6543 (Transaction Pooler). Prisma migrations require Supabase Session Pooler (port 5432)...` |
| **Wildcard CORS Origin (`*`)** | Exit `1` | `FATAL: Wildcard CORS origin ("*") is rejected for staging.` |

---

## 3. Render Blueprint Update (`render.staging.yaml`)

In [`render.staging.yaml`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/render.staging.yaml), `STAGING_SUPABASE_PROJECT_REF` was added with `sync: false`:

```yaml
services:
  - type: web
    name: equilibrium-api-staging
    env: node
    plan: free
    rootDir: server
    buildCommand: npm ci && node scripts/use-pg-schema.js && npm run build
    startCommand: npm run start:staging
    healthCheckPath: /api/v1/health
    envVars:
      - key: NODE_ENV
        value: production
      - key: DATABASE_URL
        sync: false
      - key: STAGING_SUPABASE_PROJECT_REF
        sync: false
      - key: JWT_SECRET
        generateValue: true
      - key: ALLOWED_ORIGINS
        sync: false
```

### Safety Guarantee:
- `sync: false` ensures that Render will prompt for `STAGING_SUPABASE_PROJECT_REF` during manual service creation or require it to be configured in the Render Dashboard Environment tab.
- No project reference is hardcoded or guessed in version control.

---

## 4. Local Testing Separation (`ALLOW_LOCAL_START=true`)

Local rehearsal mode is explicitly decoupled from hosted constraints:
- **What is permitted locally:** Setting `ALLOW_LOCAL_START=true` permits developers and automated CI scripts to run tests against local databases (e.g. `postgresql://postgres:postgres@localhost:5432/equilibrium_test`) without requiring `RENDER_SERVICE_NAME` or `STAGING_SUPABASE_PROJECT_REF`.
- **What is strictly prohibited locally:** Local rehearsal **never** bypasses the unconditional known-production-reference blocks. If a developer accidentally points `DATABASE_URL` to `rlqphunokjkxzqetondw`, `cazlrtmmsikikexmepoc`, or `equilibrium-db`, `prestart-check.js` halts immediately with exit code `1` and a `CRITICAL SAFETY BLOCK`.

---

## 5. Automated Regression Test Suite

A dedicated 15-test regression suite was implemented in [`server/test/regression.staging-startup.test.ts`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/test/regression.staging-startup.test.ts):

| Test # | Test Name | Target Vector / Scenario | Exit Code | Verified Behavior |
| :---: | :--- | :--- | :---: | :--- |
| **1** | Production `npm start` isolation | `server/package.json` vs `render.yaml` | — | Production does NOT invoke `prestart-check.js`. |
| **2** | Staging `npm run start:staging` | `server/package.json` vs `render.staging.yaml` | — | Staging invokes `prestart-check.js` before migrations. |
| **3** | Unconditional production DB rejection | 7 distinct host/user URLs for `cazlrtmmsikikexmepoc`, `rlqphunokjkxzqetondw`, `equilibrium-db` | `1` | All 7 rejected with `CRITICAL SAFETY BLOCK`. |
| **4** | Hosted service identity check | Missing `RENDER_SERVICE_NAME` / Mismatch (`equilibrium-api`) | `1` | Fails closed before migrations run. |
| **5** | Missing or malformed DB URL | Missing, malformed, or non-postgres URLs (`mysql://`) | `1` | Fails closed with protocol/format errors. |
| **6** | Staging CORS origin hygiene | Missing `ALLOWED_ORIGINS` / Wildcard (`*`) | `1` | Rejects wildcards and empty origins. |
| **7** | Safe local-test mode gating | `ALLOW_LOCAL_START=true` vs omitted | `0` / `1` | Requires explicit flag for local execution. |
| **8** | Failures preserve nonzero exit & leak zero secrets | Port 6543 / Short JWT with sensitive strings | `1` | Exits `1`, zero passwords/secrets logged in stdout/stderr. |
| **9** | **Approved Staging Session Pooler URL passes** | Valid `equilibrium-api-staging`, `stagingref`, pooler host `5432` | **`0`** | **Preflight checks PASS successfully.** |
| **10** | **Render-managed DB rejected** | `equilibrium-db` / `*.render.com` / `dpg-*` | `1` | Rejected with `Render-managed database target rejected`. |
| **11** | **Direct Supabase URLs rejected** | `db.stagingref.supabase.co` / `stagingref.supabase.co` | `1` | Rejected with `Direct Supabase database URL rejected`. |
| **12** | **Missing / Mismatched Project Ref** | Missing ref / Mismatched ref / Prod ref in `STAGING_SUPABASE_PROJECT_REF` | `1` | Fails closed; blocks production refs in variable. |
| **13** | **Invalid port rejected** | Port `5433` (non-standard) / Port `6543` (Transaction Pooler) | `1` | Enforces port 5432 strictly. |
| **14** | **Missing username rejected** | `postgresql://aws-0-ap-south-1.pooler.supabase.com:5432/postgres` | `1` | Rejects missing username. |
| **15** | **Local mode cannot bypass production blocks** | `ALLOW_LOCAL_START=true` with prod URLs | `1` | Fails with `CRITICAL SAFETY BLOCK`. |

---

## 6. Full Verification Evidence

```bash
# 1. Staging Startup Regression Suite (15 / 15 tests pass)
npm test test/regression.staging-startup.test.ts
# Result: PASS (15 passed, 15 total, 2.647s)

# 2. Server Default Test Suite (113 / 113 tests pass)
npm test
# Result: PASS (9 suites passed, 113 passed, 113 total, 4.259s)

# 3. Full Database Integration Suite against local PostgreSQL (175 / 175 tests pass)
$env:DATABASE_URL="postgresql://postgres:postgres@localhost:5432/equilibrium_test?schema=public"; npm run test:api -- --runInBand
# Result: PASS (16 suites passed, 175 passed, 175 total, 27.273s)

# 4. Local Staging Smoke Test Rehearsal (14 / 14 steps pass)
npx tsx scripts/test-staging-smoke-local.ts
# Result: PASS (14 / 14 steps passed, 384ms, 0 errors)

# 5. TypeScript Compilation Check
npx tsc --noEmit
# Result: Clean (0 errors)

# 6. Flutter Frontend Test Suite (87 / 87 tests pass)
flutter test
# Result: All 87 tests passed
```

---

## 7. Cloud Staging Provisioning Status: BLOCKED

Cloud staging provisioning remains **`BLOCKED`**. Do not provision cloud resources, run remote migrations, commit, or push until the repository owner performs the manual configuration steps below.

### Checklist for Unblocking Cloud Staging Provisioning:

- [ ] **Step 1: Confirm Live Production Database** (per [`docs/PHASE_4B_4_DATABASE_IDENTITY_AUDIT.md`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/docs/PHASE_4B_4_DATABASE_IDENTITY_AUDIT.md)):
  Confirm whether `equilibrium-api` on Render uses Render internal `equilibrium-db` or Supabase `rlqphunokjkxzqetondw`.
- [ ] **Step 2: Create Dedicated Supabase Staging Project:**
  Create an entirely new, free-tier Supabase project named `equilibrium-staging`. Record its distinct project reference (`[NEW_STAGING_REF]`).
- [ ] **Step 3: Enable Session Pooler:**
  In the new Supabase project $\rightarrow$ Project Settings $\rightarrow$ Database $\rightarrow$ Connection Pooler: ensure Session Pooler on port **`5432`** is enabled.
- [ ] **Step 4: Configure Render Staging Environment:**
  In the Render Dashboard for `equilibrium-api-staging`:
  - Set `STAGING_SUPABASE_PROJECT_REF=[NEW_STAGING_REF]`.
  - Set `DATABASE_URL=postgresql://postgres.[NEW_STAGING_REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:5432/postgres`.
  - Set `ALLOWED_ORIGINS=https://staging.equilibrium.app` (or your staging client origin).
- [ ] **Step 5: Trigger Staging Build:**
  Only after Steps 1–4 are complete, deploy the `equilibrium-staging` branch to Render. The safety gate will verify `[NEW_STAGING_REF]` and safely run pending Prisma migrations.
