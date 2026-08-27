# Explainability Architecture

## Principles
1. **The Backend Decides**: Equilibrium does not use an LLM to decide schedules. 
2. **Flutter Explains**: Flutter does not reproduce scheduler mathematics. It visually mounts deterministic explanation arrays delivered by the DecisionLog.
3. **No Fakes**: Never hallucinate an optimization metric, "AI confidence score", or decision reason that does not exist directly in the `DecisionLog` emitted by the Operations Research solver.

## DecisionLog Architecture
Each time a schedule is generated (`/generate`) or rebuilt after disruption (`/reschedule`), the mathematical solver (`knapsack.ts`, `placement.ts`) logs precisely what happened to each Task.

The schema tracks:
* `decisionType`: `FULLY_SCHEDULED`, `PARTIALLY_SCHEDULED`, or `DEFERRED`.
* `reasonCode`: Explicit constants like `SUCCESS`, `FRAGMENTED_CAPACITY`, `CAPACITY_EXCEEDED`, `NO_AVAILABLE_SLOTS`.
* `priorityScore`: The exact output of the prioritization heuristics (Academic Weight, Load, Deadline pressure).
* `priorityComponentsJson`: The variables feeding that exact score.

## Flutter Data Flow (Lazy Loading)
Decision data is NOT eager-loaded when the schedule loads, because a schedule might contain hundreds of tasks.

1. User clicks the "Why was this scheduled?" button on a Task's detail sheet.
2. The `TaskDetailSheet` extracts the current `versionId` from the `ScheduleProvider`.
3. It mounts the `ExplanationSheet` stateful widget.
4. `ExplanationSheet` uses the `DecisionRepository` to perform a targeted `GET /api/v1/schedules/:versionId/decisions`.
5. It matches the response against its target `TaskId`.

## UI/UX Rules
* No glowing AI effects, robot avatars, or conversational chat interfaces. 
* Explanation is purely analytical, using Equilibrium tokens (`colors.success` for SCHEDULED, `colors.warning` for PARTIAL, `colors.danger` for DEFERRED).
* Semantic labels translate the database enums into full, screen-reader readable sentences (e.g., "Physics Assignment. FULLY SCHEDULED. Decision: High-priority work was placed within available capacity before the deadline.").

## Security
The `GET /api/v1/schedules/:id/decisions` endpoint strictly validates that the requesting `userId` owns the `ScheduleVersion` requested. 404 is thrown to mask the existence of schedules belonging to other users, preventing IDOR leaks.
