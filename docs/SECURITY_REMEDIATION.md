# EQUILIBRIUM: Security Remediation & Configuration Hygiene (Phase 1)
**Date:** October 23, 2026  
**Auditor / Engineer:** Senior Technical Architect & Security Lead  
**Scope:** Repository Secret Hygiene, Git Tracking Defense, Safe Configuration Validation  
**Status:** Remediated & Verified (No secrets modified, leaked, or exposed)

---

## 1. Executive Summary & Remediation Objectives

As part of Phase 1 of the Equilibrium product hardening plan, an immediate repository audit and secret hygiene remediation was performed. 

### Key Principles Applied:
1. **Zero Secret Exposure:** No passwords, connection strings, private keys, or API tokens are printed, logged, committed, or included in any documentation.
2. **Local Work Preservation:** Local `.env` files remain intact on the developer's machine and were not overwritten, deleted, or reset.
3. **Repository Defense-in-Depth:** Configured multi-level `.gitignore` rules (root, server, and backend prototype) to guarantee that environment files are permanently excluded from Git tracking while permitting `.env.example` templates.
4. **Automated CI/CD Safety Guard:** Integrated an automated, zero-overhead secrets hygiene regression test into the existing test suite (`npm test`).

---

## 2. Inventory of Secret Findings

During static inspection of tracked repository files and Git history:

| Location | Status in Git | Variable Name | Finding & Action Taken |
| :--- | :---: | :---: | :--- |
| `server/.env` | **Untracked (Local Only)** | `DATABASE_URL`, `JWT_SECRET`, `NODE_ENV` | Verified that `server/.env` was **never** committed to Git in any commit history. File was confirmed to be actively ignored by `server/.gitignore`. Kept intact locally. |
| `equilibrium_backend/.env` | **Tracked in Git** | `DATABASE_URL` | Tracked in Git index (originally committed in `1d79aec`). Immediately removed from the Git index (`git rm --cached`) while preserving the physical file on disk. |
| `server/.env.example` | **Tracked (Clean)** | All config keys | Contains only safe, clearly fake placeholder values. Updated with explicit security documentation and length requirements. |
| `render.yaml` | **Tracked (Clean)** | `JWT_SECRET`, `DATABASE_URL` | Contains blueprint references and `generateValue: true`; contains no raw credentials. |
| `production_migration_baseline.md` | **Tracked (Clean)** | `DATABASE_URL` | Contains only standard documentation placeholders (`localhost`, `<user>`, `<password>`). |

---

## 3. Summary of Changes Made

### 3.1 Root Repository `.gitignore` Created
The repository root lacked a `.gitignore`, leaving subdirectories vulnerable to accidental tracking. A root `.gitignore` was established:
- Ignores `.env`, `.env.*`, and `*.env`.
- Explicitly permits `!.env.example` and `!**/.env.example`.
- Ignores OS metadata (`.DS_Store`, `Thumbs.db`) and build directories (`dist/`, `build/`).

### 3.2 Server `.gitignore` Hardened
Updated `server/.gitignore` to explicitly prevent any variant of environment files (`.env`, `.env.*`, `*.env`) while explicitly allowing `!.env.example`.

### 3.3 Prototype Backend `.gitignore` Added
Added `equilibrium_backend/.gitignore` to ignore `.env`, virtual environments, and Python bytecode caches.

### 3.4 Untracked `equilibrium_backend/.env` from Git Index
Executed:
```bash
git rm --cached equilibrium_backend/.env
```
- **Result:** The file was safely removed from the Git index (staged for deletion in version control) while the physical file remains completely untouched on the local filesystem.
- Git now ignores this file on any future commits.

### 3.5 Updated `server/.env.example` with Safe Placeholders
`server/.env.example` was updated with:
- Clearly fake, non-functional placeholders for all required environment variables (`DATABASE_URL`, `JWT_SECRET`, `PORT`, `NODE_ENV`, `ALLOWED_ORIGINS`, `APP_PUBLIC_URL`, `RESEND_API_KEY`, `EMAIL_FROM`, `SKIP_DB_WIPE`).
- Explicit documentation highlighting that in production (`NODE_ENV=production`), `JWT_SECRET` must be a high-entropy string of at least 32 characters.

### 3.6 Automated Secrets Hygiene Regression Test Added
Created `server/test/regression.secrets-hygiene.test.ts`:
- Automatically executed on every run of `npm test`.
- Validates that `.env.example` exists and contains all required keys.
- Validates that `.env.example` contains zero cloud provider hostnames (e.g. Supabase, AWS, Render) or non-localhost connection strings.
- Validates that `.gitignore` actively ignores `.env` while preserving `!.env.example`.
- Validates that production `JWT_SECRET` validation rejects strings under 32 characters.

---

## 4. Render `JWT_SECRET` Analysis & Unverified Remote Settings

