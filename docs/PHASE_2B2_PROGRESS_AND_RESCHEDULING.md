# Equilibrium Phase 2B.2: Trustworthy Task Progress, Completion & User-Guided Adaptive Rescheduling

## 1. Executive Summary & Objective

In university student academic planning, estimates are inherently imperfect. An assignment estimated at 60 minutes may take 35 minutes (finished early) or 95 minutes (overrun). Students frequently work in focus sessions where they make partial progress without completing the entire task, or realize they need more time than originally estimated.

Prior to Phase 2B.2, the system exhibited several severe progress and scheduling flaws:
1. **Blind Completion & Fabricated Effort**: Tapping Done on `TodayScreen` immediately called `completeTask(task.id, task.estimateMinutes)`. It forced `completedMinutes` to equal `estimateMinutes` without confirmation, falsifying actual study effort and giving students no way to log partial work.
2. **Repository Reversion Bug**: In `task.repo.ts`, `safeUpdate` explicitly overrode `status: 'COMPLETED'` back to `'IN_PROGRESS'` whenever `completedMinutes < estimateMinutes`, preventing students from marking tasks completed if they finished early.
3. **Double-Counting & Lost Effort**: Focus sessions clamped `completedMinutes` to `estimateMinutes`, discarding student effort exceeding the estimate.
4. **Rescheduling Without Past Protection**: Rescheduling called `getLockedBlocks()` (which only checked `isLocked: true`). Because past blocks and completed blocks were never flagged as locked, rescheduling could wipe past blocks or reallocate already-completed work into the past.
5. **No Guided Adaptive Re-planning**: Students had to switch tabs to find the reschedule button; after rescheduling, no truthful summary was provided, and the UI could falsely claim all tasks fit even when the knapsack solver deferred tasks due to capacity limits.

Phase 2B.2 establishes **one trustworthy, consistent progress model** across the backend (`server/`) and Flutter client (`equilibrium_app/`), introduces the **TaskProgressDialog** with 4 clear actions (Finished, Made Progress, Need More Time, Not Now), locks historical and completed blocks during rescheduling, and provides a truthful re-planning summary that explicitly reports deferred tasks.

---

## 2. Progress Model & Data Semantics

### 2.1 The Four Execution Actions
When a student interacts with a scheduled or active task (from `TodayScreen` or `TaskDetailSheet`), the system offers a non-blocking confirmation dialog rather than immediately setting status complete:

| Action | Meaning & Data Updates | Schedule Impact |
| :--- | :--- | :--- |
| **Finished** | Task is fully completed. Records actual minutes spent (`actualMinutes` $\ge 0$). Does not force actual effort to match estimate. Status set to `COMPLETED`. Marks latest schedule blocks for this task as `isCompleted: true`. | Completed task excluded from future rescheduling. History preserved. |
| **Made Progress** | Student worked in this session (`additionalMinutes` $> 0$). Increments `completedMinutes` by the session duration without completing the task. Status remains `IN_PROGRESS`. | Remaining workload (`estimateMinutes - completedMinutes`) stays scheduled or active. Student can optionally trigger re-planning. |
| **Need More Time** | Student worked or realized task is bigger than expected. Records optional session minutes worked and sets `newEstimateMinutes` = `completedMinutes + sessionMinutes + additionalNeeded`. Status remains `IN_PROGRESS`. | Automatically triggers adaptive re-planning to place the additional workload into future available slots. |
| **Not Now** | Student cancels dialog or defers action. Leaves task completely unchanged. | No API calls, no database mutations, task remains scheduled. |

### 2.2 Preserving Actual Effort Without Double-Counting
- When a timer completes (`PATCH /api/v1/focus-sessions/:id/complete`), it calculates `additionalMinutes = Math.round(finalElapsed / 60)` and increments `task.completedMinutes += additionalMinutes`. Actual minutes are not clamped to `estimateMinutes`.
- If the student subsequently opens the progress dialog, the prefilled actual time reflects what was already logged. The student can adjust or confirm total actual time without double-counting elapsed focus sessions.
- In `task.repo.ts`, `complete(id, actualMinutes)` records `actualMinutes` directly if provided, or retains the accumulated `completedMinutes` if omitted. If `Math.abs(actualMinutes - estimateMinutes) > 10`, a `DisruptionEvent` is safely recorded (`EARLY_COMPLETION` or `OVERRUN`).

---

## 3. Backend Implementation & API Contracts

