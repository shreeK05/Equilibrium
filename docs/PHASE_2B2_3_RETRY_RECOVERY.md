# Phase 2B.2.3: Ambiguous Retry Recovery, Persistent Idempotency & Safe Migration Rollback

**Date**: October 2026  
**Status**: Implemented & Verified  
**Scope**: Server Idempotency Recovery (`server/src/repositories/task.repo.ts`, `server/src/routes/tasks.routes.ts`), Flutter Client Retry Hardening (`PendingOperationManager`, `ScheduleProvider`, `TaskProgressDialog`), Migration Rollback Guidance Corrections (`docs/PHASE_2B2_2_RETRY_SAFETY.md`).

---

## 1. Problem Analysis & Core Challenges

In Phase 2B.2.2, persistent idempotency was established by recording a unique `operationId` in `TaskProgressOperation`. However, two critical edge cases remained:

1. **Ambiguous Network Outcome & Client Confusion**:
   When a mobile client sends a progress or completion request, a timeout, socket reset, or server crash can occur *after* the backend transaction has successfully committed to PostgreSQL, but *before* the client receives the HTTP response.
   - If the client treats this as a regular transient error, allowing the user to edit inputs or re-submit with a newly generated `operationId`, the backend applies the update a second time, double-counting logged effort.
   - If the dialog is dismissed or the app process restarts while an operation is in-flight or ambiguous, client state could be wiped out, losing tracking of the pending operation ID.

2. **PostgreSQL Interactive Transaction Abort State (`25P02`)**:
   Under PostgreSQL, when an interactive Prisma transaction (`prisma.$transaction(async (tx) => { ... })`) encounters a unique constraint violation (`P2002` on `"TaskProgressOperation_operationId_key"` due to a concurrent duplicate submission), the entire transaction enters an aborted state with SQL error `25P02: current transaction is aborted, commands ignored until end of transaction block`.
   - Attempting to query `tx.taskProgressOperation.findUnique` inside the transaction catch block will fail with `25P02`.
   - The transaction must be allowed to abort and roll back completely, and the recovery query must execute outside the aborted transaction against `prisma.taskProgressOperation.findUnique`.

3. **Hazardous Migration Rollback Advice**:
   Section 4.3 in `docs/PHASE_2B2_2_RETRY_SAFETY.md` previously suggested running `DROP TABLE IF EXISTS "TaskProgressOperation" CASCADE;` during an emergency rollback. If executed while active application instances still query the table, all task completions and progress operations would immediately throw PostgreSQL error `42P01` (`relation "TaskProgressOperation" does not exist`), causing severe service downtime.

---

## 2. Backend Architecture & Implementation

### 2.1 Post-Rollback Idempotency Recovery (`withIdempotencyRecovery`)
In `server/src/repositories/task.repo.ts`:
```typescript
async function withIdempotencyRecovery<T>(
  operationId: string | undefined,
  userId: string,
  taskId: string,
  payloadHash: string,
  txFn: () => Promise<T>
): Promise<T> {
  try {
    return await txFn();
  } catch (err: any) {
    if (operationId && (err.code === 'P2002' || err.message?.includes('P2002') || err.message?.includes('Unique constraint'))) {
      const committed = await prisma.taskProgressOperation.findUnique({ where: { operationId } });
      if (committed) {
        if (committed.userId !== userId || committed.taskId !== taskId || committed.payloadHash !== payloadHash) {
          const conflictErr: any = new Error('Operation ID was already used with a conflicting payload');
          conflictErr.code = 'IDEMPOTENCY_CONFLICT';
          throw conflictErr;
        }
        return JSON.parse(committed.responseBodyJson) as T;
      }
    }
    throw err;
  }
}
```
- **PostgreSQL Safety**: When a concurrent duplicate race occurs, `txFn()` aborts cleanly. The outer `withIdempotencyRecovery` catches the `P2002` error, issues a fresh query to `prisma.taskProgressOperation.findUnique`, validates payload hash equality, and returns the committed response without duplicating mutations or creating extra disruption events.

### 2.2 Authenticated Operation Status Reconciliation Endpoint
In `server/src/routes/tasks.routes.ts`:
- **Route**: `GET /api/v1/tasks/:id/operations/:operationId`
- **Controller/Repo**: `taskRepo.findOperation(operationId, taskId, userId)`
- **Behavior**:
  - Validates user ownership (`op.userId === req.userId`) and task correlation (`op.taskId === req.params.id`).
  - Returns HTTP 200 with `{ operationId, taskId, payloadHash, result, createdAt }`.
  - Returns HTTP 404 with code `OPERATION_NOT_FOUND` if unknown or uncommitted.
  - Prevents cross-user reconnaissance or tampering by returning 404 for unauthorized probes.

---

## 3. Frontend Architecture & Recovery Workflow

### 3.1 Definite Rejection vs. Ambiguous Failure Differentiation
In `equilibrium_app/lib/core/api/api_client.dart`:
```dart
extension ApiExceptionClassification on ApiException {
  /// Definite rejection: server evaluated and rejected the request without mutation.
  bool get isDefiniteRejection =>
      statusCode == 400 || statusCode == 401 || statusCode == 403 ||
      statusCode == 404 || statusCode == 409 || statusCode == 422;

  /// Ambiguous failure: request may have committed before connection dropped or crash.
  bool get isAmbiguous =>
      statusCode == 0 || code == 'NETWORK_ERROR' ||
      statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504;
}
```