### 4.1 Repository Code Inspection
In `server/src/config.ts`:
```typescript
const isProduction = process.env.NODE_ENV === 'production';
const jwtSecret = process.env.JWT_SECRET || (isProduction ? '' : 'test-secret');

if (isProduction && jwtSecret.length < 32) {
  throw new Error('JWT_SECRET must be set to at least 32 characters in production');
}
```
In `render.yaml`:
```yaml
envVars:
  - key: JWT_SECRET
    generateValue: true
```

### 4.2 Behavior & Technical Clarification
- **Blueprint Specification:** In Render, `generateValue: true` creates a secure random string **once** upon initial service creation from the blueprint. Render stores this generated string in the service's dashboard environment variables. On subsequent deployments or git pushes, Render re-uses the existing dashboard variable and does **not** regenerate it.
- **Unverified Remote Settings:**
  - The live Render dashboard cannot be inspected directly from the repository.
  - Whether `JWT_SECRET` was manually edited or generated via blueprint in the live dashboard is **unverified**.
  - Whether `RESEND_API_KEY` has been provisioned in the live Render dashboard is **unverified**.
- **Actionable Advice:** Do not modify `render.yaml` at this stage. Instead, verify in the Render dashboard that `JWT_SECRET` is persistent and that `RESEND_API_KEY` is added if password reset emails are required.

---

## 5. Required Manual Dashboard Steps (Action Items)

Because credentials in `equilibrium_backend/.env` were committed in a prior historical commit (`1d79aec`), the following manual steps should be performed on external hosting dashboards:

### Step 1: Rotate PostgreSQL Database Password
1. Log in to your database hosting provider dashboard (e.g. Supabase / AWS / Render).
2. Navigate to **Database Settings** $\rightarrow$ **Database Password**.
3. Reset / Rotate the database password.
4. Update your private local `.env` with the new password.
5. In the **Render Dashboard**, update the `DATABASE_URL` environment variable with the newly rotated connection string.

### Step 2: Configure Render Dashboard Environment Variables
1. Open the Render Dashboard for `equilibrium-api`.
2. Navigate to **Environment**.
3. Verify that `JWT_SECRET` is set and has a persistent, secure string of at least 32 characters (e.g. generated with `openssl rand -base64 32`).
4. If password reset emails are required, add:
   - `RESEND_API_KEY`: Your Resend API key (`re_...`).
   - `EMAIL_FROM`: Your verified sender address (e.g., `noreply@yourdomain.com`).

---

## 6. Historical Git Cleanup Instructions (Optional)

`server/.env` was never tracked in Git. However, `equilibrium_backend/.env` was committed in historical commit `1d79aec`. 

If this repository is to be made public, the historical commit can be sanitized using `git-filter-repo` (the official Git recommended tool). **Do not run this without coordinating with all collaborators, as rewriting history alters commit hashes.**

### Procedure for Historical Purge (Run when ready to rewrite history):
```bash
# 1. Install git-filter-repo (requires Python)
pip install git-filter-repo

# 2. Make a complete backup copy of the repository directory
cp -r "Equilibrium CP" "Equilibrium_Backup"

# 3. Purge the historical file across all branches and commits
git filter-repo --path equilibrium_backend/.env --invert-paths --force

# 4. Verify that the file no longer exists in history
git log --all --full-history -- "**/equilibrium_backend/.env"

# 5. Force push to remote (WARNING: Re-writes remote commit hashes)
git push origin main --force
```

---

## 7. Verification & Test Execution Results

All commands executed locally following remediation:

| Test / Check | Exact Command | Exit Status | Result |
| :--- | :--- | :---: | :--- |
| **Scheduler & Security Hygiene Tests** | `npm test` (in `server/`) | **0** | **5 / 5 suites passed** (38 tests passed, 0 failed, 4.21s). Includes new `regression.secrets-hygiene.test.ts`. |
| **Tracked Env File Check** | `git ls-files "*env*" "**/*env*"` | **0** | Only `server/.env.example` remains tracked. `server/.env` and `equilibrium_backend/.env` are not tracked. |
| **Physical File Verification** | `Test-Path "server/.env", "equilibrium_backend/.env"` | **0** | Both return `True` (local files safely preserved). |
| **Ignore Rule Verification** | `git check-ignore -v server/.env equilibrium_backend/.env` | **0** | Both files confirmed ignored by respective `.gitignore` rules. |
| **Flutter Static Analysis** | `flutter analyze` (in `equilibrium_app/`) | **0** | **No issues found!** (Zero errors, warnings, or lints). |

---

## 8. Rollback Notes

If these configuration changes need to be rolled back:
1. To restore Git tracking of `equilibrium_backend/.env`:
   ```bash
   git add -f equilibrium_backend/.env
   ```
2. To remove the new root `.gitignore`:
   ```bash
   git checkout HEAD -- .gitignore
   ```
3. To remove the regression test:
   ```bash
   git checkout HEAD -- server/test/regression.secrets-hygiene.test.ts
   ```
