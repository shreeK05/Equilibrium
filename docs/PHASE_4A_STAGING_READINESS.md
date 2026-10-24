# Phase 4A: Staging Readiness & Real API Integration Report

**Project:** Equilibrium — Student Workload, Focus & Sleep Balancing System  
**Phase:** 4A (Staging Readiness & Real API Integration)  
**Date:** 2026-10-24  
**Author:** Antigravity Agentic Pair Programmer  
**Status:** COMPLETE (Staging Harness Verified, Local Rehearsal Passed, Cloud Staging Prerequisites Documented)

---

## 1. Executive Summary & Readiness Matrix

Phase 4A transitions Equilibrium from isolated phase-by-phase development toward real end-to-end integration across the Flutter client, Node.js/Express API, Prisma/PostgreSQL persistence layer, and core scheduling engines.

In strict adherence to safety rules:
- **No production database** was migrated, wiped, or modified.
- **No secrets or production credentials** were logged, printed, or embedded in documentation.
- **No unverified test claims** were made: local rehearsal and deterministic tests are explicitly distinguished from pending live cloud staging runs.
- **Safety guards** were established to prevent test suites or smoke scripts from silently targeting production.

### Staging Readiness Matrix

| Area | Status | Evidence / Verification Method | Blocker / Next Action |
| :--- | :---: | :--- | :--- |
| **Backend Unit & Regression Suite** | `VERIFIED` | 8 test suites, 98/98 unit & regression tests passed (`npm test`). Type checks clean (`npx tsc --noEmit`). | None. Fully green. |
| **Database Migration Rehearsal** | `VERIFIED` | Rehearsed on isolated local PostgreSQL 17 test database (`equilibrium_test`). Applied 3 pending migrations via `prisma migrate deploy`. 14 test suites, 152 tests passed (`jest.config.js`). | Production database migrations withheld pending cloud staging sign-off. |
| **Database Safety Guards** | `VERIFIED` | `server/test/global-setup.js` blocks tests if `DATABASE_URL` is not `localhost`/`127.0.0.1`. Confirmed by deliberate negative test. | None. Safeguard operational. |
| **Flutter Test & Static Analysis** | `VERIFIED` | 87/87 tests passed (`flutter test`). 0 warnings/infos (`flutter analyze --fatal-infos --fatal-warnings`). | None. Fully green. |
| **Flutter Web Release Build** | `VERIFIED` | Compiled `build/web` via `flutter build web --release` (exit code 0). Tree-shaken icons. | None. Fully green. |
| **Staging Smoke-Test Harness** | `VERIFIED` | 14-step automated harness created (`server/scripts/staging-smoke-test.ts`). Executed locally against isolated server/database: 14/14 steps passed (476ms). | Requires hosted cloud staging target URL for remote staging run. |
| **Smoke-Test Safety Blocker** | `VERIFIED` | Exits with error code 2 if `STAGING_API_URL` is missing or points to production domains (`equilibrium-42g8.onrender.com` / `equilibrium.app`). | None. Production protection enforced. |
| **Flutter-to-API Integration Architecture** | `VERIFIED` | 7 dedicated integration tests passed (`phase_4a_api_integration_test.dart`): base URL resolution, 401 interceptor, error mapping, state synchronization, retry recovery. | Live round-trip against hosted cloud staging awaits staging environment provisioning. |
| **CI Repeatability & Staging Workflow** | `VERIFIED` | Inspected `.github/workflows/ci.yml`. Added on-demand `.github/workflows/staging-smoke.yml` (`workflow_dispatch` only). No embedded secrets. | Configure GitHub repo secrets `STAGING_API_URL` and `STAGING_TEST_PASSWORD`. |
| **Cloud-Hosted Staging Environment** | `BLOCKED` | `render.yaml` only specifies production service. No isolated staging web service or staging database is provisioned on cloud provider yet. | Infrastructure provisioning required on Render/Supabase. |
| **Production Launch Readiness** | `BLOCKED` | Staging readiness phase only. Production deployment must remain blocked until cloud staging smoke test passes. | Complete Phase 4B/4C validation prior to production rollout. |

---

## 2. Current Deployment & Environment Architecture

Equilibrium defines four distinct runtime tiers. Configuration is strictly environment-driven:

