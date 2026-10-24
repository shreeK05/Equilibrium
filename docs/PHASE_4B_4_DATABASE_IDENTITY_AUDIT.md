# Equilibrium — Phase 4B.4: Production Database Identity Resolution & Staging Safety Hardening

**Date:** October 24, 2026  
**Auditor:** Senior Infrastructure, Security & Reliability Engineer  
**Branch:** `equilibrium-staging`  
**Status:** **CLOUD PROVISIONING BLOCKED** (Pending manual confirmation of live Render Dashboard database identity)  
**Safety Stance:** Fail-Closed | Zero Secret Exposure | Multi-Target Defense-in-Depth

---

## 1. Executive Summary

Phase 4B.4 investigates an apparent ambiguity in production database references across repository artifacts, configuration files, and owner dashboard evidence:
1. The owner's Supabase dashboard displays an active project with reference **`rlqphunokjkxzqetondw`** (confirmed in `docs/PRODUCT_AUDIT.md` line 244 and active in local `server/.env`).
2. The Phase 4B.2 staging pre-start safety gate (`server/scripts/prestart-check.js`) previously guarded against candidate reference **`cazlrtmmsikikexmepoc`**.
3. The tracked production blueprint (`render.yaml`) specifies a Render-managed database named **`equilibrium-db`** via Blueprint property `fromDatabase`.

These references represent different database targets. Because Render allows manual dashboard environment variable overrides that supersede repository Blueprint declarations, the live production database target cannot be proven conclusively from local Git files alone.

### Key Actions Completed in Phase 4B.4:
- **Unified Production Database Blocklist:** Updated `server/scripts/prestart-check.js` to unconditionally reject `rlqphunokjkxzqetondw`, `cazlrtmmsikikexmepoc`, and `equilibrium-db` across all hostnames and username patterns.
- **Automated Regression Test Expansion:** Extended `server/test/regression.staging-startup.test.ts` to verify that both direct Supabase connections (`db.<ref>.supabase.co`), Session Pooler connections (`aws-0-*.pooler.supabase.com` with `postgres.<ref>` username), and Render database hosts (`equilibrium-db`) are rejected before any migration can run.
- **Audit of Deleted Screenshots (`SS/`):** Documented the 7 unstaged deleted screenshot files from commit `277eda6`, established the exact non-destructive restoration command (`git checkout HEAD -- SS/`), and confirmed they are excluded from the staging commit.
- **Git History vs. Staged Deletion Analysis:** Audited the staged deletion of `equilibrium_backend/.env`. Confirmed that staging removal purges the file from future HEAD snapshots but **does not** erase historical Git commits (`6b34cee`, `74318e6`, `1d79aec`), where credentials remain in the repository DAG.
- **Credential Rotation Runbook:** Defined credential categories and safe, zero-downtime rotation procedures without printing or requesting secrets.
- **Cloud Provisioning Verdict:** **BLOCKED**. No remote staging deployment, migration, or cloud provisioning should proceed until the owner executes the manual Render Dashboard check documented herein.

---

## 2. Evidence & Forensic Analysis of Database Identities

### 2.1 The Three Production Database Candidates

| Candidate Target | Source of Evidence | Where Referenced in Repository | Verified Role |
| :--- | :--- | :--- | :--- |
| **`rlqphunokjkxzqetondw`** | Owner's Supabase Dashboard screenshot; active in local uncommitted `server/.env` | `docs/PRODUCT_AUDIT.md` (line 244) | **Confirmed Active Supabase Project.** Contains student schema in `ap-south-1` region. |
| **`cazlrtmmsikikexmepoc`** | Phase 4B.1 / 4B.2 staging reports | `server/scripts/prestart-check.js`, `server/test/regression.staging-startup.test.ts`, `docs/PHASE_4B_*` | **Candidate Production Reference.** Recorded in Phase 4B documentation. Must remain blocked to guarantee complete fail-closed safety. |
| **`equilibrium-db`** | Production Blueprint `render.yaml` (lines 13–15, 22–26) | `render.yaml`, `render.yaml` git history (`ff83b58`, `126df43`) | **Blueprint Production Database.** Render internal PostgreSQL instance provisioned if service was created via Blueprint. |

