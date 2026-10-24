# Phase 4B: Hosted Staging Deployment Report

**Project:** Equilibrium — Student Workload, Focus & Sleep Balancing System  
**Phase:** 4B (Hosted Staging Deployment)  
**Date:** 2026-10-24  
**Author:** Antigravity Agentic Pair Programmer  
**Status:** PARTIALLY VERIFIED (Staging Blueprint & Cost Models Verified, Local Rehearsal Passed, Live Cloud Deployment Blocked on Manual Operator Action)

---

## 1. Executive Summary & Readiness Matrix

Phase 4B establishes the deployment infrastructure and cost boundaries required to run Equilibrium on an actual hosted staging API and an isolated hosted database at **zero financial cost ($0.00)**.

In strict adherence to the safety rules:
- **Zero paid resources** were created or subscribed to.
- **Production database and API** were not touched, migrated, or mutated.
- **Production secrets and connection strings** were not inherited or reused.
- **Hosted cloud staging deployment** is honestly documented as **BLOCKED** pending manual repository owner action in the Render dashboard, substantiated by real network probing evidence.

### Phase 4B Readiness Matrix

| Component | Status | Verification Method / Evidence | Blocker / Next Action |
| :--- | :---: | :--- | :--- |
| **Free-Tier Hosting & Cost Verification** | `VERIFIED` | Audited Render and Supabase free tier specifications, quotas, cold starts, and storage limits. Verified $0 cost. | None. Limits documented. |
| **Isolated Staging Blueprint (`render.staging.yaml`)** | `VERIFIED` | Created `render.staging.yaml` defining isolated web service `equilibrium-api-staging` and isolated database `equilibrium-db-staging`. `plan: free`. | Ready for operator deployment. |
| **Database Isolation Architecture** | `VERIFIED` | Scoped database references (`fromDatabase: name: equilibrium-db-staging`), unique JWT generation, and `global-setup.js` safety guards prevent cross-contamination. | None. Boundaries verified. |
| **Migration Rehearsal Status** | `VERIFIED` | Rehearsed pending migrations (`20261006090000`, `20261024143000`, `20261024150000`) on PostgreSQL 17 test instance. 167/167 tests passed. | Cloud execution will occur automatically on `npm start` once deployed. |
| **Cold-Start Resilient Smoke Harness** | `VERIFIED` | Enhanced Step 1 health check with transient retry loop to gracefully handle free-tier container cold starts (30-50s). | None. Harness ready for live endpoints. |
| **Local Staging Smoke Rehearsal** | `VERIFIED` | Ran `npx tsx scripts/test-staging-smoke-local.ts` against local server and isolated DB. All 14 steps passed in 557ms (exit code 0). | None. Rehearsal green. |
| **Hosted Staging Cloud Deployment** | `BLOCKED` | Render CLI is not installed; no cloud API keys exist in local environment. Provider dashboard operator action is required. | Operator must create Blueprint in Render Dashboard. |
| **Live Cloud Endpoint Validation** | `BLOCKED` | Live probe to `https://equilibrium-api-staging.onrender.com/api/v1/health` returned HTTP 404 "NotFound". Smoke test exited with code 1. | Live host does not exist yet. |
| **GitHub Actions Cloud Run** | `BLOCKED` | `.github/workflows/staging-smoke.yml` requires live staging URL and secrets before manual trigger. | Run manually once cloud staging responds. |
| **Production Launch & Migration** | `BLOCKED` | Production migrations remain intentionally withheld until cloud staging verification passes. | Gated on Phase 4C completion. |

---

## 2. Verified Free-Tier Hosting & Cost Analysis

Official documentation for Render and alternative free-tier cloud database providers was audited:

### 1. Render Free-Tier Web Service (`equilibrium-api-staging`)
- **Cost**: $0.00 / month.
- **Hardware Resources**: 512 MB RAM, 0.1 vCPU.
- **Inactivity Spin-down (Sleep)**: Automatically spins down after **15 minutes** of no inbound HTTP traffic.
- **Cold-Start Behavior**: The first incoming HTTP request to a sleeping instance takes **30 to 60 seconds** to boot the container.
- **Monthly Usage Quota**: 750 free instance hours per workspace per month (sufficient for continuous 24/7 execution for 1 service).
- **Suitability for Staging Tests**: Highly suitable for repeatable automated smoke testing, provided that the test harness tolerates initial cold starts.