```mermaid
graph TD
    subgraph Tier1 [1. Local Development]
        DevFlutter[Flutter Client :5000] --> DevAPI[Node.js Express API :3000]
        DevAPI --> LocalPG[(PostgreSQL 17 :5432 / equilibrium_dev)]
    end

    subgraph Tier2 [2. Automated Test / Rehearsal]
        TestRunner[Jest & Flutter Test Runners] --> IsolatedPG[(PostgreSQL 17 :5432 / equilibrium_test)]
        TestSmoke[Smoke Harness :3999] --> EphemeralAPI[Ephemeral Express API]
        EphemeralAPI --> IsolatedPG
        TestRunner -.->|Blocked if Remote| GlobalGuard[global-setup.js Guard]
    end

    subgraph Tier3 [3. Cloud Staging - Target Architecture]
        StagingFlutter[Flutter Web / Mobile Staging Build] --> StagingAPI[Render Web Service: equilibrium-api-staging]
        StagingAPI --> StagingPG[(Isolated PostgreSQL: equilibrium-db-staging)]
        SmokeWorkflow[GitHub Actions: staging-smoke.yml] -->|workflow_dispatch| StagingAPI
    end

    subgraph Tier4 [4. Production - Protected]
        ProdUsers[Production Users] --> ProdAPI[Render Web Service: equilibrium-api]
        ProdAPI --> ProdPG[(Remote Supabase DB Pooler)]
        SafetyBlock[Smoke Harness Safety Guard] -.->|BLOCKS Execution| ProdAPI
    end
```

### Environment Separation Safeguards

1. **Local Development vs. Test**:
   - Development server runs on port 3000 targeting `equilibrium_dev`.
   - Tests and rehearsals target `equilibrium_test` on `localhost:5432`.
   - `server/test/global-setup.js` executes before all Jest suites. It inspects `process.env.DATABASE_URL` and immediately throws if it does not contain `localhost` or `127.0.0.1`.
2. **Automated Test vs. Staging**:
   - Automated tests run against mock clients or ephemeral local databases.
   - Staging smoke tests do not execute automatically on `git push` or pull requests to avoid calling external networks or generating runaway test data.
3. **Staging vs. Production**:
   - Production API: `https://equilibrium-42g8.onrender.com/api/v1`
   - Staging API: Must use dedicated subdomain (e.g., `https://staging-api.equilibrium.app/api/v1` or Render staging URL `https://equilibrium-staging.onrender.com/api/v1`).
   - The smoke test script inspects `STAGING_API_URL` against known production domains and throws a `CRITICAL SAFETY BLOCK` if production URLs are supplied without an explicit `STAGING_ALLOW_PROD_URL=true` bypass.

---

## 3. Configuration and Secrets-Preflight Findings

### `.gitignore` and Environment Files Audit
- **Root `.gitignore`**: Correctly includes `.env`, `.env.*.local`, `*.pem`, `*.log`, and OS artifacts.
- **`server/.gitignore`**: Correctly ignores `.env`, `dist/`, `node_modules/`, and coverage outputs.
- **`equilibrium_backend/.gitignore`**: Correctly ignores `.env`.
- **`server/.env.example`**: Inspected and verified to contain **only safe placeholders**:
  ```ini
  PORT=3000
  NODE_ENV=development
  DATABASE_URL="postgresql://user:password@localhost:5432/equilibrium_db?schema=public"
  JWT_SECRET="your-development-jwt-secret-min-32-chars-long"
  RESEND_API_KEY="re_dummy_resend_api_key_placeholder"
  ALLOWED_ORIGINS="http://localhost:3000,http://localhost:5000"
  ```
- **Automated Secrets Hygiene Test**: `server/test/regression.secrets-hygiene.test.ts` passed:
  - Scanned backend source files (`src/`, `prisma/`, `scripts/`) for hardcoded JWT secrets, private keys, database connection strings with live passwords, and Resend API tokens. Zero violations detected.

### Credential History and Rotation Status
- Documentation review: `docs/SECURITY_REMEDIATION.md` previously outlined sanitization steps for earlier commits.
- **Verification Rule**: Staging credentials must be distinct from production credentials. Staging JWT secrets, test passwords, and database connection strings must never be shared with production environments.

### Frontend Runtime Configuration
- The Flutter client avoids hardcoded backend URLs.
- URL resolution in `ApiClient` respects:
  1. `SharedPreferences` key `custom_api_base_url` (runtime override for test/staging devices).
  2. Compile-time environment definition: `--dart-define=API_BASE_URL=https://staging-api.equilibrium.app/api/v1`.
  3. Default fallback for local debugging (`http://localhost:3000/api/v1` or Android emulator `http://10.0.2.2:3000/api/v1`).