### 2.2 Git History & Static Repository Audit

A comprehensive search of Git history across all branches and commits established:
```bash
# Static search for cazlrtmmsikikexmepoc across entire Git history
git log -S "cazlrtmmsikikexmepoc" --all
# Result: 0 commits (only exists in untracked/modified working tree files from Phase 4B)

# Static search for rlqphunokjkxzqetondw across entire Git history
git log -S "rlqphunokjkxzqetondw" --all
# Result: 0 commits (never committed to Git; exists only in local server/.env and untracked docs/PRODUCT_AUDIT.md)

# History of render.yaml
git log -p render.yaml
# Result: Created in ff83b58 with equilibrium-db; build command modified in 126df43; unchanged since.
```

### 2.3 Why Neither Reference May Be Discarded

1. **`rlqphunokjkxzqetondw` is confirmed live:** The owner's dashboard screenshot and `docs/PRODUCT_AUDIT.md` demonstrate that `rlqphunokjkxzqetondw` is a real Supabase database project holding Equilibrium data. If staging connects to this project, it could drop or alter live user tables during `prisma migrate deploy`.
2. **`cazlrtmmsikikexmepoc` must not be silently replaced:** Even though `cazlrtmmsikikexmepoc` was not found in git history, silently removing it from the blocklist violates fail-closed defense-in-depth. If an auxiliary project, sandbox, or previous database instance was identified by that reference, removing it would expose that database to accidental mutation.
3. **Unified Blocklist Policy:** The staging pre-start guard must block **both** references unconditionally, as well as the internal Render hostname `equilibrium-db`.

---

## 3. What Is Established Locally vs. What Must Be Confirmed in Render Dashboard

### 3.1 Established Locally
- In `render.yaml`, production `equilibrium-api` is configured to receive `DATABASE_URL` from the Blueprint database `equilibrium-db`.
- In `render.staging.yaml`, staging `equilibrium-api-staging` is configured with `sync: false` for `DATABASE_URL`, requiring explicit dashboard entry.
- In `server/scripts/prestart-check.js`, `KNOWN_PRODUCTION_DB_REFS` blocks `cazlrtmmsikikexmepoc`, `rlqphunokjkxzqetondw`, and `equilibrium-db`.
- The local developer environment (`server/.env`) connects to Supabase pooler `aws-0-ap-south-1.pooler.supabase.com` under project `rlqphunokjkxzqetondw`.

### 3.2 What Cannot Be Established Locally
Because Render allows users to override environment variables directly in the web UI without editing `render.yaml`:
- It is impossible to know locally whether the live production web service `equilibrium-api` is currently running against:
  - (a) Render's internal PostgreSQL instance `equilibrium-db`, **or**
  - (b) Supabase project `rlqphunokjkxzqetondw`, **or**
  - (c) Another external database instance.

### 3.3 Manual Render Dashboard Verification Runbook

> [!IMPORTANT]
> **Safety Rule:** Never copy, print, log, or share the database password, full connection string, or secret tokens. The verification checks only the hostname, service name, and project reference prefix.

The repository owner must execute the following non-destructive checks:

#### Step 1: Check Production Service `DATABASE_URL`
1. Open the [Render Dashboard](https://dashboard.render.com).
2. Click on the production web service: **`equilibrium-api`**.
3. In the left navigation, click **Environment**.
4. Locate the row for `DATABASE_URL`:
   - **Case A (Render-Managed):** If the value displays `from database equilibrium-db` or a green badge linking to `equilibrium-db`, the live production service is using Render's internal PostgreSQL.
   - **Case B (Supabase External Override):** If the value displays a masked connection string (`postgres://...` or `postgresql://...`), click the reveal/view toggle briefly to inspect the host and username prefix only:
     - Check if the username is `postgres.rlqphunokjkxzqetondw` or if the host is `aws-0-ap-south-1.pooler.supabase.com`.
     - Check if it contains `cazlrtmmsikikexmepoc`.
   - **Record the identified production target without copying passwords.**

#### Step 2: Check Render Managed Databases
1. In the Render Dashboard top navigation, click **Dashboard** or **PostgreSQL**.
2. Check if a database named **`equilibrium-db`** exists:
   - Check **Status** (Available / Suspended).
   - Check **Connections** and **Metrics** to see if queries are active.

#### Step 3: Check Supabase Dashboard
1. Open the [Supabase Dashboard](https://supabase.com/dashboard/projects).
2. Check the project named `Equilibrium` with reference **`rlqphunokjkxzqetondw`**:
   - Open **Table Editor**. Verify if `User`, `Task`, `Schedule`, `ScheduleVersion` contain production user records.
3. Check if any project with reference **`cazlrtmmsikikexmepoc`** exists in your organization.

---

## 4. Staging Safety Gate Enhancement & Regression Tests

### 4.1 Safety Gate Implementation (`server/scripts/prestart-check.js`)

The blocklist array in `server/scripts/prestart-check.js` was updated:
```javascript
const KNOWN_PRODUCTION_DB_REFS = [
  'cazlrtmmsikikexmepoc',
  'rlqphunokjkxzqetondw',
  'equilibrium-db'
];
```

The collision check inspects both the hostname and the username (lowercased for case-insensitivity):
```javascript
  // 3. Production Database Collision Guard (Unconditional)
  for (const prodRef of KNOWN_PRODUCTION_DB_REFS) {
    const lowerRef = prodRef.toLowerCase();
    const user = (dbUrl.username || '').toLowerCase();
    if (host.includes(lowerRef) || user.includes(lowerRef)) {
      console.error('[prestart-check] CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference.');
      console.error('[prestart-check] Refusing to apply migrations or start staging service to protect production data.');
      return exitFn(1);
    }
  }
```

### 4.2 Automated Regression Tests (`server/test/regression.staging-startup.test.ts`)

Test 3 was expanded to test 7 distinct production collision vectors:
1. `cazlrtmmsikikexmepoc` in pooler hostname (`aws-0-cazlrtmmsikikexmepoc.pooler.supabase.com`)
2. `cazlrtmmsikikexmepoc` in direct hostname (`db.cazlrtmmsikikexmepoc.supabase.co`)
3. `cazlrtmmsikikexmepoc` in username (`postgres.cazlrtmmsikikexmepoc`)
4. `rlqphunokjkxzqetondw` in pooler hostname (`aws-0-rlqphunokjkxzqetondw.pooler.supabase.com`)
5. `rlqphunokjkxzqetondw` in direct hostname (`db.rlqphunokjkxzqetondw.supabase.co`)
6. `rlqphunokjkxzqetondw` in username (`postgres.rlqphunokjkxzqetondw`)
7. `equilibrium-db` in hostname (`postgresql://equilibrium:pass@equilibrium-db:5432/equilibrium`)

**Execution Result:**
```
PASS test/regression.staging-startup.test.ts
  Regression: Staging Startup Isolation & Safety Gate (Phase 4B.2)
    √ 1. Production npm start does not unexpectedly begin executing the staging migration flow (2 ms)
    √ 2. Staging startup invokes the staging safety check before migrations (1 ms)
    √ 3. All candidate and confirmed production database references are rejected for staging (501 ms)
    √ 4. Missing or incorrect hosted staging identity stops execution before migrations (137 ms)
    √ 5. Missing database configuration stops execution before migrations (207 ms)
    √ 6. A missing or wildcard staging origin fails the staging preflight (219 ms)
    √ 7. Safe local-test mode works only when explicitly enabled (143 ms)
    √ 8. Failures preserve a nonzero exit code and expose no secret values (136 ms)

Test Suites: 1 passed, 1 total
Tests:       8 passed, 8 total
```

---

## 5. Review of Deleted Screenshots under `SS/`

### 5.1 Status & History
The following 7 files are currently deleted in the local working directory (unstaged):
- `SS/Screenshot_20260930_184531_Equilibrium.jpg`
- `SS/Screenshot_20260930_184651_Equilibrium.jpg`
- `SS/Screenshot_20260930_184718_Equilibrium.jpg`
- `SS/Screenshot_20260930_184954_Equilibrium.jpg`
- `SS/Screenshot_20260930_185013_Equilibrium.jpg`
- `SS/Screenshot_20260930_185023_Equilibrium.jpg`
- `SS/Screenshot_20260930_185223_Equilibrium.jpg`

These files were committed in commit `277eda6` (`Fix timezone bug in scheduler, timeline UI rendering, and interaction logic`). They are mobile application UI screenshots.

### 5.2 Preservation Policy
- **Do NOT delete or restore automatically.**
- If the deletion was **accidental**, the exact command to restore all 7 files without altering any other work is:
  ```bash
  git checkout HEAD -- SS/
  ```
- If the deletion was **intentional** (e.g., to reduce repository clone size), stage their deletion explicitly:
  ```bash
  git rm SS/Screenshot_20260930_*.jpg
  ```
- **Staging Commit Exclusion:** These files MUST be excluded from the proposed staging commit unless the repository owner intentionally chooses to commit their removal. Do NOT use `git add .` or `git commit -a`.

---

## 6. Review of Staged Deletion of `equilibrium_backend/.env` & Git History Reality

### 6.1 Status in Current Working Tree
`git status` reports:
```
D  equilibrium_backend/.env
```
This file was staged for removal via `git rm --cached equilibrium_backend/.env` during Phase 1 (`docs/SECURITY_REMEDIATION.md`).

### 6.2 Impact on HEAD vs. Git History
- **Impact on HEAD:** Once this staged change is committed to the local branch, `equilibrium_backend/.env` will be removed from the tracked file tree. Future checkouts or clones of that commit will not have the file in their working directory.
- **Git History Reality (Crucial Distinction):**
  > [!WARNING]
  > Staging or committing the deletion of a file **DOES NOT** erase it from past Git history.
  
  In Git's commit graph, `equilibrium_backend/.env` was tracked in commits:
  - `6b34cee` (*Initial commit for Equilibrium deployment*)
  - `74318e6` (*Remove sensitive .env from tracking*)
  - `1d79aec` (*Migrate to PostgreSQL for Render*)

  Anyone with access to the repository can run:
  ```bash
  git show 1d79aec:equilibrium_backend/.env
  ```
  and view the committed historical contents. Therefore, **staging the deletion does NOT remediate historical credential exposure.**

---

## 7. Historical Secret-Rotation Runbook

Because historical commits cannot be assumed secret on a shared or public repository (`shreeK05/Equilibrium`), all exposed credentials must be rotated.

> [!NOTE]
> **Zero Exposure Rule:** Never print, log, or request the plaintext secret values during this process.

### 7.1 Inventory of Credential Categories

| Credential Category | Service Impact if Revoked / Rotated | Risk Level |
| :--- | :--- | :---: |
| **1. Supabase PostgreSQL Password** | Backend cannot connect to database; immediate HTTP 500 across all API endpoints until connection string is updated. | **Critical (P0)** |
| **2. Render Web Service `JWT_SECRET`** | Existing active student login tokens become invalid; users are logged out and must re-authenticate. | **High (P1)** |
| **3. Resend API Key (`RESEND_API_KEY`)** | Password reset emails cannot be sent until new key is deployed. | **Medium (P2)** |
| **4. Supabase API Keys (Anon / Service Role)** | Client SDK calls or direct REST calls using the rotated key are rejected. | **High (P1)** |

### 7.2 Zero-Downtime Safe Rotation Runbook

#### Procedure A: Rotating Supabase Database Password
1. **Prepare New Password:** Generate a high-entropy random password (e.g. `openssl rand -base64 24`) in a secure password manager.
2. **Access Supabase Console:** Navigate to **Project Settings** $\rightarrow$ **Database** $\rightarrow$ **Database Password**.
3. **Update Password in Supabase:** Enter the new password and apply changes.
4. **Immediately Update Render Production Environment:**
   - Go to [Render Dashboard](https://dashboard.render.com) $\rightarrow$ `equilibrium-api` $\rightarrow$ **Environment**.
   - Update `DATABASE_URL` with the new password in the connection string.
   - Click **Save Changes** (Render will trigger an automatic zero-downtime redeploy).
5. **Verify Service Health:**
   - Check `https://equilibrium-42g8.onrender.com/api/v1/health` $\rightarrow$ should return `{"status":"ok"}`.
   - Run a test login from the mobile app or staging smoke test harness.

#### Procedure B: Rotating `JWT_SECRET`
1. **Generate New Secret:** Generate a random 64-character hexadecimal string:
   ```bash
   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
   ```
2. **Update Render Dashboard:**
   - In Render Dashboard $\rightarrow$ `equilibrium-api` $\rightarrow$ **Environment**.
   - Set `JWT_SECRET` to the new 64-character string.
   - Save changes and redeploy.
3. **Expected User Impact:** All currently logged-in mobile clients will receive `HTTP 401 Unauthorized` on their next request. The Equilibrium Flutter client's `api_client.dart` token interceptor will catch the 401 and redirect users to the login screen cleanly.

#### Procedure C: Rotating Resend API Key
1. **Access Resend Dashboard:** Go to [Resend API Keys](https://resend.com/api-keys).
2. **Create New Key:** Create an API key named `equilibrium-prod-2026`. Copy the key.
3. **Update Render Environment:** Set `RESEND_API_KEY` in the Render Dashboard environment settings.
4. **Verify Email Delivery:** Request a password reset for a test account; verify email delivery.
5. **Revoke Old Key:** In the Resend Dashboard, delete / revoke the old API key.

---

## 8. Verification & Test Evidence

All automated test suites were executed locally against isolated test infrastructure:

| Verification Suite | Exact Command | Exit Code | Results |
| :--- | :--- | :---: | :--- |
| **Staging Startup Regression** | `npm test test/regression.staging-startup.test.ts` | **0** | **8 / 8 tests passed** (including expanded 7-case DB collision test). |
| **Full Jest Unit & Regression** | `npm test` (in `server/`) | **0** | **9 / 9 suites passed, 106 / 106 tests passed.** |
| **Full Database Integration Suite** | `$env:DATABASE_URL="postgresql://postgres:postgres@localhost:5432/equilibrium_test?schema=public"; npm run test:api -- --runInBand` | **0** | **16 / 16 suites passed, 175 / 175 tests passed** (27.27s). |
| **Staging Smoke Local Rehearsal** | `npx tsx scripts/test-staging-smoke-local.ts` | **0** | **14 / 14 steps passed** (384ms, zero errors). |
| **Backend TypeScript Compilation** | `npx tsc --noEmit` | **0** | **0 errors, clean build.** |
| **Flutter Test Suite** | `flutter test` (in `equilibrium_app/`) | **0** | **87 / 87 tests passed** (clean). |

---

## 9. Cloud Provisioning Decision

```
================================================================================
                    CLOUD PROVISIONING DECISION: BLOCKED                        
================================================================================
Reason:
1. The live production database identity remains ambiguous between Render-managed
   'equilibrium-db' and Supabase project 'rlqphunokjkxzqetondw'.
2. Live Render Dashboard environment variables must be manually inspected by the
   repository owner to confirm whether 'DATABASE_URL' is linked via Blueprint or
   overridden with an external connection string.
3. Once confirmed, a dedicated, isolated Supabase staging project must be created
   with a distinct project reference before any staging cloud resources are provisioned.
================================================================================
```
