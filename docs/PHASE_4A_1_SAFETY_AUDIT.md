# Phase 4A.1: Staging Safety Gate & Change Audit Report

**Project:** Equilibrium — Student Workload, Focus & Sleep Balancing System  
**Phase:** 4A.1 (Staging Safety Gate & Change Audit)  
**Date:** 2026-10-24  
**Author:** Antigravity Agentic Pair Programmer  
**Status:** COMPLETE (Safety Gates Enforced, Fail-Closed Target Validation Verified, Changes Audited)

---

## 1. Executive Summary & Scope Boundaries

Phase 4A.1 reviews, audits, and hardens the staging readiness implementation established in Phase 4A before any remote cloud staging infrastructure is provisioned.

### Safety & Scope Boundaries Enforced
- **Zero Cloud Infrastructure Provisioned**: No cloud resources were deployed or modified on Render, Supabase, or AWS.
- **Zero Production Mutations**: Production databases and environment variables were not altered or migrated.
- **Fail-Closed Target Security**: Smoke testing now strictly refuses network requests unless the target hostname exactly matches an explicitly configured `STAGING_ALLOWED_HOST`.
- **Localhost Isolation**: Localhost targets are rejected unless an explicit local-test mode (`ALLOW_LOCALHOST=true`) is declared.
- **Redirect Protection**: In-flight HTTP redirects to unapproved origins are blocked before credentials or mutating payloads can be transmitted.
- **No Unverified Claims**: Hosted cloud staging remains explicitly marked **BLOCKED** pending cloud provisioning.

---

## 2. File-by-File Change Audit

Every file modified or created during Phase 4A and Phase 4A.1 has been inspected, audited, and linked to automated test coverage:

| File Path | Change Type | Rationale & Architectural Purpose | Test Coverage |
| :--- | :---: | :--- | :--- |
| `server/src/repositories/task.repo.ts` | **Modified** | Hardened `safeUpdate` to mutually synchronize `completedMinutes` and `actualMinutes`, prevent overrun tasks from auto-completing, revive `remainingMinutes` when completed tasks have effort decreased, set `remainingMinutes = 0` on completion, and enforce strict user ownership. | `server/test/v3.regression.test.ts` (7 tests), `server/test/regression.task-progress-reschedule.test.ts` (36 tests), `server/test/api.test.ts` |
| `server/scripts/staging-target-validator.ts` | **Created** | Fail-closed validation engine enforcing exact hostname matching against `STAGING_ALLOWED_HOST`, forbidden production domain blocklists, lookalike spoofing rejection, HTTPS enforcement, and redirect origin interception. | `server/test/staging-target-validator.test.ts` (10 tests) |
| `server/scripts/staging-smoke-test.ts` | **Hardened** | 14-step staging smoke test harness with preflight target & credential safety gates, redirect protection, scoped task cleanup, emergency error cleanup, and strict nonzero exit code propagation. | `server/test/staging-target-validator.test.ts` (Test 8), `server/scripts/test-staging-smoke-local.ts` |
| `server/scripts/test-staging-smoke-local.ts` | **Modified** | Isolated local rehearsal runner spawning an ephemeral server on port 3999, passing `ALLOW_LOCALHOST: 'true'`, and executing all 14 smoke steps against local PostgreSQL 17 test database. | Executed directly (`npx tsx scripts/test-staging-smoke-local.ts`, exit code 0) |
| `server/test/v3.regression.test.ts` | **Modified** | Added 5 dedicated regression test cases verifying `safeUpdate` workload synchronization, status revival, overrun safety, explicit completion, and IDOR protection. | Executed directly (`npx jest test/v3.regression.test.ts`, 7/7 passed) |
| `server/test/staging-target-validator.test.ts` | **Created** | Automated test suite validating all 9 target validation and safety gate scenarios (approved host, missing host, production host, lookalikes, unexpected hosts, malformed URLs, redirect interception, process exit codes, localhost gating). | Executed directly (`npx jest test/staging-target-validator.test.ts`, 10/10 passed) |
| `.github/workflows/staging-smoke.yml` | **Hardened** | On-demand GitHub Actions workflow requiring `staging_url` and `staging_allowed_host`, validating secrets before network activity, setting `ALLOW_LOCALHOST: 'false'`, and propagating test failures. | CI syntax and manual dispatch configuration |
| `equilibrium_app/test/phase_4a_api_integration_test.dart` | **Created** | Flutter integration tests verifying configurable `API_BASE_URL` resolution, HTTP 401 interception, failure categorization, state reactivity across providers, and session isolation. | `flutter test test/phase_4a_api_integration_test.dart` (7/7 passed) |
| `equilibrium_app/test/phase_3b_reliability_test.dart` | **Modified** | Anchored Today screen grouping test blocks to morning (`todayMorning = DateTime(now.year, now.month, now.day, 9, 0)`) to eliminate time-of-day midnight boundary flakes when tests run in the evening. | `flutter test test/phase_3b_reliability_test.dart` (37/37 passed) |
| `server/package.json` | **Modified** | Added `"smoke:staging": "tsx scripts/staging-smoke-test.ts"` npm script. | Executed via npm |
| `docs/PHASE_4A_STAGING_READINESS.md` | **Created** | Initial staging readiness deliverable documenting environment architecture, migration rehearsal, and baseline metrics. | Documentation review |