- Source code edits are never required to point Flutter builds to staging.

---

## 4. Safe Staging Smoke-Test Harness

The smoke test harness is implemented in `server/scripts/staging-smoke-test.ts`, accessible via `npm run smoke:staging`.

### Configuration Environment Variables

| Variable | Required | Default | Purpose / Safety Rule |
| :--- | :---: | :--- | :--- |
| `STAGING_API_URL` | **Yes** | *None* | Target API base URL (e.g. `http://localhost:3999/api/v1`). Script terminates with status `BLOCKED` (exit code 2) if unset. |
| `STAGING_TEST_EMAIL` | No | `smoke_test_student@equilibrium.test` | Dedicated staging test account. Will log in if existing, or register if new. |
| `STAGING_TEST_PASSWORD` | No | `SmokeTestPassword123!` | Test account password. Masked in console logs (`Smok...123!`). |
| `STAGING_ALLOW_PROD_URL` | No | `false` | Must be `true` to allow targeting `equilibrium-42g8.onrender.com` or `equilibrium.app`. Otherwise execution halts immediately. |

### 14-Step Smoke Test Execution Sequence

1. **API Health Check**: `GET /api/v1/health` verifies API status is 200 OK.
2. **Dedicated Test Account Authentication**: `POST /api/v1/auth/login` (with fallback to `POST /api/v1/auth/register`) obtains JWT token.
3. **Authorization Boundary Check**: `GET /api/v1/profile` confirms token matches the authenticated test account.
4. **Task Creation**: `POST /api/v1/tasks` creates a uniquely identifiable test task (`Phase 4A Smoke Task [timestamp]`, 90 min estimate, due in 48 hours).
5. **Task Retrieval & Field Verification**: `GET /api/v1/tasks/:id` validates `estimateMinutes=90`, `completedMinutes=0`, `status=PENDING`.
6. **Schedule-Fit Simulation**: `POST /api/v1/schedules/simulate` validates feasibility prediction without altering state.
7. **Schedule Generation**: `POST /api/v1/schedules/generate` runs schedule placement and creates a new schedule version.
8. **Scheduled Block Verification**: `GET /api/v1/schedules/current` verifies scheduled time blocks exist for the test task.
9. **Progress Submission (Unique Operation ID)**: `POST /api/v1/tasks/:id/progress` submits 30 min of progress with a UUID `operationId`.
10. **Idempotent Retry Safety**: Submits the exact same progress payload and `operationId` again; verifies the response is replayed without double-counting effort.
11. **Decoupled Workload Semantics**: Fetches task to verify `actualMinutes=30`, `remainingMinutes=60`, and `status=IN_PROGRESS`.
12. **Cross-User Isolation (IDOR Defense)**: Registers an ephemeral "User B" and attempts `GET /api/v1/tasks/:testTaskId`. Verifies HTTP 404 Not Found.
13. **Sleep Shield & Constraint Verification**: `GET /api/v1/constraints` verifies active Sleep Shield boundaries (23:00 to 06:00).
14. **Scoped Cleanup**: `DELETE /api/v1/tasks/:id` deletes **only** the test task created during this run. No blanket table drops or broad deletes.

### Real Execution Evidence

#### Run A: Local Staging Rehearsal (Ephemeral Server + Isolated PostgreSQL)
Command: `npx tsx scripts/test-staging-smoke-local.ts`  
Exit Code: `0` (Success)

