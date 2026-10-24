# Equilibrium Phase 2B.2.1: Task Progress Semantics Correction

**Status:** Completed & Verified  
**Date:** October 24, 2026  
**Scope:** Backend task repository, routes, scheduler consumption, Flutter client models, progress dialog, and end-to-end regression test suite.

---

## 1. Executive Summary & Root Cause Analysis

### The Flaw
In previous versions, `Task.completedMinutes` conflated two mutually incompatible concepts:
1. **Actual elapsed effort** spent in focus sessions or logged by the user.
2. **Completed academic work progress** assumed to reduce remaining workload (`Math.max(0, estimateMinutes - completedMinutes)`).

Furthermore, `TaskRepository.safeUpdate` and `TaskRepository.recordProgress` contained logic that automatically changed a task's status to `COMPLETED` whenever `completedMinutes >= estimateMinutes`, even when the user explicitly selected `Made Progress` or when significant work remained to be done.

### Consequence
- When a task overran its original estimate (e.g., an essay estimated at 60 minutes taking 90 minutes with 30 minutes still required):
  - `completedMinutes` was incremented to 90.
  - The repository automatically marked the task `COMPLETED`.
  - The remaining work calculation yielded `Math.max(0, 60 - 90) = 0`, so the scheduler dropped the task entirely instead of scheduling the remaining 30 minutes.
- If a user finished a focus timer session and then interacted with the progress dialog choosing "Need More Time", the session minutes were vulnerable to being double-counted.

---

## 2. Distinct Field Definitions & Architecture

To permanently decouple effort spent from work remaining without breaking legacy consumers, four distinct concepts are now implemented:

| Field | Type | Semantic Definition | Authoritative Source |
|---|---|---|---|
| `estimateMinutes` | `Int` | Original initial estimate of total task duration. Baseline for early completion / overrun disruption metrics. | Set at task creation (or explicitly updated via `newEstimateMinutes`). |
| `actualMinutes` | `Int` (default 0) | Cumulative actual effort spent by the user across focus timer sessions and manual logs. | Incremented by completed timer sessions or explicit user logs. |
| `remainingMinutes` | `Int?` | Authoritative estimate of work remaining to be scheduled by the scheduling engine. | Decremented by progress or explicitly confirmed/set by user via `Made Progress` / `Need More Time`. When 0, task is done. |
| `status` | `String` / `Enum` | Explicit lifecycle state (`PENDING`, `IN_PROGRESS`, `COMPLETED`, `ARCHIVED`). | User action (`Finished`) or explicit state update. |
| `completedMinutes` | `Int` (default 0) | Backward-compatibility mirror synced with `actualMinutes` for existing API consumers and older Flutter client views. | Maintained in database and API payloads. |

### Architectural Rules
1. **No Auto-Completion on Effort Overrun:** An unfinished task whose `actualMinutes` exceeds `estimateMinutes` retains `status: 'IN_PROGRESS'` as long as `remainingMinutes > 0` or status is explicitly set.
2. **Explicit Finished Authority:** An explicit `Finished` action completes a task regardless of whether actual elapsed minutes are less than, equal to, or greater than the original estimate. When finished, `remainingMinutes` is set to 0.
3. **Scheduler Consumes Remaining Work:** The scheduler (`schedule.service.ts` / `rescheduler.ts`) consumes `task.remainingMinutes`, not `estimateMinutes - completedMinutes`. Tasks with `remainingMinutes === 0` are excluded from candidate task scheduling.
4. **Timer Single-Count Invariant:** Completing a timer session records `additionalMinutes` once to `task.actualMinutes` and decrements `task.remainingMinutes`. The subsequent progress dialog defaults untracked effort to 0, preventing double-counting.
5. **Idempotent Completion & Retries:** `focusSessionsRouter.patch('/:id/complete')` only operates on `RUNNING` or `PAUSED` sessions. Retries return HTTP 400 and cannot duplicate logged minutes.

---

## 3. Database Migration & Historical Compatibility

### Prisma Schema (`server/prisma/schema.prisma`)
```prisma
model Task {
  id                 String           @id @default(uuid())
  userId             String
  ...
  estimateMinutes    Int
  actualMinutes      Int              @default(0)
  remainingMinutes   Int?
  completedMinutes   Int              @default(0)
  status             String           @default("PENDING")
  ...
}
```