---

## 3. Deep-Dive Audit: `task.repo.ts` & Workload Semantics

### The Issue Investigated
During Phase 4A baseline testing, `v3.regression.test.ts` failed when testing status reversion:
- *Scenario*: A task was marked `COMPLETED` (estimate: 60m, completed: 60m). Later, an update reduced `completedMinutes` to 30m.
- *Defect*: The existing `safeUpdate` method did not adjust status to `IN_PROGRESS` or revive `remainingMinutes`, because line 85 only inspected `remainingMinutes`.

### Audit of `TaskRepository.safeUpdate` Invariants

```typescript
// 1. Synchronize actualMinutes and completedMinutes if only one was passed
if (targetCompleted != null && targetActual == null) {
  data.actualMinutes = targetCompleted;
} else if (targetActual != null && targetCompleted == null) {
  data.completedMinutes = targetActual;
}

// 2. Status determination
if (data.status === undefined) {
  if (targetRemaining === 0) {
    data.status = 'COMPLETED';
  } else if (targetRemaining != null && (targetRemaining as number) > 0 && task.status === 'COMPLETED') {
    data.status = 'IN_PROGRESS';
  } else if (targetCompleted != null && (targetCompleted as number) < task.estimateMinutes && task.status === 'COMPLETED') {
    data.status = 'IN_PROGRESS';
    if (data.remainingMinutes === undefined) {
      data.remainingMinutes = Math.max(0, task.estimateMinutes - (targetCompleted as number));
    }
  }
} else if (newStatus === 'COMPLETED') {
  if (data.remainingMinutes === undefined) {
    data.remainingMinutes = 0;
  }
} else if (newStatus === 'IN_PROGRESS' && task.status === 'COMPLETED') {
  if (data.remainingMinutes === undefined && (task.remainingMinutes === 0 || task.remainingMinutes == null)) {
    const effectiveCompleted = targetCompleted ?? task.completedMinutes ?? 0;
    data.remainingMinutes = Math.max(1, task.estimateMinutes - (effectiveCompleted as number));
  }
}
```

### Verification of Core Invariants

1. **`completedMinutes` Updates Cannot Silently Desync `actualMinutes` or `remainingMinutes`**:
   - If legacy or standard clients send `{ completedMinutes: 45 }`, `data.actualMinutes` is automatically synchronized to 45.
   - If `actualMinutes` is sent, `completedMinutes` is synchronized.
2. **`COMPLETED` Tasks Cannot Become Inconsistently Completed or In Progress**:
   - If status is set to `COMPLETED`, `remainingMinutes` is guaranteed to be 0.
   - If a task is completed and `completedMinutes` is lowered below `estimateMinutes` (or `remainingMinutes > 0` is set), the task is revived to `IN_PROGRESS` and `remainingMinutes` is recalculated as `estimate - completed`.