```text
================================================================
        Equilibrium Staging Smoke-Test Harness (Phase 4A)       
================================================================
Target API URL: http://localhost:3999/api/v1
Test Account:   smoke_test_student@equilibrium.test
Password:       Smok...123!
----------------------------------------------------------------

[✓] Step 01: API Health Check (75ms) - PASS -> status=ok
[✓] Step 02: Authenticate Test Account (Registered) (203ms) - PASS -> Created new test user
[✓] Step 03: Verify Authorization Boundary (7ms) - PASS -> Authenticated as smoke_test_student@equilibrium.test
[✓] Step 04: Create Identifiable Test Task (11ms) - PASS -> taskId=a0153c34-071c-4986-9520-9e1364e6a473
[✓] Step 05: Fetch Task & Verify Fields (6ms) - PASS -> Estimate=90m, Completed=0m, Status=PENDING
[✓] Step 06: Schedule-Fit Simulation (21ms) - PASS -> fits=true, decisionType=FULLY_SCHEDULED
[✓] Step 07: Generate Schedule Version (25ms) - PASS -> versionId=52bc784e-46b7-427d-9d7d-a66599985e82, blocks=1
[✓] Step 08: Verify Scheduled Blocks (6ms) - PASS -> Found 1 scheduled chunks for test task
[✓] Step 09: Submit Progress Update (operationId) (13ms) - PASS -> actual=30m, remaining=60m, op=a098...29f7
[✓] Step 10: Idempotent Retry Verification (6ms) - PASS -> Replayed original response without double-counting effort
[✓] Step 11: Verify Decoupled Workload Semantics (4ms) - PASS -> Actual=30m, Remaining=60m, Status=IN_PROGRESS confirmed in DB
[✓] Step 12: Cross-User Isolation (IDOR Defense) (88ms) - PASS -> User B received HTTP 404 attempting to access User A task
[✓] Step 13: Verify Sleep Shield Protection (4ms) - PASS -> Active Sleep Shield: 23:00 -> 06:00
[✓] Step 14: Scoped Test Task Cleanup (7ms) - PASS -> Successfully deleted test task

================================================================
                   SMOKE TEST EXECUTION SUMMARY                 
================================================================
Step | Name                               | Status  | Duration
-----+------------------------------------+---------+---------
   1 | API Health Check                   | PASS    |    75ms
   2 | Authenticate Test Account (Registered) | PASS    |   203ms
   3 | Verify Authorization Boundary      | PASS    |     7ms
   4 | Create Identifiable Test Task      | PASS    |    11ms
   5 | Fetch Task & Verify Fields         | PASS    |     6ms
   6 | Schedule-Fit Simulation            | PASS    |    21ms
   7 | Generate Schedule Version          | PASS    |    25ms
   8 | Verify Scheduled Blocks            | PASS    |     6ms
   9 | Submit Progress Update (operationId) | PASS    |    13ms
  10 | Idempotent Retry Verification      | PASS    |     6ms
  11 | Verify Decoupled Workload Semantics | PASS    |     4ms
  12 | Cross-User Isolation (IDOR Defense) | PASS    |    88ms
  13 | Verify Sleep Shield Protection     | PASS    |     4ms
  14 | Scoped Test Task Cleanup           | PASS    |     7ms
-----+------------------------------------+---------+---------
TOTAL: 14 steps | PASSED: 14 | FAILED: 0 | BLOCKED: 0 | TIME: 476ms

FINAL RESULT: PASSED - All staging readiness requirements verified.
```

#### Run B: Unconfigured Environment Guard Check
Command: `npm run smoke:staging` (without `STAGING_API_URL`)  
Exit Code: `1` (CLI wrapper for exit code 2 `BLOCKED`)

```text
ERROR: STAGING_API_URL environment variable is not defined.
To run against local server: STAGING_API_URL="http://localhost:3000/api/v1"
To run against hosted staging: STAGING_API_URL="https://staging.equilibrium.app/api/v1"
[⊘] Step 01: Target URL Validation (0ms) - BLOCKED -> Missing STAGING_API_URL
FINAL RESULT: BLOCKED - Prerequisites or target availability incomplete.
```

#### Run C: Production Target Guard Check
Command: `$env:STAGING_API_URL="https://equilibrium-42g8.onrender.com/api/v1"; npm run smoke:staging`  
Exit Code: `1` (CLI wrapper for exit code 2 `BLOCKED`)

```text
CRITICAL SAFETY BLOCK: STAGING_API_URL appears to target a live production domain.
Refusing execution to protect production database and customer data.
If this is a deliberate test, you must explicitly set STAGING_ALLOW_PROD_URL=true.
[⊘] Step 01: Production Protection Guard (0ms) - BLOCKED -> Production-like URL blocked
FINAL RESULT: BLOCKED - Prerequisites or target availability incomplete.
```

---

## 5. Database Migration Rehearsal Evidence

### Isolated Rehearsal Target
- Database Engine: PostgreSQL 17.0 (64-bit) running on `localhost:5432`
- Database Name: `equilibrium_test`
- Connection URL: `postgresql://postgres:postgres@localhost:5432/equilibrium_test?schema=public`

