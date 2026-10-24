# Equilibrium — Phase 4B.1: Finalize Supabase-Backed Staging Configuration

**Document Status:** Complete & Verified  
**Date:** October 24, 2026  
**Target Environment:** Isolated Free Staging (Render Web Service + Supabase Free PostgreSQL)  
**Safety Classification:** Strictly Guarded | No Cloud Resources Provisioned | No Production Mutation | Zero Cost ($0.00)  

---

## 1. Executive Summary & Objective

In Phase 4B, the pre-deployment review verified that `render.staging.yaml` parsed cleanly locally, but confirmed that **remote provider validation had not occurred** and **the staging service had not been provisioned**. Crucially, the review identified that Render enforces a strict quota of **one free-tier PostgreSQL database per workspace**, and that free Render databases are subject to an automatic 30-day deletion lifecycle.

To ensure an operational staging environment without incurring costs or attempting to provision a second Render-managed database, **Phase 4B.1 finalizes an isolated staging architecture backed by an external Supabase Free PostgreSQL project**.

### Core Tenets of this Configuration
1. **Preserve Production:** Production `render.yaml`, production databases (`cazlrtmmsikikexmepoc`), and all existing working-tree modifications are preserved untouched.
2. **Decoupled Database Provisioning:** Render no longer manages the staging database. `render.staging.yaml` defines solely the `equilibrium-api-staging` web service.
3. **Strict Credential Hygiene (`sync: false`):** `DATABASE_URL` is configured with `sync: false` in the Blueprint, requiring manual entry via the Render Dashboard. Zero credentials, connection strings, or project passwords exist in Git.
4. **Prisma & Supabase Pooling Compatibility:** The Supabase **Session Pooler (Port 5432)** is formally required and documented for Prisma migrations (`prisma migrate deploy`). The **Transaction Pooler (Port 6543)** is explicitly warned against due to PostgreSQL advisory lock incompatibility.
5. **Fail-Closed Preflight Protection:** A boot-time safety script (`server/scripts/prestart-check.js`) runs prior to `prisma migrate deploy` and `node dist/server.js`, refusing execution if credentials point to the production database or if critical variables are missing, all while masking secrets in log output.
6. **Non-Assumption of Hosted Readiness:** Remote deployment and provisioning have not been triggered. The outcome of Phase 4B.1 is an auditable, verified configuration ready for the repository owner to provision manually.

---

## 2. Review of Prisma Schema & Migration Configuration

Before altering environment variables or designing pooler connection strings, the complete Prisma schema and migration pipeline were inspected.

### 2.1 Prisma Environment
- **Prisma Client Version:** `^5.22.0` (`server/package.json`)
- **Prisma CLI Version:** `^5.22.0` (`server/package.json`)
- **Datasource Engine:** PostgreSQL
  ```prisma
  datasource db {
    provider = "postgresql"
    url      = env("DATABASE_URL")
  }

  generator client {
    provider = "prisma-client-js"
  }
  ```

### 2.2 Complete Migration History
The repository maintains six sequential, immutable Prisma migrations:
1. `20260915171355_initial_baseline`: Core schema baseline (Users, UserConstraints, FixedCommitments, Tasks, ScheduleVersions, ScheduledBlocks, Disruptions, TeamShares, ImportJobs, NotificationPreferences, FocusSessions, Exams, Subjects).
2. `20260915171626_add_scheduled_minutes`: Adds `scheduledMinutes` tracking to Tasks.
3. `20260915181811_add_password_reset`: Adds `PasswordResetToken` table for secure reset flows.
4. `20261006090000_user_timezone_default_ist`: Enforces `Asia/Kolkata` default user timezone.
5. `20261024143000_add_task_actual_and_remaining_minutes`: Introduces Phase 2B/4A task progress fields (`actualMinutes`, `remainingMinutes`).
6. `20261024150000_add_task_progress_operation`: Introduces `TaskProgressOperation` table for idempotent progress logging and replay safety.