### 3.2 Persistent Local Storage (`PendingOperationManager`)
In `equilibrium_app/lib/core/services/pending_operation_manager.dart`:
- Persists pending operations to `SharedPreferences` under key `pending_progress_op_$taskId`.
- **Zero Secrets / Zero Sensitive Data**: Stores only `taskId`, `operationId`, `action`, workload minute integers, `status`, and `timestamp`. No JWT tokens, passwords, or personal notes are written.
- Saved **before** making the network request; cleared **only** after confirmed success or definite rejection.

### 3.3 TaskProgressDialog Lifecycle & Input Locking
In `equilibrium_app/lib/widgets/dialogs/task_progress_dialog.dart`:
- **State Restoration**: `initState()` calls `_checkAndRestorePendingOperation()`. If an ambiguous operation is pending in storage, it restores the form action and values, locks inputs (`enabled: !_isSubmitting && !_isAmbiguous`), and sets `_isAmbiguous = true`.
- **Recovery Banner**: Displays a distinct warning banner alerting the user that the operation outcome is unconfirmed.
- **Action Locking**: Disables action switching and back navigation while an ambiguous operation is pending.
- **Reconciliation / Retry Button**: Renders a dedicated `"Retry Pending Update"` button:
  1. Probes `getTaskOperation(taskId, operationId)` to check if the server already committed.
  2. If found, reconciles immediately without repeating mutations.
  3. If not found (404), replays the request with the identical `operationId` and payload.

---

## 4. Verification & Regression Coverage

### 4.1 Backend Verification (`server/`)
Executed via `npm test` and `npx tsc --noEmit`:
- **Result**: 8 test suites passed, 98 tests passed (0 failed).
- **TypeScript**: `tsc --noEmit` exited code 0.
- **Phase 2B.2.3 Tests Added**:
  1. `Operation reconciliation endpoint GET /tasks/:id/operations/:operationId allows safe status query`:
     - Verifies 404 for uncommitted operationId.
     - Verifies 200 with result payload for committed operationId.
     - Verifies 404 for unauthorized user access attempt.
  2. `Late duplicate race recovery`:
     - Verifies simulated P2002 duplicate rollback retrieves committed record cleanly.
  3. `Conflicting payload with identical operationId`:
     - Verifies HTTP 409 `IDEMPOTENCY_CONFLICT` returned without corrupting task state.
  4. `Deduplication of completion disruptions`:
     - Verifies duplicate completion replay does not generate extraneous disruption events.
  5. `Post-reconciliation subsequent progress`:
     - Verifies fresh operationId after confirmed reconciliation increments effort exactly once.

### 4.2 Frontend Verification (`equilibrium_app/`)
Executed via `flutter test` and `flutter analyze`:
- **Result**: 19 tests in `test/phase_2b2_progress_test.dart` passed (0 failed). 18 tests in `test/phase_2b1_correctness_test.dart` passed.
- **Analysis**: `flutter analyze --fatal-infos --fatal-warnings` returned 0 issues.
- **Phase 2B.2.3 Tests Added**:
  1. `Ambiguous network failure locks inputs, shows recovery banner, and preserves operationId in SharedPreferences`.
  2. `Reopening dialog for task with ambiguous pending operation restores pending state and locks inputs`.
  3. `Tapping "Retry Pending Update" reconciles server commit via getTaskOperation without re-running progress`.
  4. `Definite validation rejection (HTTP 400) clears pending lock and keeps inputs editable for user correction`.
  5. `Subsequent progress submission after confirmed success generates a fresh operationId`.

---

## 5. Test Limitations & Real PostgreSQL Concurrency Guidance

> [!NOTE]
> **Distinction Between Fake / In-Memory Tests and Real PostgreSQL Concurrency**
> - The unit and integration tests in `server/test/helpers/fake-prisma.ts` execute against an in-memory database simulation that models PostgreSQL table constraints, interactive transaction rollbacks, and deep-copy state rollbacks.
> - While this faithfully verifies code paths and catch-block recovery semantics, true PostgreSQL multi-process concurrency (e.g. MVCC row locking, connection pool saturation, write-skew, and distributed deadlocks) should be validated in a multi-container staging environment connected to a real PostgreSQL instance under load testing prior to high-volume production deployments.

---

## 6. Coordinated Deployment & Rollback Protocol

1. **Backup**: Automated snapshot of PostgreSQL cluster.
2. **Additive Migration**: `npx prisma migrate deploy` creates `TaskProgressOperation`.
3. **Backend Deployment**: Roll out updated backend containers (backward-compatible).
4. **Health Check**: Verify `GET /api/v1/tasks/:id/operations/:operationId` connectivity.
5. **Client Release**: Release Flutter app build with `PendingOperationManager`.
6. **Rollback Rule**: In case of severe backend regression, revert container images; **never drop the table** while live or restarting application instances reference it.