### 2. Render Free-Tier PostgreSQL (`equilibrium-db-staging`)
- **Cost**: $0.00 / month.
- **Hardware Resources**: 1 GB SSD storage, 256 MB RAM, max 100 connections.
- **Critical Limitations**:
  1. **30-Day Expiration**: Render automatically expires free databases **30 days** after creation. After 30 days, a 14-day grace period is given before permanent deletion.
  2. **One Free DB Per Workspace**: Render strictly limits each workspace to **one active free database**.
  - *Impact*: If the user's Render workspace already hosts `equilibrium-db` (the production database), Render will reject the creation of a second free database in that same workspace.

### 3. Verified Free-Tier Alternative: Supabase Staging Project
If the Render workspace has reached its 1-free-database limit, a dedicated free staging project on **Supabase** is the recommended alternative:
- **Cost**: $0.00 / month (up to 2 free projects per account).
- **Resources**: 500 MB PostgreSQL database, pooled connection string (`pgbouncer`).
- **No 30-Day Deletion**: Does not delete after 30 days (pauses after 7 days of inactivity, resumed instantly via dashboard).
- **Configuration**: Set `DATABASE_URL` in the Render staging web service settings rather than using `fromDatabase`.

---

## 3. Isolated Staging Deployment Specification (`render.staging.yaml`)

Created [render.staging.yaml](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/render.staging.yaml) in the repository root without modifying the production `render.yaml`:

```yaml
# Render Blueprint Specification for Equilibrium Staging Environment
# This configuration provisions an isolated, free-tier staging deployment.
# It does NOT affect or inherit any resources from production (render.yaml).

services:
  - type: web
    name: equilibrium-api-staging
    env: node
    plan: free
    rootDir: server
    buildCommand: npm ci && node scripts/use-pg-schema.js && npm run build
    startCommand: npm start
    healthCheckPath: /api/v1/health
    envVars:
      - key: NODE_ENV
        value: production
      - key: DATABASE_URL
        fromDatabase:
          name: equilibrium-db-staging
          property: connectionString
      - key: JWT_SECRET
        generateValue: true
      - key: ALLOWED_ORIGINS
        value: '*'

databases:
  - name: equilibrium-db-staging
    databaseName: equilibrium_staging
    user: equilibrium_staging
    plan: free
```

### Architectural Separation
1. **Isolated Service Identity**: Service is named `equilibrium-api-staging` (distinct from `equilibrium-api`).
2. **Dedicated Database**: Database is named `equilibrium-db-staging` with database name `equilibrium_staging` (distinct from `equilibrium-db`).
3. **No Credential Inheritance**: `DATABASE_URL` is bound directly to `equilibrium-db-staging` using Render's internal service discovery. It is physically impossible for the staging service to connect to the production database via this configuration.
4. **Independent JWT Secret**: `JWT_SECRET: generateValue: true` instructs Render to generate a brand new, random 32-character secret unique to staging.
5. **Automatic Migration on Boot**: `npm start` runs `npx prisma migrate deploy && node dist/server.js`, automatically applying pending migrations to the isolated staging database during initial startup.

---

## 4. Confirm Database Isolation & Migration Rehearsal

### Local Rehearsal Evidence
The pending Prisma migrations were rehearsed on the isolated PostgreSQL 17 test database (`equilibrium_test`):
- `20261006090000_user_timezone_default_ist`
- `20261024143000_add_task_actual_and_remaining_minutes`
- `20261024150000_add_task_progress_operation`

All 3 migrations applied cleanly. Status check confirmed:
```text
3 migrations found in prisma/migrations
Database schema is up to date!
```
Post-migration integration tests confirmed that:
- `TaskProgressOperation` unique constraint `(userId, taskId, operationId)` prevents duplicate progress updates.
- `Task.actualMinutes` and `Task.remainingMinutes` support decoupled workload tracking without data loss.
- 15 test suites and 167 tests passed against the migrated database.

### Remote Database Safety
- **Production Supabase DB**: No migrations have been executed against production. Production remains isolated and protected.
- **Safety Throw in Test Harness**: `server/test/global-setup.js` enforces that automated test suites throw an error if `DATABASE_URL` does not point to `localhost` or `127.0.0.1`.

---

## 5. Live Staging Probe Evidence & Failure Demonstration

To verify whether the cloud staging endpoint was live, real network requests were executed from the local environment:

### Probe A: DNS Resolution Check
Command: `Resolve-DnsName equilibrium-api-staging.onrender.com`
```text
Name                           Type   TTL   Section    NameHost
----                           ----   ---   -------    --------
equilibrium-api-staging.onrend CNAME  300   Answer     gcp-us-west1-1.origin.onrender.com
er.com
```
*Finding*: Render maintains a wildcard CNAME for `*.onrender.com`. DNS resolves to Render's Cloudflare edge proxy, but the backend container does not exist.