### 2.3 Migration Execution Flow
In `server/package.json`, the `"start"` script is defined as:
```json
"start": "node scripts/prestart-check.js && npx prisma migrate deploy && node dist/server.js"
```
When Render boots `equilibrium-api-staging`, execution follows this deterministic pipeline:
1. `node scripts/prestart-check.js`: Evaluates database URL format, validates protocol, blocks production DB references, warns against port 6543, and validates `JWT_SECRET`. Exits `1` if any check fails.
2. `npx prisma migrate deploy`: Acquires database advisory lock, checks `_prisma_migrations` table, applies any pending migrations in chronological order, and releases the lock.
3. `node dist/server.js`: Starts the Express HTTP application on `0.0.0.0:${PORT}`.

---

## 3. Supabase Pooler Requirements for Prisma Migrations

Connecting Prisma to a hosted Supabase PostgreSQL instance requires strict attention to connection pooling modes and advisory locks.

### 3.1 The Advisory Lock Problem (Why Transaction Pooler Fails)
- **Mechanism:** During `prisma migrate deploy`, Prisma CLI executes `pg_advisory_lock` (or `pg_advisory_xact_lock`) to serialize schema alterations across potential multiple deploying containers.
- **Transaction Pooler (Port 6543):**
  - Supabase's transaction pooler (powered by Supavisor) assigns a server-side PostgreSQL connection only for the lifespan of a single transaction.
  - When statements complete, the connection is returned to the pool. Session-level state (including session-level advisory locks, prepared statements, and temporary variables) is reset or discarded.
  - Consequently, Prisma cannot maintain its advisory migration lock across connection handoffs. On port 6543, `prisma migrate deploy` will either fail immediately with an advisory lock error or hang indefinitely waiting for a lock release that never arrives.
- **Direct Connection (`db.[project-ref].supabase.co:5432`):**
  - Bypasses the pooler and connects directly to the underlying PostgreSQL instance.
  - **The IPv4 / IPv6 Trap on Free Tier:** Due to AWS IPv4 address fees, Supabase Direct Connection endpoints resolve exclusively to IPv6 addresses on free-tier projects. Standard Render Free web services run within an IPv4-only network environment and cannot resolve or reach IPv6-only hosts, causing connection timeouts or `getaddrinfo ENOTFOUND` errors.

### 3.2 The Solution: Supabase Session Pooler (Port 5432)
- **Endpoint Structure:**
  ```text
  postgresql://postgres.[project-ref]:[DB_PASSWORD]@aws-0-[region].pooler.supabase.com:5432/postgres
  ```
- **Why Session Pooler Works:**
  1. **Session Persistence:** Allocates a dedicated server connection for the duration of the client connection session.
  2. **Advisory Lock Support:** Because the session persists, PostgreSQL session-level advisory locks (`pg_advisory_lock`) function normally, allowing `prisma migrate deploy` to acquire, execute, and release locks without errors or deadlocks.
  3. **IPv4 Compatibility:** The Supabase pooler domains (`aws-0-[region].pooler.supabase.com`) provide dual-stack / IPv4 routing compatible with Render's free container network.

### 3.3 Connection String Parameter Recommendations
When specifying the staging `DATABASE_URL` in the Render Dashboard, format the URL as follows:
```text
postgresql://postgres.[staging-project-ref]:[DB_PASSWORD]@aws-0-[region].pooler.supabase.com:5432/postgres?connection_limit=5
```
- Port: **5432** (Session Mode).
- Parameter `connection_limit=5`: Constrains Prisma Client connection pool to stay well within Supabase Free tier pooler limits (typically 20-30 pooler slots) while leaving room for manual psql inspection or test runner queries.

---

## 4. Render Staging Blueprint Specification (`render.staging.yaml`)

The Blueprint configuration has been updated to remove all Render-managed database definitions and establish `DATABASE_URL` as an unsynced dashboard secret.