3. **Overrun Safety Preserved**:
   - If a student logs 80 minutes on a 60-minute task (`completedMinutes >= estimateMinutes`), the task **never auto-completes** unless `status: 'COMPLETED'` or `remainingMinutes: 0` is explicitly provided.
4. **User Ownership Enforced**:
   - `safeUpdate` queries `findById(id, userId)` and updates with `where: { id, userId }`.
   - If user B attempts to update user A's task, it immediately throws `Task not found or unauthorized` and updates 0 records.
5. **No Double-Counting**:
   - Progress updates with `operationId` are handled in `recordProgress` inside interactive transactions with `TaskProgressOperation` unique constraints, guaranteeing idempotency.

### Test Evidence (`server/test/v3.regression.test.ts`)
```text
PASS test/v3.regression.test.ts
  V3 Regression Tests
    √ Regression test: task status reverts from COMPLETED when completedMinutes drops below threshold (155 ms)
    √ Regression test: scheduledMinutes freezes correctly for a task completed in version A when version B is generated without it (29 ms)
    TaskRepository.safeUpdate workload & status consistency
      √ synchronizes actualMinutes when completedMinutes is updated, and revives remainingMinutes on completed task (7 ms)
      √ synchronizes completedMinutes when actualMinutes is updated (6 ms)
      √ does not auto-flip to COMPLETED on overrun when completedMinutes >= estimateMinutes unless status or remainingMinutes=0 is explicit (6 ms)
      √ sets remainingMinutes to 0 when status is explicitly set to COMPLETED (6 ms)
      √ strictly enforces user ownership in safeUpdate (prevents IDOR) (23 ms)
```

---

## 4. Fail-Closed Staging Target Validation & Security Gate

### Architecture: Fail-Closed vs. Vulnerable Blocklists

Previously, the smoke test relied on a blocklist of production domains (`equilibrium-42g8.onrender.com`). Blocklists are vulnerable to lookalike domains, unlisted production domains, and accidental misconfiguration.

Phase 4A.1 implements a **strict, fail-closed target policy**:
1. **Explicit Approved Hostname**: `STAGING_ALLOWED_HOST` is required for hosted staging. If omitted, execution halts immediately with exit code 2.
2. **Exact Matching**: Parsed URL hostnames are compared using case-insensitive exact equality (`targetToMatch === expected`). Substring or suffix matches are rejected.
3. **Production Host Hard Block**: Known production hostnames (`equilibrium-42g8.onrender.com`, `equilibrium.app`, `www.equilibrium.app`, `api.equilibrium.app`, `prod.equilibrium.app`) and spoofed lookalikes (`*.equilibrium.app.*`, `*.onrender.com.*`) are rejected even if someone sets `STAGING_ALLOWED_HOST`.
4. **Protocol & Port Enforcement**: Hosted staging requires HTTPS on default port 443 (or explicitly specified port).
5. **Localhost Isolation**: Localhost targets (`localhost`, `127.0.0.1`, `::1`) are rejected unless explicit local-test mode is declared via `ALLOW_LOCALHOST=true`.
6. **Redirect Interception**: The `createSecureRequester` wrapper intercepts HTTP 301/302/303/307/308 redirects with `redirect: 'manual'`. If the `Location` header points to any origin other than `approvedOrigin`, the request is aborted with `Security Violation: Redirect to unapproved origin rejected` before credentials or headers are forwarded.

### Automated Test Evidence (`server/test/staging-target-validator.test.ts`)

All 9 required security scenarios were verified:

| Scenario | Tested Behavior | Result |
| :--- | :--- | :---: |
| **1. Approved Hostname** | `targetUrl: https://staging-api.equilibrium.app/api/v1` with matching `STAGING_ALLOWED_HOST` | **PASS** |
| **2. Missing Approved Hostname** | Missing `STAGING_ALLOWED_HOST` halts with `Missing STAGING_ALLOWED_HOST. Staging target validation is fail-closed.` | **PASS** |
| **3. Known Production Host** | Attempting to target `equilibrium-42g8.onrender.com` or `equilibrium.app` halts with forbidden production host error | **PASS** |
| **4. Lookalike Hostname** | Attempting `staging-api.equilibrium.app.attacker.com` or `equilibrium.app.phishing.net` rejected | **PASS** |
| **5. Unexpected External Host** | Attempting `random-service.io` rejected as host mismatch | **PASS** |
| **6. Malformed URL** | Invalid URLs (`not-a-url`, `ftp://...`, empty) rejected with parse error | **PASS** |
| **7. Redirect Interception** | HTTP 302 redirect to `https://evil-attacker.example.com` aborted before sending headers/body | **PASS** |
| **8. Nonzero Process Exit Codes** | Process exits with code 2 on configuration error, exit code 1 on test failure, never 0 on failure | **PASS** |
| **9. Local-Test Mode Distinction** | Localhost rejected when `ALLOW_LOCALHOST=false`; permitted when `ALLOW_LOCALHOST=true` | **PASS** |

```text
PASS test/staging-target-validator.test.ts (5.505 s)
  Phase 4A.1: Staging Target Validation & Security Gate
    √ 1. accepts explicitly approved staging hostname over HTTPS (3 ms)
    √ 2. fails closed when approved hostname (STAGING_ALLOWED_HOST) is missing (1 ms)
    √ 3. strictly rejects known production hostnames even if configured as allowed host (1 ms)
    √ 4. rejects lookalike hostnames with added suffixes or attacker subdomains (1 ms)
    √ 5. rejects unexpected external hostnames (1 ms)
    √ 6. rejects malformed or invalid URLs (1 ms)
    √ 8. ensures smoke test process fails with nonzero exit code on invalid target or config (5061 ms)
    √ 9. enforces local-test mode distinction: rejects localhost unless ALLOW_LOCALHOST=true (1 ms)
    7. Redirect Security Verification
      √ rejects redirect when target origin differs from approved origin (40 ms)
      √ permits redirect when target location stays within approved origin (22 ms)
```

---

## 5. Smoke-Test Credentials & Data Isolation Findings

### Required Configuration Environment Variables

| Variable | Required | Purpose | Validation Rule |
| :--- | :---: | :--- | :--- |
| `STAGING_API_URL` | **Yes** | Staging API base endpoint | Valid HTTP/HTTPS URL. Trailing slashes stripped. |
| `STAGING_ALLOWED_HOST` | **Yes** (Hosted) | Approved target hostname | Must match parsed URL hostname exactly. Fail-closed. |
| `ALLOW_LOCALHOST` | **Yes** (Local) | Local rehearsal override | Must be explicitly `'true'` to permit localhost/127.0.0.1. |
| `STAGING_TEST_EMAIL` | **Yes** | Dedicated staging test user A | Must be non-empty and valid email format (`/^[^\s@]+@[^\s@]+\.[^\s@]+$/`). |
| `STAGING_TEST_PASSWORD` | **Yes** | Staging test user A password | Minimum 8 characters. Masked in console output. |
| `STAGING_TEST_PASSWORD_B`| No | Ephemeral test user B password | Defaults to `STAGING_TEST_PASSWORD`. Masked in logs. |

### Data Isolation & Cleanup Integrity
- **Preflight Credential Check**: Missing or invalid emails/passwords halt execution before any network request or database mutation occurs.
- **Credential Masking**: Logs display passwords as `Smok...123!` or `********`. Tokens and request bodies containing secrets are never written to logs.
- **Second User Isolation**: User B is registered dynamically with a unique run ID (`smoke_b_[runId]@equilibrium.test`). Step 12 confirms User B receives HTTP 404 when querying User A's task.
- **Scoped Cleanup**: Step 14 deletes **only** the single task created by User A during that specific run (`DELETE /api/v1/tasks/:createdTaskId`). No blanket deletes or table drops.
- **Emergency Cleanup Handling**: If an unexpected exception occurs mid-run, an emergency cleanup block attempts deletion of `createdTaskId` and explicitly reports whether cleanup succeeded or failed. If cleanup fails, the summary prints:
  `CRITICAL WARNING: Scoped test task cleanup did not complete successfully.` and forces process exit code 1.

