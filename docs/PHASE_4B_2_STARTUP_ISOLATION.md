# Equilibrium — Phase 4B.2: Isolate Staging Startup from Production

**Document Status:** Complete & Verified  
**Date:** October 24, 2026  
**Target Environment:** Isolated Free Staging (Render Web Service + Supabase Free PostgreSQL)  
**Safety Classification:** Strictly Guarded | No Cloud Resources Provisioned | No Production Mutation | Zero Cost ($0.00)  

---

## 1. Executive Summary & Objective

In Phase 4B.1, a pre-start safety check (`server/scripts/prestart-check.js`) and migration flow were introduced to validate the Supabase staging database before booting the Express server. However, by modifying the shared `"start"` script in `server/package.json` and pointing `render.staging.yaml` to `npm start`, staging-specific preflight checks and assumptions were unintentionally coupled to the command shared by the production service.

**Phase 4B.2 formally isolates staging startup from production**, ensuring:
1. **Production Startup Unaltered:** Production `render.yaml` executes `npm start`, which retains its established deployment behavior without invoking staging preflight scripts or failing on staging identity checks.
2. **Dedicated Staging Startup:** `render.staging.yaml` explicitly invokes `npm run start:staging`, running the hardened preflight safety gate, applying migrations exclusively to the isolated staging database, and booting the server.
3. **Fail-Closed Staging Safety Gate:** The staging preflight script fails closed if hosted staging service identity (`RENDER_SERVICE_NAME=equilibrium-api-staging`) is missing or mismatched, prevents any connection to production database references unconditionally, enforces Supabase Session Pooler port 5432, and rejects wildcard CORS origins (`*`).
4. **Zero Cloud Deployments:** No cloud resources were provisioned, no remote migrations were executed, no commits were made, and production was not altered.

---

## 2. Audit of Startup Behavior: Old vs. New

### 2.1 Production Start Command Evidence (Git History)
Inspection of Git commit history confirmed the exact evolution of the production startup script:
- **Initial Baseline (Commit `6b34ceeface431f375e2810a21dedd70f4c367cd`, Aug 27, 2026):**
  `"start": "node dist/server.js"`
- **Production Baseline (Commit `da35f492536dcd89e3d93ca5727c5be067fdb919`, Sep 15, 2026):**
  `"start": "npx prisma migrate deploy && node dist/server.js"`
- **Current Production Blueprint (`render.yaml`):**
  ```yaml
  services:
    - type: web
      name: equilibrium-api
      env: node
      rootDir: server
      buildCommand: npm ci && node scripts/use-pg-schema.js && npm run build
      startCommand: npm start
      healthCheckPath: /api/v1/health
  ```
  `render.yaml` specifies `startCommand: npm start`. Therefore, production deployment relies on `npm start` in `server/package.json`.

### 2.2 The Coupling Issue in Phase 4B.1
In Phase 4B.1, `server/package.json` `"start"` was modified to:
```json
"start": "node scripts/prestart-check.js && npx prisma migrate deploy && node dist/server.js"
```
Because both `render.yaml` and `render.staging.yaml` invoked `npm start`, this shared script meant:
- The staging prestart script would execute during production startup, evaluating staging-specific conditions and environment variables.
- Any staging gate changes (such as expecting `equilibrium-api-staging`) would fail production deployments.

### 2.3 Phase 4B.2 Command Separation
The startup commands in `server/package.json` are now strictly separated:

| Environment | Blueprint | Invoked Command | Exact Script Definition |
|---|---|---|---|
| **Production** | `render.yaml` | `npm start` | `npx prisma migrate deploy && node dist/server.js` |
| **Staging** | `render.staging.yaml` | `npm run start:staging` | `node scripts/prestart-check.js && npx prisma migrate deploy && node dist/server.js` |

- **Production Impact:** `npm start` retains its established production migration-and-run sequence. It never executes `prestart-check.js`.
- **Staging Impact:** `render.staging.yaml` explicitly runs `npm run start:staging`. Staging migrations cannot proceed unless `prestart-check.js` passes all safety gates with exit code `0`.

---

## 3. Strengthened Staging Safety Gate (`server/scripts/prestart-check.js`)

The staging preflight script was hardened with fail-closed security policies:

### 3.1 Service Identity Check (Fail-Closed)
- **Hosted Environment:** Evaluates `process.env.RENDER_SERVICE_NAME` provided by the Render container runtime.
- **Fail-Closed Condition:**
  - If `RENDER_SERVICE_NAME` is missing or empty, halts immediately with exit code `1`.
  - If `RENDER_SERVICE_NAME` does not equal `'equilibrium-api-staging'` (e.g., if erroneously executed on the production service `'equilibrium-api'`), halts immediately with exit code `1`.
- **Explicit Local Rehearsal:** Local execution is permitted only when `ALLOW_LOCAL_START=true` is explicitly passed in the environment.

### 3.2 Unconditional Production Database Collision Guard
- If `DATABASE_URL` contains `cazlrtmmsikikexmepoc` in either the hostname or username (Supabase project ref format), the script halts immediately with:
  `[prestart-check] CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference.`
  `Refusing to apply migrations or start staging service to protect production data.`
  Exits code `1`.

### 3.3 Supabase Session Pooler (Port 5432) Enforcement
- For Supabase pooler hostnames (`aws-0-*.pooler.supabase.com` / `pooler.supabase.com`):
  - **Port 6543 (Transaction Pooler):** Fails immediately with exit code `1`. Prisma CLI requires PostgreSQL advisory locks (`pg_advisory_lock`), which transaction pooling discards across statements, leading to hanging or failed migrations.
  - **Port 5432 (Session Pooler):** Validated and required.
  - Any port other than 5432 fails closed with exit code `1`.

### 3.4 Strict Secret Masking
- The script logs only sanitized metadata:
  `[prestart-check] Service Identity: equilibrium-api-staging`
  `[prestart-check] Database Target: host=aws-0-ap-south-1.pooler.supabase.com, port=5432, database=/postgres`
  `[prestart-check] CORS Allowed Origins: https://staging.equilibrium.app`
  `[prestart-check] JWT_SECRET: CONFIGURED (prod...8901)`
- Database passwords, user credentials, query parameters (`?search_path=...`), and raw JWT secrets are never printed to stdout or stderr.

---

## 4. Staging CORS Configuration Hardening

### 4.1 Rejection of Wildcard Origins for Staging
In Phase 4B.1, `render.staging.yaml` provided `ALLOWED_ORIGINS: '*'`.  
In Phase 4B.2:
1. **Blueprint Update ([render.staging.yaml](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/render.staging.yaml)):**
   ```yaml
         - key: ALLOWED_ORIGINS
           sync: false
   ```
   Requires the operator to supply an explicit list of permitted browser origins via the Render Dashboard.
2. **Preflight Enforcement ([server/scripts/prestart-check.js](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/scripts/prestart-check.js)):**
   - Rejects missing or empty `ALLOWED_ORIGINS` with exit code `1`.
   - Rejects wildcard `'*'` or lists containing `'*'` with exit code `1`:
     `[prestart-check] FATAL: Wildcard CORS origin ("*") is rejected for staging.`
     `[prestart-check] Staging must configure an explicit comma-separated list of permitted browser origins in Render Dashboard.`

### 4.2 Handling Origins Prior to Frontend Provisioning
- **No Fictional Origins:** Configuration must never specify fictional `.local` domains in hosted staging.
- **Local Web Development Option:** `http://localhost:8080` may be supplied in `ALLOWED_ORIGINS` during development if running local Flutter Web debug sessions against the hosted staging API.
- **Adding the Actual Hosted Origin:** Once the staging frontend web client is provisioned (e.g., on Render, Vercel, or Firebase Hosting), its actual HTTPS domain (e.g., `https://equilibrium-staging-web.onrender.com`) is added to the comma-separated list in Render Dashboard settings.
- **Smoke-Test Independence:** API-to-API testing (such as `staging-smoke-test.ts` and GitHub Actions CI) communicates via Node.js HTTP clients without browser CORS restrictions. Smoke tests run independently of browser origin allowlists.
- **Production CORS Untouched:** Production `render.yaml` remains untouched (`ALLOWED_ORIGINS: '*'`).