### 4.1 Updated `render.staging.yaml`
```yaml
# Render Blueprint Specification for Equilibrium Staging Environment
# This configuration provisions an isolated, free-tier staging API service
# backed by an external isolated PostgreSQL staging database (e.g., Supabase Free Project).
# It does NOT provision a Render-managed database and does NOT touch production.

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
        sync: false
      - key: JWT_SECRET
        generateValue: true
      - key: ALLOWED_ORIGINS
        value: '*'
      - key: APP_PUBLIC_URL
        sync: false
```

### 4.2 Key Blueprint Decisions & Safety Controls
| Field | Value | Rationale |
|---|---|---|
| `name` | `equilibrium-api-staging` | Distinct from production service (`equilibrium-api`). Guaranteed no namespace collision. |
| `plan` | `free` | Enforces zero cost ($0.00). Complies with free-tier rules. |
| `DATABASE_URL: sync: false` | Render Dashboard secret | Prevents storing connection strings or passwords in Git. Relies on isolated external Supabase staging database. |
| `JWT_SECRET: generateValue: true` | Auto-generated by Render | Generates a cryptographically strong 256-bit secret (32+ chars), satisfying production security checks. |
| `APP_PUBLIC_URL: sync: false` | Optional dashboard override | Allows explicit hostname override; if omitted, automatically falls back to `RENDER_EXTERNAL_URL`. |
| `databases:` section | **REMOVED** | Eliminates attempt to create a second Render database, bypassing Render's 1-free-database workspace ceiling. |

### 4.3 Blueprint Schema Validation Status
- **Local Parsing Validation:** Validated via Node.js YAML parser (`js-yaml`). Successfully parsed with 0 syntax errors.
- **Remote Provider Validation:** **NOT VALIDATED BY RENDER.** Official Render CLI or remote validation API tokens are not available in this local environment. The configuration adheres strictly to the official Render Blueprint specification (`render.yaml` spec for Node.js Web Services).

---

## 5. Hostname Resolution, CORS, and URL-Dependent Configuration

### 5.1 Dynamic `appPublicUrl` Resolution
In `server/src/config.ts`, `appPublicUrl` was inspected and updated to prevent silent fallbacks to the hardcoded production domain:
```typescript
export const config = {
  jwtSecret,
  port: Number(process.env.PORT || 3000),
  resendApiKey: process.env.RESEND_API_KEY || 're_test',
  emailFrom: process.env.EMAIL_FROM || 'noreply@equilibrium.local',
  appPublicUrl: process.env.APP_PUBLIC_URL || process.env.RENDER_EXTERNAL_URL || 'https://equilibrium-42g8.onrender.com'
};
```
- **Behavior on Render:** Render automatically provisions the service domain (e.g., `https://equilibrium-api-staging.onrender.com`) and injects it as `RENDER_EXTERNAL_URL`.
- **Precedence:**
  1. `process.env.APP_PUBLIC_URL` (if manually set in Render Dashboard).
  2. `process.env.RENDER_EXTERNAL_URL` (automatically provided by Render).
  3. Hardcoded fallback (only used if running outside Render and without explicit environment variable).
- **Consumer:** Password reset redirect links (`server/src/services/auth.service.ts`: `resetLink = ${config.appPublicUrl}/api/v1/auth/reset-redirect?token=${token}`). Guarantees reset links point to the actual staging service rather than production.

### 5.2 CORS Configuration
In `server/src/app.ts`:
```typescript
const allowedOriginsString = process.env.ALLOWED_ORIGINS;
let corsOrigin: string | string[] = ['http://localhost:3000', 'http://localhost:8080'];
if (allowedOriginsString) {
  if (allowedOriginsString === '*' && process.env.NODE_ENV === 'production') {
    console.warn('ALLOWED_ORIGINS=* is permissive in production; configure explicit browser origins in Render.');
  }
  corsOrigin = allowedOriginsString === '*' ? '*' : allowedOriginsString.split(',');
}
app.use(cors({ origin: corsOrigin }));
```
- `render.staging.yaml` provides `ALLOWED_ORIGINS: '*'`. For browser-based staging testing, this allows Flutter Web or local development clients to make cross-origin API calls against the staging API.
- If more restrictive CORS is desired later, `ALLOWED_ORIGINS` can be updated in the Render Dashboard to specific browser URLs (e.g., `https://staging.equilibrium.app,http://localhost:8080`).