### 3.1 Zod Validation Schemas (`server/src/validation/schemas.ts`)
```typescript
export const taskCompletionSchema = z.object({
  actualMinutes: z.number().int().min(0).max(10000).optional(),
});

export const taskProgressSchema = z.object({
  completedMinutes: z.number().int().min(0).max(10000).optional(),
  additionalMinutes: z.number().int().min(1).max(10000).optional(),
  newEstimateMinutes: z.number().int().min(1).max(10000).optional(),
  status: z.enum(['PENDING', 'IN_PROGRESS', 'COMPLETED']).optional(),
}).refine(
  data => data.completedMinutes !== undefined || data.additionalMinutes !== undefined || data.newEstimateMinutes !== undefined || data.status !== undefined,
  { message: 'At least one progress update field must be provided' }
);
```

### 3.2 Task Repository Correctness (`server/src/repositories/task.repo.ts`)
- **Fix in `safeUpdate`**:
  ```typescript
  if (data.status === 'COMPLETED') {
    derivedStatus = 'COMPLETED';
  } else if (newCompleted >= newEstimate && newEstimate > 0) {
    derivedStatus = 'COMPLETED';
  } else if (newCompleted > 0) {
    derivedStatus = 'IN_PROGRESS';
  }
  ```
  Status `COMPLETED` is now honored even if `completedMinutes < estimateMinutes`.
- **`complete(userId, id, actualMinutes)`**:
  - Validates user ownership (returns 404 if not found or unauthorized).
  - Idempotent: if already completed, returns existing task without duplicating disruption events.
  - Updates latest version blocks for this task to `isCompleted: true`.
- **`recordProgress(userId, id, progress)`**:
  - Supports incremental `additionalMinutes` or absolute `completedMinutes`.
  - Supports workload extension (`newEstimateMinutes`).
  - Sets status `COMPLETED` if total completed $\ge$ estimate, or retains `IN_PROGRESS`.

### 3.3 Adaptive Rescheduling Protection (`server/src/services/schedule.service.ts`)
During rescheduling, blocks from the prior schedule version that satisfy:
$$\text{isLocked} = \text{true} \quad \lor \quad \text{isCompleted} = \text{true} \quad \lor \quad \text{endTime} \le \text{now}$$
are automatically locked in place.
- Past focus blocks are protected against being overwritten or moved into the past.
- Completed tasks are excluded from knapsack candidate placement.
- Incomplete workload from active tasks is rescheduled into future available capacity.
- Decision logs record `FULLY_SCHEDULED`, `PARTIALLY_SCHEDULED`, or `DEFERRED` for every candidate task.

---

## 4. Frontend Implementation (`equilibrium_app/`)

### 4.1 ReplanSummary Model & ScheduleProvider (`schedule_provider.dart`)
```dart
class ReplanSummary {
  final int scheduledTaskCount;
  final int totalScheduledMinutes;
  final int deferredTaskCount;
  final List<String> deferredTaskTitles;
  final bool hasDeferred;
  final String userMessage;
}
```
- `ScheduleProvider.reschedule()` guards against duplicate or concurrent calls (`if (isLoading || currentSchedule == null) return null;`).
- Analyzes `newVersion.decisionLogs` for `DecisionType.deferred`.
- Truthfully computes `deferredTaskCount` and names of deferred tasks.
- Returns user-facing summary:
  - If deferred: `"Re-planned: X min scheduled. Y task(s) deferred (Title A, Title B) due to capacity."`
  - If all fit: `"Schedule updated: X min planned across Z tasks."`
  - Never falsely claims all tasks fit when any task was deferred.

### 4.2 Interactive Task Progress Dialog (`widgets/dialogs/task_progress_dialog.dart`)
- Modal bottom sheet with clean Material 3 surface styling.
- Clearly displays task title, logged minutes, and remaining workload.
- Inline validation prevents negative or non-positive durations.
- Button states display circular progress indicator while submitting to prevent repeated taps.
- API save failures display a non-dismissing, readable error banner.

### 4.3 TodayScreen & TaskDetailSheet Integration
- **`TodayScreen`**:
  - Replaced immediate completions with `_handleTaskDone` on Hero card, Up Next, Needs Attention, and Today's Tasks.
  - Added a direct "Re-plan remaining day" text button next to the `WorkloadMeter`.
  - Displays formatted SnackBar summaries on reschedule and task progress.
- **`TaskDetailSheet`**:
  - Added "Record Progress / Complete" button triggering `TaskProgressDialog`.
  - Preserves slider manual adjustment and updates task without fabricated completion.