### Pending Migrations Identified
Prisma migration history review identified three migrations applied to development but pending rehearsal:
1. `20261006090000_user_timezone_default_ist`: Sets default timezone for users to `Asia/Kolkata`.
2. `20261024143000_add_task_actual_and_remaining_minutes`: Adds `actualMinutes` (INT NOT NULL DEFAULT 0) and `remainingMinutes` (INT NULL) to `Task` table to support decoupled workload semantics.
3. `20261024150000_add_task_progress_operation`: Adds `TaskProgressOperation` table with fields `id`, `taskId`, `userId`, `operationId`, `payload`, `responseBody`, `statusCode`, `createdAt`, with unique constraint on `(userId, taskId, operationId)`.

### Rehearsal Execution
Rehearsal command executed:
```bash
npx prisma migrate deploy
```
Output:
```text
Prisma schema loaded from prisma\schema.prisma
Datasource "db": PostgreSQL database "equilibrium_test", schema "public" at "localhost:5432"

3 migrations found in prisma/migrations

Applying migration `20261006090000_user_timezone_default_ist`
Applying migration `20261024143000_add_task_actual_and_remaining_minutes`
Applying migration `20261024150000_add_task_progress_operation`

All migrations have been successfully applied.
```

Status check command:
```bash
npx prisma migrate status
```
Output:
```text
3 migrations found in prisma/migrations
Database schema is up to date!
```

### Table & Column Schema Verification
SQL inspection against `information_schema.columns` in `equilibrium_test` verified:
- Table `TaskProgressOperation` exists with primary key `id`, indexes on `operationId` and compound unique index `[userId, taskId, operationId]`.
- Table `Task` has column `actualMinutes` (`integer`, `is_nullable: NO`, `column_default: 0`).
- Table `Task` has column `remainingMinutes` (`integer`, `is_nullable: YES`).

### Post-Migration Persistence Verification
All 14 backend test suites (152 tests) were run against `equilibrium_test` via `npx jest --config jest.config.js --runInBand`.
All 152 tests passed (including task creation, progress operations, idempotent replays, deadline feasibility, and exam scheduling).

### Production Migration Risk & Rollback Strategy
- **Additive Design**: All changes in migrations `20261024143000` and `20261024150000` are non-breaking and backward-compatible (new table, optional column, and column with safe default).
- **Production Supabase Status**: Production database migrations are **intentionally withheld** until a hosted cloud staging rehearsal has completed.
- **Rollback Procedure**: In case of deployment failure, down-migration scripts are documented (`ALTER TABLE "Task" DROP COLUMN IF EXISTS "remainingMinutes", DROP COLUMN IF EXISTS "actualMinutes"; DROP TABLE IF EXISTS "TaskProgressOperation";`).

---

## 6. Flutter-to-API Integration Evidence

### Test Suite: `phase_4a_api_integration_test.dart`
Location: `equilibrium_app/test/phase_4a_api_integration_test.dart`  
Tests Executed: 7  
Passed: 7  
Failed: 0  
Duration: 0.8s

#### Integration Scenarios Verified

1. **Configurable Base URL Selection**:
   - Verified that `ApiClient.setBaseUrl('https://staging-api.equilibrium.app/api/v1')` updates URL resolution without restarting the app.
   - Verified persistence across app launches via `SharedPreferences`.
2. **Session Expiry & 401 Interception**:
   - Verified that an HTTP 401 Unauthorized response triggers `AuthProvider.forceLogout()`.
   - Verified that authentication token and user profile are purged from storage, returning app state to `unauthenticated`.
3. **Definite vs. Ambiguous Network Failure Categorization**:
   - Verified that client distinguishes HTTP 4xx validation rejections (`isDefiniteRejection = true`) from network dropouts (`isAmbiguousNetworkFailure = true`), preventing unsafe blind retries on business rejections.
4. **Task Creation & State Refresh**:
   - Verified that task creation through `TaskRepository` updates `ScheduleProvider` task list and triggers UI reactivity.
5. **Schedule Generation & Plan View Synchronization**:
   - Verified that generating a schedule updates `currentSchedule`, schedules blocks into the timeline, and refreshes the Today view.
6. **Progress Submission, Idempotency, and Retry Recovery**:
   - Verified that `PendingOperationManager` records in-flight progress operations.
   - Verified that upon simulated connection interruption, the operationId is retained in `SharedPreferences`.
   - Verified that retrying submits the identical operation ID and resolves cleanly without state corruption.
7. **Sign-Out & Account Isolation**:
   - Verified that invoking `signOut()` purges cached tasks, schedules, and JWT credentials.