---

## 6. Pre-Start Safety Check (`server/scripts/prestart-check.js`)

To prevent accidental production database mutation, misconfiguration, or silent failures, a preflight check executes on container boot before `prisma migrate deploy`.

### 6.1 Guard Implementation
```javascript
#!/usr/bin/env node
const { URL } = require('url');

const KNOWN_PRODUCTION_DB_REFS = [
  'cazlrtmmsikikexmepoc'
];

function maskString(str) {
  if (!str) return '[EMPTY]';
  if (str.length <= 8) return '********';
  return str.substring(0, 4) + '...' + str.substring(str.length - 4);
}

function runPrestartCheck() {
  console.log('[prestart-check] Running preflight database and environment safety validation...');

  // 1. Verify DATABASE_URL
  const rawDbUrl = process.env.DATABASE_URL;
  if (!rawDbUrl || rawDbUrl.trim() === '') {
    console.error('[prestart-check] FATAL: DATABASE_URL environment variable is not defined.');
    console.error('[prestart-check] Please configure DATABASE_URL in your hosting environment settings.');
    process.exit(1);
  }

  let dbUrl;
  try {
    dbUrl = new URL(rawDbUrl.trim());
  } catch (err) {
    console.error(`[prestart-check] FATAL: Malformed DATABASE_URL: ${err.message}`);
    process.exit(1);
  }

  if (dbUrl.protocol !== 'postgres:' && dbUrl.protocol !== 'postgresql:') {
    console.error(`[prestart-check] FATAL: Invalid database protocol "${dbUrl.protocol}". Must be postgres: or postgresql:`);
    process.exit(1);
  }

  const host = (dbUrl.hostname || '').toLowerCase();
  const port = dbUrl.port || (dbUrl.protocol === 'https:' ? '443' : '5432');
  const dbName = dbUrl.pathname || '/';

  // 2. Production Database Collision Guard
  const serviceName = (process.env.RENDER_SERVICE_NAME || process.env.SERVICE_NAME || '').toLowerCase();
  const isStagingService = serviceName.includes('staging') || process.env.NODE_ENV === 'staging';

  for (const prodRef of KNOWN_PRODUCTION_DB_REFS) {
    if (host.includes(prodRef) || (dbUrl.username && dbUrl.username.includes(prodRef))) {
      if (isStagingService) {
        console.error('[prestart-check] CRITICAL SAFETY BLOCK: Staging service detected, but DATABASE_URL points to the known production database project reference.');
        console.error('[prestart-check] Refusing to apply migrations or start staging service to protect production data.');
        process.exit(1);
      }
    }
  }

  // 3. Supabase Pooler Port Advisory Check
  if (host.includes('pooler.supabase.com') && port === '6543') {
    console.warn('[prestart-check] NOTICE: DATABASE_URL is configured on port 6543 (Transaction Pooler).');
    console.warn('[prestart-check] If Prisma migrations hang on advisory locks, switch connection string to port 5432 (Session Pooler).');
  }

  // Sanitized logging (No credentials or query params)
  console.log(`[prestart-check] Database Target: host=${host}, port=${port}, database=${dbName}`);

  // 4. Verify JWT_SECRET
  const isProduction = process.env.NODE_ENV === 'production';
  const jwtSecret = process.env.JWT_SECRET || '';

  if (isProduction && jwtSecret.length < 32) {
    console.error('[prestart-check] FATAL: JWT_SECRET must be set to at least 32 characters in production.');
    console.error(`[prestart-check] Current length: ${jwtSecret.length} characters.`);
    process.exit(1);
  }

  console.log(`[prestart-check] JWT_SECRET: ${jwtSecret ? 'CONFIGURED (' + maskString(jwtSecret) + ')' : '[EMPTY]'}`);
  console.log('[prestart-check] Preflight database and environment checks PASSED.');
}

runPrestartCheck();
```