---

## 5. Verification & Test Results

### 5.1 Backend Automated Tests (`server/test/`)
Commands executed:
- `npm test`
- `npx tsc --noEmit`

Test Suites: **8 passed, 8 total**  
Tests: **81 passed, 81 total**  
Snapshots: **0 total**  
Time: **2.636s**  
TypeScript Error Count: **0 errors**

Key Phase 2B.2 tests verified in `test/regression.task-progress-reschedule.test.ts`:
1. Early completion (`actual < estimate`) retains status `COMPLETED`, records exact actual minutes, and logs `EARLY_COMPLETION` disruption.
2. Overrun completion (`actual > estimate`) retains status `COMPLETED`, records exact actual minutes, and logs `OVERRUN` disruption.
3. Repeated completion calls are idempotent and do not create duplicate disruption events.
4. Partial progress increments `completedMinutes` and preserves remaining workload.
5. Workload extension (`Need More Time`) increases `estimateMinutes` while retaining `IN_PROGRESS` status.
6. Multi-tenant ownership enforcement rejects completion or progress requests from unauthorized users with 404.
7. Rescheduling locks past and completed blocks, excludes completed tasks, and preserves the schedule audit chain (`previousVersionId`).
8. Knapsack capacity overflow produces truthful `DEFERRED` decision logs for tasks that cannot fit.

### 5.2 Flutter Automated Tests (`equilibrium_app/test/`)
Commands executed:
- `flutter test`
- `flutter analyze --fatal-infos --fatal-warnings`

Test Suites: **6 passed, 6 total**  
Tests: **47 passed, 47 total**  
Flutter Analyzer Status: **No issues found! (ran in 2.0s, 0 warnings, 0 infos)**

Key Phase 2B.2 tests verified in `test/phase_2b2_progress_test.dart`:
1. `Finished` option records exact actual minutes, calls `completeTask`, and updates task status.
2. `Made Progress` records incremental minutes, keeps unfinished workload active, and updates remaining workload.
3. `Need More Time` increases estimate and triggers adaptive rescheduling.
4. `Not Now` dismisses dialog with `null` without invoking APIs or modifying state.
5. Input validation rejects non-positive or invalid minutes with inline error messages.
6. API save failures retain dialog state and display inline error banner without crashing.
7. `ReplanSummary` truthfully reports deferred tasks when workload cannot fit, never falsely claiming all tasks fit.
8. `ReplanSummary` reports complete fit when all tasks fit within capacity.

---

## 6. Acceptance Criteria Verification Matrix

| Acceptance Criterion | Verification Method | Result |
| :--- | :--- | :--- |
| **Partial progress is preserved** | Backend `recordProgress` and Flutter dialog `Made Progress` | **PASSED** (active tasks retain remaining minutes) |
| **Actual effort is not double-counted** | Timer session routes, task completion, and manual logging | **PASSED** (exact actual minutes recorded, not forced to estimate) |
| **Completed tasks cannot reappear as active** | Backend `schedule.service.ts` locks completed blocks and excludes completed tasks | **PASSED** (verified in integration tests) |
| **Rescheduling preserves history & hard constraints** | `oldVersion.blocks` where `isLocked \|\| isCompleted \|\| endTime <= now` locked; sleep windows and commitments protected | **PASSED** (verified in scheduler tests) |
| **Truthful explanation of schedule changes** | `ReplanSummary` inspects `DecisionLog` for deferred tasks | **PASSED** (explicitly names deferred tasks, never claims all fit when deferred) |
| **Consistency across UI surfaces** | `TodayScreen` cards and `TaskDetailSheet` use unified flow | **PASSED** (both trigger `TaskProgressDialog` and handle replan summaries) |

---

## 7. Limitations & Production Safety Notice

1. **Local Safe Mocking Only**: All backend tests run against the safe in-memory database mock (`fake-prisma.ts`). No production database was accessed, modified, or migrated.
2. **Database Migrations**: No schema alterations were required. Existing Prisma models (`Task`, `ScheduleBlock`, `DisruptionEvent`, `FocusSession`, `DecisionLog`) were sufficient to support the progress model. No production migrations were run.
3. **Physical Device Behaviors**: While all widget interactions, animations, modal transitions, and API error states pass automated Flutter tests, physical touch latency and OEM background notification scheduling on low-end Android/iOS hardware remain subject to on-device validation during Phase 4 staging.
