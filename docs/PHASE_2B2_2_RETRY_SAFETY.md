# Equilibrium Phase 2B.2.2: Persistent Idempotency & Retry Safety

## Executive Summary
Phase 2B.2.2 addresses critical data correctness and network reliability vulnerabilities in Equilibrium's task progress tracking and focus session completion. Previously, when a client submitted progress with incremental `additionalMinutes` or completed a timer session, a dropped HTTP response could cause the client to retry. Because the endpoints lacked persistent idempotency, retrying progress doubled cumulative actual effort and decremented remaining workload twice, while retrying timer completion resulted in an unhelpful HTTP 400 rejection (`Session is already COMPLETED`).

This phase implements persistent database-backed idempotency, conflict detection, concurrent race protection, and safe timer retry semantics across both the backend (`server/`) and Flutter client (`equilibrium_app/`).

---

## 1. Problem Analysis & Invariants

### 1.1 The Double-Increment Problem
In Phase 2B.2.1, task workload dimensions were cleanly separated into:
- `estimateMinutes`: Original baseline workload.
- `actualMinutes`: Cumulative actual effort spent.
- `remainingMinutes`: Estimated remaining work to be scheduled.

When the user records partial progress (`Made Progress`), the client sends incremental effort (e.g. `additionalMinutes: 30`). If the backend commits the database transaction but the network connection drops before the client receives HTTP 200:
1. The client catches a network error or timeout.
2. The user taps "Retry" or "Save Progress" again.
3. Without an idempotency mechanism, the backend applies `newActual = actualMinutes + additionalMinutes` a second time, inflating effort to 60 minutes and erroneously deducting another 30 minutes from `remainingMinutes`.

### 1.2 The Timer Completion Rejection Problem
In `focus-sessions.routes.ts`, `PATCH /api/v1/focus-sessions/:id/complete` previously rejected any request where `session.status === 'COMPLETED'` with HTTP 400. If the server finished completing the session and updating the linked task, but the response was interrupted in transit:
1. Flutter's `TimerProvider` caught an exception and displayed `'Could not complete session. Please try again.'`.
2. Upon user retry, the server returned HTTP 400, leaving the user permanently stuck in an error state with an active timer UI.

---

## 2. Architecture & Backend Implementation

### 2.1 Durable Storage: `TaskProgressOperation`
A new Prisma model `TaskProgressOperation` was introduced to persist operation executions with a database-level uniqueness guarantee:

```prisma
model TaskProgressOperation {
  id               String   @id @default(uuid())
  operationId      String   @unique
  userId           String
  taskId           String
  payloadHash      String
  responseBodyJson String
  createdAt        DateTime @default(now())

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)
  task Task @relation(fields: [taskId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@index([taskId])
}
```

### 2.2 Canonical Payload Hashing
To verify that a retried operation has not diverged from its original intent, `computePayloadHash` in `server/src/utils/task-workload.helper.ts` generates a SHA-256 digest over normalized workload fields:

```typescript
export function computePayloadHash(params: {
  completedMinutes?: number;
  additionalMinutes?: number;
  actualMinutes?: number;
  remainingMinutes?: number | null;
  newEstimateMinutes?: number;
  status?: string;
}): string {
  const canonical = {
    completedMinutes: params.completedMinutes ?? null,
    additionalMinutes: params.additionalMinutes ?? null,
    actualMinutes: params.actualMinutes ?? null,
    remainingMinutes: params.remainingMinutes ?? null,
    newEstimateMinutes: params.newEstimateMinutes ?? null,
    status: params.status ?? null,
  };
  return createHash('sha256').update(JSON.stringify(canonical)).digest('hex');
}
```

### 2.3 Atomic Progress & Completion Repository Handling
In `server/src/repositories/task.repo.ts`, `recordProgress` and `complete` now execute inside atomic Prisma transactions:
1. **Pre-Check**: If `operationId` is supplied, query `tx.taskProgressOperation.findUnique({ where: { operationId } })`.
   - **Match**: If `existingOp.payloadHash === payloadHash` and the operation belongs to the same user and task, parse and return `existingOp.responseBodyJson` immediately without re-mutating the task or schedule blocks.
   - **Mismatch**: If `operationId` was previously used with different parameters, a different task, or a different user, throw an error with `err.code = 'IDEMPOTENCY_CONFLICT'`, mapped by Express to HTTP 409.
2. **Workload Mutation**: Apply workload updates (preserving `remainingMinutes` if user indicates remaining work, updating `actualMinutes`).
3. **Persist Operation**: Save `tx.taskProgressOperation.create(...)`.
4. **Concurrency Race Protection**: If two concurrent requests race to create the same `operationId`, the database unique constraint throws Prisma error `P2002`. The catching block catches `P2002`, queries the committed record, validates the hash, and returns the response body, guaranteeing zero duplicated increments under concurrent execution.