### 6.2 Pre-Start Check Validation Evidence
1. **Missing `DATABASE_URL` Test:** Exited with code `1` and printed `FATAL: DATABASE_URL environment variable is not defined.`
2. **Malformed URL Test:** Exited with code `1` and printed `FATAL: Malformed DATABASE_URL: ...`
3. **Production Database Collision Test:** Tested with `RENDER_SERVICE_NAME=equilibrium-api-staging` and a pooler URL containing `cazlrtmmsikikexmepoc`. Exited immediately with code `1` and printed:
   `CRITICAL SAFETY BLOCK: Staging service detected, but DATABASE_URL points to the known production database project reference.`
4. **Port 6543 Warning Test:** Tested with `port: 6543`. Emitted descriptive advisory notice advising port 5432.
5. **Short JWT Secret Test:** Exited with code `1` when `JWT_SECRET` length < 32 in production.
6. **Valid Configuration Test:** Logged sanitized parameters (`host=aws-0-ap-south-1.pooler.supabase.com, port=5432, database=/postgres`), masked secret (`JWT_SECRET: CONFIGURED (prod...8901)`), and exited `0`.

---

## 7. Environment Variable Classification & Secrets Audit

All environment variables consumed by the staging runtime, smoke-test harness, and CI workflow have been cataloged and classified.

### 7.1 Web Service Runtime Variables (`server`)
| Variable | Classification | Location | Default / Injection | Purpose |
|---|---|---|---|---|
| `NODE_ENV` | Non-Secret | `render.staging.yaml` | `production` | Enables production optimizations and strict JWT length checking. |
| `DATABASE_URL` | **SECRET** | Render Dashboard (`sync: false`) | **None** (Operator must provide) | PostgreSQL connection string to isolated Supabase staging database. |
| `JWT_SECRET` | **SECRET** | Render Blueprint (`generateValue: true`) | Render auto-generates | 256-bit secret for signing user authentication tokens. |
| `ALLOWED_ORIGINS` | Non-Secret | `render.staging.yaml` | `*` | CORS origin policy for client applications. |
| `APP_PUBLIC_URL` | Non-Secret / Config | Render Dashboard (`sync: false`) | Falls back to `RENDER_EXTERNAL_URL` | Base public URL for password reset redirect links. |
| `PORT` | Non-Secret | Render Platform | Auto-injected (typically 10000) | Express HTTP listen port. |

### 7.2 Staging Smoke-Test Script (`server/scripts/staging-smoke-test.ts`)
| Variable | Classification | Source | Format / Constraints | Purpose |
|---|---|---|---|---|
| `STAGING_API_URL` | Non-Secret | GitHub Workflow Input / CLI | Absolute URL (e.g., `https://equilibrium-api-staging.onrender.com/api/v1`) | Base endpoint of staging API under test. |
| `STAGING_ALLOWED_HOST` | Non-Secret | GitHub Workflow Input / CLI | Hostname string (e.g., `equilibrium-api-staging.onrender.com`) | Fail-closed allowlist hostname pinning. |
| `ALLOW_LOCALHOST` | Non-Secret | CLI / Defaults to `false` | Boolean string (`true` / `false`) | Permits localhost testing exclusively during offline rehearsals. Must be `false` for staging. |
| `STAGING_TEST_EMAIL` | Non-Secret / Config | GitHub Input or Secret | Valid email format (e.g., `staging-smoke-runner@equilibrium.app`) | Dedicated staging test account username. |
| `STAGING_TEST_PASSWORD` | **SECRET** | GitHub Secret / Local env | Minimum 8 characters | Dedicated test account password. Auto-registers if user does not exist. |
| `STAGING_TEST_PASSWORD_B`| **SECRET** (Optional) | Local env / Defaults to `STAGING_TEST_PASSWORD` | Minimum 8 characters | Password for secondary test user in multi-user test suites. |