---

## 7. CI and Repeatability

### Existing Pipeline (`ci.yml`) Review
- Runs on push to `main` and pull requests targeting `main`.
- `server` job: Spawns an isolated PostgreSQL 16 service container (`equilibrium_test`), runs migrations, builds TypeScript, and executes tests with Indian Standard Time (`Asia/Kolkata`) timezone.
- `flutter` job: Sets up Flutter stable channel, runs `flutter analyze`, `flutter test`, and builds web and Android release artifacts.

### Staging Smoke-Test Pipeline (`staging-smoke.yml`)
Created `.github/workflows/staging-smoke.yml` with the following properties:
- **Trigger**: `workflow_dispatch` (Manual on-demand trigger only. Never runs automatically on PRs or pushes).
- **Target URL Validation**: Accepts `staging_url` parameter; feeds it into `npm run smoke:staging`.
- **Zero Embedded Secrets**: Uses GitHub repository secrets `STAGING_TEST_EMAIL` and `STAGING_TEST_PASSWORD`.
- **Built-in Safety**: Inherits the harness's production protection guard; attempts to run against production URLs are automatically aborted.

---

## 8. Known Risks & Prioritized Remaining Actions

### Known Risks

1. **Missing Hosted Cloud Staging Service (`BLOCKED`)**:
   - Render configuration currently contains only the production web service (`equilibrium-api`) and production database (`equilibrium-db`).
   - *Impact*: End-to-end cloud smoke tests cannot execute until a dedicated staging web service and isolated database are provisioned.
2. **Pending Supabase Production Migrations**:
   - Remote Supabase production database does not yet contain migrations `20261024143000` and `20261024150000`.
   - *Impact*: Production deployments must remain halted until cloud staging validation is signed off.
3. **Mobile Network Security Configuration (Android / iOS)**:
   - Android release builds enforce HTTPS by default. Testing against local staging (`http://10.0.2.2:3000`) on Android physical devices or emulators requires `usesCleartextTraffic` or staging HTTPS certificates.

### Prioritized Action Plan (Roadmap to Phase 4B)

```mermaid
gantt
    title Equilibrium Staging to Validation Roadmap
    dateFormat  YYYY-MM-DD
    section Phase 4A (Complete)
    Local Rehearsal & Smoke Harness       :done, 2026-10-24, 1d
    Flutter Integration Test Suite         :done, 2026-10-24, 1d
    CI Workflow & Safety Guards            :done, 2026-10-24, 1d
    section Phase 4B (Next Steps)
    Provision Render Staging API & DB      :active, 2026-10-25, 1d
    Configure Staging GitHub Secrets       :2026-10-25, 1d
    Execute Cloud Staging Smoke Test       :2026-10-26, 1d
    Perform Flutter Web Staging Smoke Test :2026-10-26, 1d
    Deploy Production Database Migrations  :2026-10-27, 1d
```

1. **Action 1 (Cloud Infrastructure)**: Provision `equilibrium-api-staging` and `equilibrium-db-staging` on Render or Supabase staging tier.
2. **Action 2 (Secrets Configuration)**: Add `STAGING_API_URL` and `STAGING_TEST_PASSWORD` to GitHub Actions repository secrets.
3. **Action 3 (Staging Execution)**: Trigger `staging-smoke.yml` workflow via GitHub Actions UI and observe all 14 steps pass against the hosted staging URL.
4. **Action 4 (Production Migration Deployment)**: Once cloud staging passes, execute `npx prisma migrate deploy` against the production Supabase database during a scheduled maintenance window.

---

## 9. Deliverables Inventory

| File Path | Description | Status |
| :--- | :--- | :---: |
| `docs/PHASE_4A_STAGING_READINESS.md` | Comprehensive Phase 4A report and readiness matrix | **Created** |
| `server/scripts/staging-smoke-test.ts` | 14-step automated staging smoke-test harness with safety guards | **Created** |
| `server/scripts/test-staging-smoke-local.ts` | Local test runner for staging smoke test against isolated server | **Created** |
| `equilibrium_app/test/phase_4a_api_integration_test.dart` | 7 Flutter-to-API integration tests | **Created** |
| `.github/workflows/staging-smoke.yml` | On-demand staging verification GitHub workflow | **Created** |
| `server/package.json` | Added `smoke:staging` npm script | **Updated** |
| `server/src/repositories/task.repo.ts` | Status reversion fix when task effort decreases | **Updated** |