### 2.4 Safe Timer Completion Retry
In `server/src/routes/focus-sessions.routes.ts`:
- If `session.status === 'COMPLETED'`, return HTTP 200 with the completed session (including task details) immediately.
- Re-check `current.status === 'COMPLETED'` inside the Prisma transaction to protect against concurrent execution races.
- If `session.status === 'DISCARDED'`, reject invalid transitions with HTTP 400.
- If `session` is not owned by the requesting user, return HTTP 404 (strictly preserving multi-tenant isolation).

---

## 3. Frontend Implementation (`equilibrium_app`)

### 3.1 Cryptographically Secure UUIDv4 Generator
Created `equilibrium_app/lib/core/utils/uuid_generator.dart` generating RFC 4122 version 4 UUIDs using Dart's `Random.secure()` without third-party dependencies:
- Sets version 4 (`(byte & 0x0f) | 0x40`).
- Sets variant 1 (`(byte & 0x3f) | 0x80`).
- Formats 36-character lowercase hex string compatible with backend `z.string().uuid()` validation.

### 3.2 TaskProgressDialog Lifecycle & Retry Preservation
In `equilibrium_app/lib/widgets/dialogs/task_progress_dialog.dart`:
- **Active Operation ID**: Tracks `_activeOperationId`.
- **First Attempt**: When user presses "Save Progress" or "Confirm Task Finished", initializes `_activeOperationId ??= generateUuidV4()` and forwards it to the provider and API.
- **Retry on Network Failure**: If the request fails, `_isSubmitting` is set to `false`, `_errorMessage` is displayed, but `_activeOperationId` and text inputs are preserved intact. When the user taps submit again, the exact same `operationId` is reused.
- **Genuine New Action Invalidation**: If the user modifies any text input (`addListener`), switches actions, or dismisses the dialog, `_activeOperationId` is reset to `null` so genuine subsequent submissions receive fresh UUIDs.

### 3.3 Provider and Repository Propagation
- `TaskRepository`: Updated `completeTask(id, [actualMinutes, operationId])` and `recordProgress(id, { ..., operationId })` to forward `operationId` in the JSON request body.
- `ScheduleProvider`: Updated `completeTask` and `recordTaskProgress` to accept and pass `operationId`.
- `TimerProvider`: When retrying `completeSession()`, it now receives HTTP 200 on already-completed sessions, successfully resetting `_activeSession` and adding the session to history without stuck states.

---

## 4. Database Migration & Rollback Strategy

### 4.1 Additive Migration File
Located at `server/prisma/migrations/20261024150000_add_task_progress_operation/migration.sql`:
```sql
-- CreateTable
CREATE TABLE "TaskProgressOperation" (
    "id" TEXT NOT NULL,
    "operationId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "taskId" TEXT NOT NULL,
    "payloadHash" TEXT NOT NULL,
    "responseBodyJson" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TaskProgressOperation_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "TaskProgressOperation_operationId_key" ON "TaskProgressOperation"("operationId");

-- CreateIndex
CREATE INDEX "TaskProgressOperation_userId_taskId_idx" ON "TaskProgressOperation"("userId", "taskId");

-- CreateIndex
CREATE INDEX "TaskProgressOperation_operationId_idx" ON "TaskProgressOperation"("operationId");

-- AddForeignKey
ALTER TABLE "TaskProgressOperation" ADD CONSTRAINT "TaskProgressOperation_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TaskProgressOperation" ADD CONSTRAINT "TaskProgressOperation_taskId_fkey" FOREIGN KEY ("taskId") REFERENCES "Task"("id") ON DELETE CASCADE ON UPDATE CASCADE;
```

### 4.2 Safe Forward Deployment Order
To ensure zero downtime and prevent race conditions between mobile clients and the backend:
1. **Database Snapshot / Backup**: Take a standard snapshot or point-in-time recovery backup of the PostgreSQL database.
2. **Apply Additive Migration**: Run `npx prisma migrate deploy` in the deployment pipeline. Because the migration only introduces a new independent table, unique index, and foreign keys, it executes without locking or modifying existing `Task` or `User` records.
3. **Deploy Backward-Compatible Backend**: Deploy the new backend container images. Because `operationId` is optional in the validation schemas and task repository, legacy client requests without `operationId` proceed smoothly without regression.
4. **Health & Idempotency Smoke Test**: Execute container health checks and verify the reconciliation route (`GET /api/v1/tasks/:id/operations/:operationId`) returns expected status before routing live traffic.
5. **Mobile Client Release**: Roll out the updated Flutter application build with `PendingOperationManager` and ambiguous retry recovery to app stores.

### 4.3 Coordinated Rollback & Forward-Repair Runbook