### 7.3 GitHub Actions Workflow (`.github/workflows/staging-smoke.yml`)
| Parameter / Secret | Type | Source | Required | Purpose |
|---|---|---|---|---|
| `inputs.staging_url` | Workflow Input | Operator input at dispatch | **Yes** | Target API URL. |
| `inputs.staging_allowed_host`| Workflow Input | Operator input at dispatch | **Yes** | Hostname allowlist match. |
| `inputs.test_email` | Workflow Input | Operator input at dispatch | No | Overrides `secrets.STAGING_TEST_EMAIL` if specified. |
| `secrets.STAGING_TEST_PASSWORD` | Repository Secret | GitHub Actions Secrets | **Yes** | Primary auth credential for smoke-test suite. |
| `secrets.STAGING_TEST_EMAIL` | Repository Secret | GitHub Actions Secrets | No (if input given) | Fallback test email. |

### 7.4 Dedicated Staging Test Account Creation Policy
- **Automatic Idempotent Registration:**
  In `server/scripts/staging-smoke-test.ts` (lines 198–223):
  1. The test runner attempts `POST /api/v1/auth/login` with `STAGING_TEST_EMAIL` and `STAGING_TEST_PASSWORD`.
  2. If the user does not exist (`401` or `404 USER_NOT_FOUND`), the script automatically calls `POST /api/v1/auth/register` with `{ email, password, timezone: 'Asia/Kolkata' }`.
  3. This ensures that on a freshly migrated, completely empty staging database, the dedicated test user is automatically created on first run without requiring manual database seeding or SQL insertion.
- **No Committed Passwords:** No default passwords, hardcoded credentials, or reusable example passwords exist in code or Git.

---

## 8. Safety Guarantees & Gate Protections

The safety harness established in Phase 4A and 4A.1 remains strictly preserved:

1. **Target Allowlist Enforcement:** `validateStagingTarget()` parses the target URL, extracts the hostname, and requires an exact case-insensitive match against `STAGING_ALLOWED_HOST`.
2. **Production Blacklist Guard:** Target validation rejects any URL matching known production domains (`equilibrium-42g8.onrender.com`, `equilibrium.app`, `cazlrtmmsikikexmepoc.supabase.co`).
3. **Localhost Isolation:** Requests to `localhost`, `127.0.0.1`, `::1`, or `.local` are rejected unless `ALLOW_LOCALHOST=true` is explicitly provided.
4. **Redirect Protection:** The custom HTTP requester (`createSecureRequester()`) intercepts HTTP 301, 302, 307, and 308 redirects. It validates the redirect `Location` header against the approved origin before sending headers or credentials, preventing credential leakage to malicious origins.
5. **Strict Nonzero Exit Codes:**
   - Exit Code `0`: All 14 smoke test steps passed completely.
   - Exit Code `1`: Any assertion failure, unhandled exception, or failed task cleanup.
   - Exit Code `2`: Blocked by safety gates (allowlist mismatch, missing credentials, production target attempt).

---

## 9. Verification & Test Evidence

All components of the application, server, and test harness have been thoroughly tested locally:

### 9.1 Backend Test Suite (`server`)
```text
Test Suites: 8 passed, 8 total
Tests:       98 passed, 98 total
Snapshots:   0 total
Time:        4.846 s
Ran all test suites.
Exit code: 0
```
- Includes regression suites: `v3.regression.test.ts`, `regression.deadline-feasibility.test.ts`, `regression.insights-sleep-capacity.test.ts`, `regression.task-progress-reschedule.test.ts`, `regression.secrets-hygiene.test.ts`, `auth.test.ts`, and `staging-target-validator.test.ts`.

### 9.2 TypeScript Compilation Check (`server`)
```text
npx tsc --noEmit
Exit code: 0 (Zero errors)
```