### Probe B: HTTP Health Endpoint Probe
Command: `Invoke-RestMethod -Uri "https://equilibrium-api-staging.onrender.com/api/v1/health"`
```text
The remote server returned an error: (404) Not Found.
Body: "NotFound"
```
*Finding*: Render's reverse proxy responds with `HTTP 404 NotFound` because no web service named `equilibrium-api-staging` has been provisioned under any Render account.

### Probe C: Real Smoke-Test Harness Execution Against Live Target
Command:
```powershell
$env:STAGING_API_URL="https://equilibrium-api-staging.onrender.com/api/v1"
$env:STAGING_ALLOWED_HOST="equilibrium-api-staging.onrender.com"
$env:STAGING_TEST_EMAIL="staging_test_user@equilibrium.test"
$env:STAGING_TEST_PASSWORD="StagingPassword123!"
npm run smoke:staging
```

Execution Output:
```text
================================================================
        Equilibrium Staging Smoke-Test Harness (Phase 4A.1)     
================================================================
Target API URL:  https://equilibrium-api-staging.onrender.com/api/v1
Allowed Host:    equilibrium-api-staging.onrender.com
Test Account:    staging_test_user@equilibrium.test
Password:        Stag...123!
----------------------------------------------------------------

[✗] Step 01: API Health Check (1035ms) - FAIL -> HTTP 404

================================================================
                   SMOKE TEST EXECUTION SUMMARY                 
================================================================
Step | Name                               | Status  | Duration
-----+------------------------------------+---------+---------
   1 | API Health Check                   | FAIL    |  1035ms
-----+------------------------------------+---------+---------
TOTAL: 1 steps | PASSED: 0 | FAILED: 1 | BLOCKED: 0 | SKIPPED: 0 | TIME: 1035ms

FINAL RESULT: FAILED - Staging smoke-test sequence encountered failures.
```

**Real Result**: The smoke test harness executed, verified safety gates, attempted to contact the real remote service, caught the HTTP 404, aborted without making mutating requests, and exited with code 1. **No test results were invented.**

---

## 6. Local Rehearsal Evidence (Port 3999 + Isolated PostgreSQL)

Command: `npx tsx scripts/test-staging-smoke-local.ts`  
Exit Code: `0` (Success)  
Execution Time: 557ms  

```text
================================================================
        Equilibrium Staging Smoke-Test Harness (Phase 4A.1)     
================================================================
Target API URL:  http://localhost:3999/api/v1
Allowed Host:    [LOCALHOST PERMITTED]
Test Account:    smoke_test_student@equilibrium.test
Password:        Smok...123!
----------------------------------------------------------------

[✓] Step 01: API Health Check (83ms) - PASS -> status=ok
[✓] Step 02: Authenticate Test Account (Registered) (249ms) - PASS -> Created test user: 2b607081-c40c-4bef-9e36-78a037742deb
[✓] Step 03: Verify Authorization Boundary (10ms) - PASS -> Authenticated as smoke_test_student@equilibrium.test
[✓] Step 04: Create Identifiable Test Task (16ms) - PASS -> taskId=c3d0c1c8-ec4a-481d-9501-eb31297c8ba4
[✓] Step 05: Fetch Task & Verify Fields (8ms) - PASS -> Estimate=90m, Completed=0m, Status=PENDING
[✓] Step 06: Schedule-Fit Simulation (25ms) - PASS -> fits=true, decisionType=FULLY_SCHEDULED
[✓] Step 07: Generate Schedule Version (33ms) - PASS -> versionId=e4e7f967-d687-45a6-a47e-5baa26a21d4a, blocks=1
[✓] Step 08: Verify Scheduled Blocks (8ms) - PASS -> Found 1 scheduled chunks for test task
[✓] Step 09: Submit Progress Update (operationId) (15ms) - PASS -> actual=30m, remaining=60m, op=e447...2fb1
[✓] Step 10: Idempotent Retry Verification (6ms) - PASS -> Replayed original response without double-counting effort
[✓] Step 11: Verify Decoupled Workload Semantics (5ms) - PASS -> Actual=30m, Remaining=60m, Status=IN_PROGRESS confirmed in DB
[✓] Step 12: Cross-User Isolation (IDOR Defense) (86ms) - PASS -> User B received HTTP 404 attempting to access User A task
[✓] Step 13: Verify Sleep Shield Protection (5ms) - PASS -> Active Sleep Shield: 23:00 -> 06:00
[✓] Step 14: Scoped Test Task Cleanup (8ms) - PASS -> Successfully deleted test task: c3d0c1c8-ec4a-481d-9501-eb31297c8ba4

================================================================
                   SMOKE TEST EXECUTION SUMMARY                 
================================================================
Step | Name                               | Status  | Duration
-----+------------------------------------+---------+---------
   1 | API Health Check                   | PASS    |    83ms
   2 | Authenticate Test Account (Registered) | PASS    |   249ms
   3 | Verify Authorization Boundary      | PASS    |    10ms
   4 | Create Identifiable Test Task      | PASS    |    16ms
   5 | Fetch Task & Verify Fields         | PASS    |     8ms
   6 | Schedule-Fit Simulation            | PASS    |    25ms
   7 | Generate Schedule Version          | PASS    |    33ms
   8 | Verify Scheduled Blocks            | PASS    |     8ms
   9 | Submit Progress Update (operationId) | PASS    |    15ms
  10 | Idempotent Retry Verification      | PASS    |     6ms
  11 | Verify Decoupled Workload Semantics | PASS    |     5ms
  12 | Cross-User Isolation (IDOR Defense) | PASS    |    86ms
  13 | Verify Sleep Shield Protection     | PASS    |     5ms
  14 | Scoped Test Task Cleanup           | PASS    |     8ms
-----+------------------------------------+---------+---------
TOTAL: 14 steps | PASSED: 14 | FAILED: 0 | BLOCKED: 0 | SKIPPED: 0 | TIME: 557ms

FINAL RESULT: PASSED - All staging readiness requirements verified.
```