> [!CAUTION]
> **NEVER DROP TABLE WHILE APPLICATION CODE REFERENCES IT**
> Do **NOT** execute `DROP TABLE IF EXISTS "TaskProgressOperation" CASCADE;` while an application version referencing `taskProgressOperation` is live or restarting. Doing so immediately causes Prisma queries to fail with PostgreSQL error `42P01: relation "TaskProgressOperation" does not exist`, resulting in runtime HTTP 500 errors on task progress and completion endpoints.

#### Procedure for Severe Backend Regression:
1. **Revert Backend Container Image**: Revert the container or service deployment to the previous known-good image.
2. **Retain Database Table Intact**: Leave `TaskProgressOperation` in PostgreSQL. Since the migration was purely additive, previous application code versions that do not query `TaskProgressOperation` operate completely normally alongside the unused table.
3. **Prioritize Forward-Repair**: Deploy forward hotfixes to resolve any edge-case logic or race conditions rather than modifying database DDL in panic situations.
4. **Controlled Decommissioning (If Permanently Deprecated)**:
   - Phase 1: Deploy application version with all `taskProgressOperation` references removed.
   - Phase 2: Verify zero active containers run the old code.
   - Phase 3: In a planned maintenance window, deploy a new Prisma migration containing `DROP TABLE "TaskProgressOperation";`.

---

## 5. Verification & Test Results

### 5.1 Backend Verification (`server/`)
1. **Jest Test Suite**:
   ```bash
   npm test
   ```
   - **Result**: 8 test suites passed, 92 tests passed (0 failed).
   - Covered scenarios:
     - First progress submission records operation and updates task.
     - Simulated response loss retry returns identical HTTP 200 response without double-counting `actualMinutes` or `remainingMinutes`.
     - Conflicting payload with same `operationId` returns HTTP 409 `IDEMPOTENCY_CONFLICT`.
     - Different task with same `operationId` returns HTTP 409.
     - Concurrent duplicate submissions (`Promise.all`) succeed with identical body and no race condition.
     - Genuinely new subsequent progress with fresh `operationId` increments effort correctly.
     - User-indicated remaining minutes preserved independently of elapsed effort.
     - Task completion with `operationId` idempotent across retries.
     - Focus session completion retry returns HTTP 200 without duplicate effort.
     - Invalid session transition (`DISCARDED`) returns HTTP 400.
2. **TypeScript Compilation**:
   ```bash
   npx tsc --noEmit
   ```
   - **Result**: Exited with code 0 (0 compilation or type errors).

### 5.2 Frontend Verification (`equilibrium_app/`)
1. **Flutter Tests**:
   ```bash
   flutter test
   ```
   - **Result**: All 53 tests passed (0 failed).
   - Dedicated Phase 2B.2.2 tests:
     - `generateUuidV4` produces valid RFC 4122 v4 UUIDs across 500 distinct generations.
     - `Made Progress` generates `operationId` and forwards it to `ScheduleProvider`.
     - Retrying submission after failure reuses the exact same `operationId` and preserves form inputs.
     - Modifying an input field invalidates `operationId` so the next submission generates a fresh ID.
2. **Flutter Static Analysis**:
   ```bash
   flutter analyze --fatal-infos --fatal-warnings
   ```
   - **Result**: `No issues found! (ran in 5.0s)` (0 errors, 0 warnings, 0 infos).

---

## 6. Summary of Verified vs. Unverified Outcomes

| Outcome | Status | Verification Evidence |
|---|---|---|
| Incremental `additionalMinutes` idempotent across retries | **VERIFIED** | Jest regression tests with simulated dropped response verify `actualMinutes` is only incremented once. |
| Conflicting payload rejected with HTTP 409 | **VERIFIED** | Jest regression test explicitly asserts HTTP 409 `IDEMPOTENCY_CONFLICT`. |
| Concurrent requests safe against race conditions | **VERIFIED** | Jest `Promise.all` test and fake-prisma unique constraint verify single execution. |
| Completed timer session safe to retry | **VERIFIED** | Focus-session route test verifies HTTP 200 on retry without duplicate minutes. |
| Invalid focus session transitions rejected | **VERIFIED** | Attempting to complete a DISCARDED session verified to return HTTP 400. |
| Flutter reuses `operationId` on retry without input loss | **VERIFIED** | Flutter widget test simulates failure, asserts inputs preserved, and verifies identical ID reused. |
| Input modification produces new `operationId` | **VERIFIED** | Flutter widget test changes input text and verifies different UUID generated. |
| Sleep, scheduling, and onboarding constraints intact | **VERIFIED** | All 53 Flutter tests and 92 server regression tests pass with 0 regressions. |
| Production Postgres migration execution | **UNVERIFIED (By Design)** | Migration created and tested against local `@prisma/client` and fake Prisma; production databases were strictly NOT accessed or deployed per safety requirements. |