---

## 6. GitHub Actions Wiring Verification

Audit of `.github/workflows/staging-smoke.yml`:

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
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: server/package-lock.json

      - name: Install dependencies
        run: npm ci

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

### Safety Confirmations
1. **Manual Trigger Only**: Configured with `workflow_dispatch` only. Cannot trigger automatically on pull requests or commits.
2. **Preflight Guard**: Step `Preflight Secrets & Safety Check` terminates the GitHub workflow with exit code 1 if `STAGING_TEST_PASSWORD` or `staging_allowed_host` is empty.
3. **Fail-Closed Target in CI**: `staging_allowed_host` is required input; `ALLOW_LOCALHOST` is explicitly set to `'false'`.
4. **Log Sanitization**: Passwords and JWT tokens are masked in console output.
5. **Accidental Production Block**: Even if someone enters `https://equilibrium-42g8.onrender.com/api/v1` in GitHub Actions, the runner aborts with `Target host is a forbidden production host`.

---

## 7. Local Rehearsal & Baseline Test Verification

All baseline checks were rerun in full using only the isolated local PostgreSQL test database (`equilibrium_test`) and local application processes.

### Execution Results

| Check | Command | Result | Exit Code | Notes |
| :--- | :--- | :---: | :---: | :--- |
| **Backend Unit & Regression Suite** | `npm test` in `server` | **PASS** | `0` | 8 test suites, 98/98 tests passed (4.1s). |
| **Backend TypeScript Verification** | `npx tsc --noEmit` in `server` | **PASS** | `0` | Clean type-check. Zero errors. |
| **Database-Backed Jest Integration Suite** | `$env:DATABASE_URL="postgresql://postgres:postgres@localhost:5432/equilibrium_test?schema=public"; npx jest --config jest.config.js --runInBand` | **PASS** | `0` | 15 test suites, 167/167 tests passed (21.2s). Tested against isolated PostgreSQL 17 test DB. |
| **Staging Target Security Tests** | `npx jest test/staging-target-validator.test.ts` in `server` | **PASS** | `0` | 1 test suite, 10/10 tests passed (5.5s). All 9 safety scenarios validated. |
| **Local Staging Smoke Rehearsal** | `npx tsx scripts/test-staging-smoke-local.ts` in `server` | **PASS** | `0` | Ephemeral server on port 3999 + isolated DB. **All 14 steps PASSED (503ms)**. |
| **Flutter Test Suite** | `flutter test` in `equilibrium_app` | **PASS** | `0` | 87/87 tests passed (5.1s). Fixed evening midnight boundary flake. |
| **Flutter Static Analysis** | `flutter analyze --fatal-infos --fatal-warnings` in `equilibrium_app` | **PASS** | `0` | No issues found! Clean analysis (4.7s). |
| **Flutter Web Release Build** | `flutter build web --release` in `equilibrium_app` | **PASS** | `0` | Compiled `build/web` cleanly (51.9s). Tree-shaken icons. |

---

## 8. Remaining Blockers & Next Actions

1. **Cloud Staging Infrastructure Provisioning (`BLOCKED`)**:
   - Hosted staging cannot be verified until an isolated Render web service (`equilibrium-api-staging`) and isolated database (`equilibrium-db-staging`) are provisioned.
2. **GitHub Actions Secrets Configuration (`BLOCKED`)**:
   - `STAGING_TEST_PASSWORD` and `STAGING_TEST_EMAIL` must be configured in GitHub repository secrets before triggering `staging-smoke.yml`.
3. **Production Database Migration Withholding (`INTENTIONAL`)**:
   - Migrations `20261024143000` and `20261024150000` remain unapplied on the remote Supabase production database. They must remain withheld until cloud staging verification is complete.
4. **No Public Launch (`INTENTIONAL`)**:
   - Equilibrium remains in readiness verification mode. Public launch readiness is strictly gated on Phase 4B/4C hosted validation.