### 9.3 Staging Target Validator Unit Suite
```text
Test Suites: 1 passed, 1 total
Tests:       10 passed, 10 total
Time:        5.932 s
Exit code: 0
```
Validates fail-closed allowlists, redirect interception, localhost gating, and production blocking.

### 9.4 Smoke Test Harness Local End-to-End Rehearsal
Executed `test-staging-smoke-local.ts` (exercises local ephemeral server on port 3099):
```text
Step 01: API Health Check (18ms) - PASS
Step 02: Authenticate Test Account (Registered) (138ms) - PASS
Step 03: Verify Authorization Boundary (26ms) - PASS
Step 04: Create Test Task (33ms) - PASS
Step 05: Fetch Task Detail (17ms) - PASS
Step 06: Trigger Schedule Engine (49ms) - PASS
Step 07: Inspect Schedule Output (23ms) - PASS
Step 08: Post Task Progress & Idempotency (32ms) - PASS
Step 09: Duplicate Idempotency Replay (17ms) - PASS
Step 10: Trigger Adaptive Reschedule (46ms) - PASS
Step 11: Create Focus Session (22ms) - PASS
Step 12: Verify User Workload Insights (26ms) - PASS
Step 13: Clean Up Test Task (37ms) - PASS
Step 14: Verify Task Deletion (19ms) - PASS

TOTAL: 14 steps | PASSED: 14 | FAILED: 0 | BLOCKED: 0 | SKIPPED: 0 | TIME: 512ms
FINAL RESULT: PASSED - All staging readiness requirements verified.
Exit code: 0
```

### 9.5 Flutter Application Quality Gates (`equilibrium_app`)
- **Unit & Widget Tests:**
  ```text
  flutter test
  00:19 +87: All tests passed!
  Exit code: 0
  ```
- **Static Analysis:**
  ```text
  flutter analyze --fatal-infos --fatal-warnings
  Analyzing equilibrium_app...
  No issues found! (ran in 9.1s)
  Exit code: 0
  ```

---

## 10. Manual Operator Dashboard Runbook (Remaining Human Steps)

Because the agent cannot create external cloud accounts, log in to third-party dashboards, or provision resources, the repository owner must execute the following actions in their browser:

### Step 1: Create Isolated Supabase Staging Project
1. Log in to [Supabase Dashboard](https://supabase.com/dashboard).
2. Click **New Project**.
3. Choose an organization and specify:
   - **Name:** `equilibrium-staging-db`
   - **Database Password:** Generate a secure, high-entropy password and save it in a password manager.
   - **Region:** Choose a region close to your Render deployment (e.g., `ap-south-1` or `us-east-1`).
   - **Pricing Plan:** Free ($0.00).
4. Click **Create new project** and wait ~2 minutes for PostgreSQL provisioning to complete.

### Step 2: Retrieve Supabase Session Pooler Connection String
1. In the Supabase project dashboard, navigate to **Project Settings** > **Database**.
2. Scroll to the **Connection Pooling** (Supavisor) section.
3. Select:
   - **Mode:** `Session` (Port **5432**) — **DO NOT SELECT TRANSACTION (6543)**.
   - **Connection String:** URI format.
4. The connection string will look like:
   `postgresql://postgres.[project-ref]:[YOUR-PASSWORD]@aws-0-[region].pooler.supabase.com:5432/postgres`
5. Replace `[YOUR-PASSWORD]` with your actual database password.

### Step 3: Deploy Blueprint on Render
1. Log in to [Render Dashboard](https://dashboard.render.com).
2. Click **New +** > **Blueprint**.
3. Connect your GitHub repository (`shreeK05/Equilibrium`).
4. Select the branch and set **Blueprint Path** to: `render.staging.yaml`.
5. Render will detect the service `equilibrium-api-staging` and show that `DATABASE_URL` is required (`sync: false`).
6. Paste the **Supabase Session Pooler Connection String** into the `DATABASE_URL` input field.
7. Click **Apply**.
8. Render will trigger the initial build (`npm ci && node scripts/use-pg-schema.js && npm run build`) and start the service.

### Step 4: Verify Deployment Logs in Render
1. Open the deployment logs for `equilibrium-api-staging`.
2. Verify the prestart check output:
   ```text
   [prestart-check] Running preflight database and environment safety validation...
   [prestart-check] Database Target: host=aws-0-..., port=5432, database=/postgres
   [prestart-check] JWT_SECRET: CONFIGURED (...)
   [prestart-check] Preflight database and environment checks PASSED.
   ```
3. Verify Prisma migration execution:
   ```text
   Prisma schema loaded from prisma/schema.prisma
   Datasource "db": PostgreSQL database "postgres", schema "public"
   Applying migration `20260915171355_initial_baseline`
   ...
   Applying migration `20261024150000_add_task_progress_operation`
   All migrations have been successfully applied.
   ```
4. Verify HTTP listener boot:
   ```text
   Server listening on port 10000
   ```
5. Copy the assigned staging URL: `https://equilibrium-api-staging.onrender.com`.

### Step 5: Configure GitHub Secrets & Run Staging Smoke Test
1. In the GitHub repository, navigate to **Settings** > **Secrets and variables** > **Actions**.
2. Create repository secret:
   - `STAGING_TEST_PASSWORD`: A dedicated password for the test account (at least 8 characters).
   - `STAGING_TEST_EMAIL` (Optional): A dedicated email such as `staging-runner@equilibrium.app`.
3. Navigate to **Actions** > **Staging Smoke Test** workflow.
4. Click **Run workflow**:
   - `staging_url`: `https://equilibrium-api-staging.onrender.com/api/v1`
   - `staging_allowed_host`: `equilibrium-api-staging.onrender.com`
   - `test_email`: (Leave blank to use default or secret)
5. Review workflow execution. All 14 steps should pass green.

---

## 11. Staging Readiness & Verification Matrix

| Component | Status | Verification Detail |
|---|---|---|
| **Production Blueprint (`render.yaml`)** | **VERIFIED** | Untouched, identical to main, production database reference preserved. |
| **Staging Blueprint (`render.staging.yaml`)** | **PARTIALLY VERIFIED** | Validated via `js-yaml` locally; Render remote validation pending operator dashboard apply. |
| **Prisma 5.22.0 Migration Compatibility** | **VERIFIED** | Verified with PostgreSQL engine; Session Pooler (5432) documented for advisory lock safety. |
| **Pre-Start Safety Check (`prestart-check.js`)** | **VERIFIED** | Verified against missing URLs, malformed URLs, production DB collision, and short secrets. |
| **Hostname Resolution (`config.ts`)** | **VERIFIED** | Updated to resolve `RENDER_EXTERNAL_URL` dynamically; password reset links resolve to staging. |
| **Staging Smoke-Test Target Validator** | **VERIFIED** | 10/10 Jest unit tests passed; redirect protection and fail-closed allowlists verified. |
| **Local Smoke-Test Rehearsal** | **VERIFIED** | 14/14 steps passed in 512ms against isolated local Express server. |
| **Backend Test Suite & Typecheck** | **VERIFIED** | 98/98 unit/regression tests passed; `tsc --noEmit` passed with 0 errors. |
| **Flutter Test Suite & Analysis** | **VERIFIED** | 87/87 tests passed; `flutter analyze --fatal-infos --fatal-warnings` passed with 0 issues. |
| **Hosted Staging Deployment** | **NOT TESTED / BLOCKED** | Awaiting manual operator provisioning in Supabase and Render Dashboards. |

---

## 12. Conclusion

Phase 4B.1 resolves the Render workspace database limitation safely and elegantly by shifting staging persistence to an isolated, free Supabase project.

All application code, configuration scripts, safety checks, and test harnesses are in place, verified, and ready. Zero credentials are committed to Git, production is completely isolated from staging, and the repository owner has an actionable runbook to provision staging at zero cost ($0.00).