### 4.3 Removal of Guessed `APP_PUBLIC_URL` from Blueprint
In Phase 4B.1, `render.staging.yaml` specified `APP_PUBLIC_URL: sync: false`.
- **Finding:** Requiring `APP_PUBLIC_URL` via `sync: false` forced the operator to guess Render's assigned hostname before the web service had even been provisioned.
- **Correction:** In [server/src/config.ts](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/src/config.ts#L13), `config.appPublicUrl` is defined as:
  ```typescript
  appPublicUrl: process.env.APP_PUBLIC_URL || process.env.RENDER_EXTERNAL_URL || 'https://equilibrium-42g8.onrender.com'
  ```
- **Action:** `APP_PUBLIC_URL` was removed from `render.staging.yaml`. Render automatically provides `RENDER_EXTERNAL_URL` at runtime, ensuring password reset links resolve to the exact provisioned staging hostname without requiring a guessed value during initial creation. Production `render.yaml` was not modified.

---

## 5. Files Changed & Rationale

| File | Change | Rationale |
|---|---|---|
| [`server/package.json`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/package.json) | Restored `start: npx prisma migrate deploy && node dist/server.js`; added `start:staging: node scripts/prestart-check.js && npx prisma migrate deploy && node dist/server.js` | Disentangles production startup from staging prestart check. |
| [`render.staging.yaml`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/render.staging.yaml) | Changed `startCommand: npm run start:staging`; changed `ALLOWED_ORIGINS: sync: false`; removed `APP_PUBLIC_URL: sync: false` | Uses isolated staging start command; requires dashboard-configured CORS origins; relies on automatic `RENDER_EXTERNAL_URL`. |
| [`server/scripts/prestart-check.js`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/scripts/prestart-check.js) | Implemented fail-closed identity, unconditional production DB block, port 5432 check, and CORS wildcard block | Hardens staging boot gate before migrations can be invoked. |
| [`server/test/regression.staging-startup.test.ts`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/test/regression.staging-startup.test.ts) | Created comprehensive 8-case automated test suite | Proves startup separation, identity gating, database safety, CORS rejection, and secret masking. |
| [`equilibrium_app/test/phase_3b_reliability_test.dart`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/test/phase_3b_reliability_test.dart) | Anchored narrow layout mock schedule to daytime (10:00 AM) | Prevents test run collision with 23:00 Sleep Shield when tests execute in late evening. |

---

## 6. Regression & Verification Results

All required verification suites were executed directly and their exit codes verified:

### 6.1 Server Scheduler & Regression Tests (`npm test`)
```text
Test Suites: 9 passed, 9 total
Tests:       106 passed, 106 total
Snapshots:   0 total
Time:        3.408 s
Exit code: 0
```
Includes `regression.staging-startup.test.ts` (8/8 tests passed):
- `1. Production npm start does not unexpectedly begin executing the staging migration flow`
- `2. Staging startup invokes the staging safety check before migrations`
- `3. A production database reference is rejected for staging`
- `4. Missing or incorrect hosted staging identity stops execution before migrations`
- `5. Missing database configuration stops execution before migrations`
- `6. A missing or wildcard staging origin fails the staging preflight`
- `7. Safe local-test mode works only when explicitly enabled`
- `8. Failures preserve a nonzero exit code and expose no secret values`

### 6.2 TypeScript Compilation Check
```text
npx tsc --noEmit
Exit code: 0 (Zero errors)
```

### 6.3 Database-Backed Jest Safety Guard Verification (`test:api`)
Executed explicitly against the isolated local test database:
```bash
$env:DATABASE_URL="postgresql://postgres:postgres@localhost:5432/equilibrium_test"; npx jest --config jest.config.js --runInBand
```
- **Target Verification:** Target confirmed on `localhost:5432/equilibrium_test`.
- **Exit Code:** `0`
- **Result:** 16 test suites passed, 175 tests passed, 0 failures.
- **Safety Guard Behavior:** When executed without a localhost target (e.g. against any remote connection string), `server/test/global-setup.js` immediately halts execution before wiping data or running tests:
  ```text
  Error: Jest: Got error running globalSetup - server/test/global-setup.js, 
  reason: REFUSING TO RUN TESTS: DATABASE_URL is not a local test database.
  Exit code: 1
  ```

### 6.4 Staging Smoke-Test Local Rehearsal (`test-staging-smoke-local.ts`)
```text
TOTAL: 14 steps | PASSED: 14 | FAILED: 0 | BLOCKED: 0 | SKIPPED: 0 | TIME: 349ms
FINAL RESULT: PASSED - All staging readiness requirements verified.
Exit code: 0
```

### 6.5 Flutter Application Quality Gates (`equilibrium_app`)
- **Unit & Widget Tests:**
  ```text
  flutter test
  00:07 +87: All tests passed!
  Exit code: 0
  ```
- **Static Analysis:**
  ```text
  flutter analyze --fatal-infos --fatal-warnings
  Analyzing equilibrium_app...
  No issues found! (ran in 5.5s)
  Exit code: 0
  ```
- **Web Release Compilation:**
  ```text
  flutter build web --release
  Compiling lib/main.dart for the Web...
  Built build/web (ran in 55.6s)
  Exit code: 0
  ```

---

## 7. Confirmation of Local Resource Isolation

During all local test executions:
- **No Remote Resources Accessed:** All tests executed against local mocks, ephemeral in-memory state, or strictly localhost connections (`localhost:5432/equilibrium_test`).
- **Production Completely Untouched:** Production `render.yaml`, production databases (`cazlrtmmsikikexmepoc`), and production configuration remained entirely untouched.
- **No Git Commits or Push:** No changes have been staged or committed to Git.

---

## 8. Remaining Manual Provisioning Actions (Operator Runbook)

Hosted staging is **not claimed ready** until the repository owner manually provisions the cloud services:
1. **Create Supabase Free Project:** Provision `equilibrium-staging-db` in the Supabase Dashboard and retrieve the **Session Pooler URL (Port 5432)**.
2. **Apply Render Blueprint:** In the Render Dashboard, create a new Blueprint pointing to `render.staging.yaml`.
3. **Supply Dashboard Secrets (`sync: false`):**
   - `DATABASE_URL`: The Supabase Session Pooler URI on port 5432.
   - `ALLOWED_ORIGINS`: Comma-separated list of permitted browser origins (e.g., `http://localhost:8080` for local Flutter web debug, or the deployed frontend domain).
4. **Deploy & Smoke Test:** Verify container logs for successful `prestart-check` and migration application, then dispatch the GitHub Actions smoke-test workflow.

---

## 9. Pre-Provisioning Decision

| Pre-Provisioning Verification Check | Status | Verification Detail |
|---|---|---|
| **Production Startup Isolation** | **PASS** | `render.yaml` executes `npm start`; `prestart-check.js` omitted from production start command. |
| **Staging Startup Separation** | **PASS** | `render.staging.yaml` explicitly invokes `npm run start:staging`. |
| **Staging Blueprint Syntax (Local)** | **PASS** | `render.staging.yaml` parses cleanly via `js-yaml` with 0 syntax errors. |
| **Render Blueprint Remote Validation** | **NOT TESTED** | Render CLI / authenticated API validation tokens are unavailable in this environment. Local schema validation passed. |
| **Prisma Session Pooler (Port 5432) Gate** | **PASS** | Enforced by `prestart-check.js`; transaction pooler port 6543 rejected with exit code `1`. |
| **Production DB Collision Block** | **PASS** | Subprocess test confirmed unconditional exit code `1` if targeting `cazlrtmmsikikexmepoc`. |
| **Hosted Identity Fail-Closed Gate** | **PASS** | Rejects missing or non-matching `RENDER_SERVICE_NAME` with exit code `1`. |
| **Staging CORS Wildcard Rejection** | **PASS** | Rejects `*` or empty origins; requires explicit dashboard configuration (`sync: false`). |
| **Dynamic Hostname Auto-Resolution** | **PASS** | `APP_PUBLIC_URL` removed from Blueprint; `server/src/config.ts` automatically adopts `RENDER_EXTERNAL_URL`. |
| **Local Unit & Regression Suites** | **PASS** | 106/106 tests passed in `server` (including 8/8 startup regression tests). |
| **Isolated Local PostgreSQL Suite** | **PASS** | 175/175 tests passed in `test:api` against `localhost:5432/equilibrium_test`. |
| **Local Staging Smoke Rehearsal** | **PASS** | 14/14 steps passed in 349ms against ephemeral server. |
| **Flutter Tests, Analysis & Web Build** | **PASS** | 87/87 tests passed, 0 analyzer issues, web release build passed. |
| **Hosted Cloud Persistence Provisioning** | **BLOCKED** | Awaiting manual operator creation of Supabase staging database project. |
| **Hosted Web Service Deployment** | **BLOCKED** | Awaiting manual operator apply in Render Dashboard. |