### Additive Migration SQL (`server/prisma/migrations/20261024143000_add_task_actual_and_remaining_minutes/migration.sql`)
```sql
-- AlterTable: Additive migration for separate progress semantics
ALTER TABLE "Task" ADD COLUMN "actualMinutes" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Task" ADD COLUMN "remainingMinutes" INTEGER;
```

> [!IMPORTANT]
> **Production Safety Invariant:** This migration is additive and backward-compatible. In accordance with safety policies, this migration was NOT applied to any remote or production database.

### Historical Row Resolution (`server/src/utils/task-workload.helper.ts`)
To handle legacy rows without fabricating historical effort:
- If `actualMinutes` is 0 and `completedMinutes > 0`, `actualMinutes` resolves to `completedMinutes`.
- If `remainingMinutes` is `null`:
  - If `status === 'COMPLETED'`, `remainingMinutes` resolves to `0`.
  - Otherwise, `remainingMinutes` resolves to `Math.max(0, estimateMinutes - completedMinutes)`.
- If an older client updates a legacy row with `{ completedMinutes: 35 }`, `recordProgress` updates `actualMinutes: 35` and recomputes `remainingMinutes: Math.max(0, estimate - 35)`.

---

## 4. Files Modified & Changes Made

### Backend (`server/`)
1. [schema.prisma](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/prisma/schema.prisma):
   - Added `actualMinutes Int @default(0)` and `remainingMinutes Int?`.
2. [migration.sql](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/prisma/migrations/20261024143000_add_task_actual_and_remaining_minutes/migration.sql):
   - Created additive SQL migration.
3. [task-workload.helper.ts](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/src/utils/task-workload.helper.ts):
   - Created `resolveTaskWorkload(task)` helper to safely normalize workload fields across new and legacy records.
4. [task.repo.ts](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/src/repositories/task.repo.ts):
   - `create`: Initializes `actualMinutes` and `remainingMinutes`.
   - `safeUpdate`: Removed false auto-completion (`newCompleted >= newEstimate => COMPLETED`).
   - `complete`: Records actual effort, sets `remainingMinutes: 0`, marks schedule blocks complete, logs disruption events.
   - `recordProgress`: Updates `actualMinutes`, `remainingMinutes`, `estimateMinutes`, `status`, and syncs `completedMinutes`. Never falsely auto-completes when `remainingMinutes > 0` or status is `IN_PROGRESS`.
   - `split`: Consumes `resolveTaskWorkload(task).remainingMinutes`.
5. [focus-sessions.routes.ts](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/src/routes/focus-sessions.routes.ts):
   - Completed focus sessions increment `actualMinutes` and decrement `remainingMinutes` without auto-completing unfinished tasks.
6. [schedule.service.ts](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/src/services/schedule.service.ts):
   - `loadContext`: Uses `resolveTaskWorkload(t)`, passes authoritative `remainingMinutes` to the scheduling pipeline, and filters out tasks with `remainingMinutes <= 0`.
7. [dashboard.routes.ts](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/src/routes/dashboard.routes.ts):
   - Includes `actualMinutes` and `remainingMinutes` in task select and computes `totalRemainingMinutes` via `resolveTaskWorkload(t).remainingMinutes`.
8. [insights.routes.ts](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/src/routes/insights.routes.ts):
   - Computes `remainingMinutes` via `resolveTaskWorkload(task).remainingMinutes`.
9. [schemas.ts](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/src/validation/schemas.ts):
   - Updated `taskSchema`, `taskUpdateSchema`, `taskProgressSchema` to validate `actualMinutes` and `remainingMinutes`.
10. [fake-prisma.ts](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/test/helpers/fake-prisma.ts):
    - Added `focusSession` in-memory mock store and CRUD operations.
11. [regression.task-progress-reschedule.test.ts](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/test/regression.task-progress-reschedule.test.ts):
    - Added comprehensive regression tests covering all 8 specified verification requirements.

### Frontend Client (`equilibrium_app/`)
1. [task.dart](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/lib/models/task.dart):
   - Added `actualMinutes` and `remainingMinutes` fields, constructor defaults, `fromJson`, `toJson`, `copyWith`.
2. [task_repository.dart](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/lib/services/task_repository.dart):
   - Added `actualMinutes` and `remainingMinutes` parameters to `recordProgress`.