---

## 7. Step-by-Step Operator Instructions to Provision Hosted Staging

To unblock live cloud execution without incurring costs or touching production:

### Step 1: Open Render Dashboard
1. Log into [dashboard.render.com](https://dashboard.render.com).
2. Click **New +** and select **Blueprint**.
3. Connect the repository `shreeK05/Equilibrium`.

### Step 2: Configure Blueprint Path
1. In the Blueprint configuration screen, change the Blueprint Path from `render.yaml` to:
   ```text
   render.staging.yaml
   ```
2. Click **Apply Blueprint**.
3. *Note on 1-Free-DB Limit*: If your workspace already has `equilibrium-db`, Render will inform you that only one free database is allowed per workspace.
   - *Resolution*: Either create a dedicated free Staging Workspace in Render, or create a free project on Supabase, obtain its pooled connection string, and set `DATABASE_URL` in the Render staging service settings.

### Step 3: Note the Assigned Staging Hostname
Once Render completes building and deploying, it will display the service URL (e.g., `https://equilibrium-api-staging-xxxx.onrender.com`).
Extract the exact hostname (e.g., `equilibrium-api-staging-xxxx.onrender.com`).

### Step 4: Configure GitHub Actions Secrets
In the GitHub repository (`shreeK05/Equilibrium`):
1. Navigate to **Settings** > **Secrets and variables** > **Actions**.
2. Add the repository secret:
   - `STAGING_TEST_PASSWORD`: A secure password (minimum 8 characters).
   - `STAGING_TEST_EMAIL` (Optional): e.g. `staging_test_student@equilibrium.test`.

### Step 5: Trigger the Hosted Staging Smoke Test
1. Go to **Actions** > **Staging Smoke Test**.
2. Click **Run workflow**.
3. Input:
   - `staging_url`: `https://equilibrium-api-staging-xxxx.onrender.com/api/v1`
   - `staging_allowed_host`: `equilibrium-api-staging-xxxx.onrender.com`
4. Run the workflow. Observe all 14 steps pass.

---

## 8. Remaining Blockers & Next Actions

1. **Operator Blueprint Deployment (`BLOCKED`)**:
   - Deployment of `render.staging.yaml` requires manual login and authorization in the Render dashboard by the repository owner.
2. **Cloud Smoke-Test Execution (`BLOCKED`)**:
   - Execution against a live remote endpoint is blocked until Step 1 provisions the service.
3. **Production Database Migrations (`INTENTIONALLY WITHHELD`)**:
   - Production migrations `20261024143000` and `20261024150000` remain withheld until hosted cloud staging verification is complete.
4. **Public Launch (`NOT READY`)**:
   - Equilibrium is not ready for public launch. Phase 4C student pilot validation is the next sequential milestone.