3. [schedule_provider.dart](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/lib/core/state/schedule_provider.dart):
   - Added `actualMinutes` and `remainingMinutes` parameters to `recordTaskProgress`.
4. [task_progress_dialog.dart](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/lib/widgets/dialogs/task_progress_dialog.dart):
   - Separated display of actual effort spent and estimated remaining time.
   - In "Need More Time": default untracked effort to 0 to prevent double-counting completed timer sessions, and pass explicit `remainingMinutes`.
   - In "Made Progress": pass updated `remainingMinutes`.
5. [phase_2b2_progress_test.dart](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/test/phase_2b2_progress_test.dart):
   - Updated `MockScheduleProvider` and assertions to verify separate dimensions for actual effort and remaining workload.

---

## 5. Verification & Test Results

### 1. Backend Safe Server Tests
```bash
$ npm test
PASS test/regression.task-progress-reschedule.test.ts
PASS test/regression.secrets-hygiene.test.ts
PASS test/regression.deadline-feasibility.test.ts
PASS test/regression.insights-sleep-capacity.test.ts
PASS test/regression.exam-prep-sleep-shield.test.ts
PASS test/scheduler.extended.test.ts
PASS test/scheduler.test.ts
PASS test/regression.student-workflow.test.ts

Test Suites: 8 passed, 8 total
Tests:       85 passed, 85 total
Snapshots:   0 total
Time:        2.759 s
```

### 2. Backend TypeScript Compilation
```bash
$ npx tsc --noEmit
# Exit code: 0 (No type errors)
```

### 3. Flutter Client Tests
```bash
$ flutter test
00:04 +49: All tests passed!
```

### 4. Flutter Code Analysis
```bash
$ flutter analyze --fatal-infos --fatal-warnings
Analyzing equilibrium_app...
No issues found! (ran in 2.4s)
```

---

## 6. Verification Against Acceptance Criteria

| Requirement | Verified Behavior | Test Assertion |
|---|---|---|
| **1. Overrun Task (60m est, 90m spent, 30m still needed)** | Task retains `IN_PROGRESS` status, `actualMinutes = 90`, and scheduler consumes `remainingMinutes = 30`. | `expect(progRes.body.status).toBe('IN_PROGRESS')`<br>`expect(progRes.body.actualMinutes).toBe(90)`<br>`expect(progRes.body.remainingMinutes).toBe(30)` |
| **2. Explicit Early Finished (35m on 60m est)** | Task marked `COMPLETED` immediately, `actualMinutes = 35`, `remainingMinutes = 0`, disruption event logged as `EARLY_COMPLETION`. | `expect(completeRes.body.status).toBe('COMPLETED')`<br>`expect(completeRes.body.completedMinutes).toBe(35)` |
| **3. Focus Timer + Need More Time** | Completing a 25m timer session logs 25m effort. Selecting Need More Time with 45m needed keeps actual effort at 25m (not 50m). | `expect(progressRes.body.actualMinutes).toBe(25)`<br>`expect(progressRes.body.remainingMinutes).toBe(45)` |
| **4. Idempotency & Retry Safety** | Repeated completion calls on the same timer session return HTTP 400 and do not duplicate minutes. | `expect(complete1.status).toBe(200)`<br>`expect(complete2.status).toBe(400)`<br>`expect(task.actualMinutes).toBe(20)` |
| **5. Partial Progress Preserved** | `remainingMinutes` stored in database persists across schedule regeneration and app reload. | `expect(progRes1.body.remainingMinutes).toBe(75)`<br>`expect(progRes2.body.remainingMinutes).toBe(45)` |
| **6. Completed Tasks Excluded** | Completed tasks with `remainingMinutes === 0` are excluded from candidate tasks in `schedule.service.ts`. | `expect(task1Blocks.length).toBe(0)` |
| **7. Legacy API Payload Safety** | Historical rows without `actualMinutes` or `remainingMinutes` resolve safely; legacy `{ completedMinutes: 35 }` updates work as expected. | `expect(legacyUpdateRes.body.completedMinutes).toBe(35)`<br>`expect(legacyUpdateRes.body.remainingMinutes).toBe(25)` |
| **8. Hard Constraints & Invariants Intact** | Sleep window, commitment blocks, deadline feasibility, user ownership (HTTP 404), and historical audit chains remain intact. | `expect(res.status).toBe(404)` (for cross-user attempts) |
