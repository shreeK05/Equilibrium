# Rescheduling UI & Disruption Experience

Equilibrium gracefully surfaces schedule mutations without relying on mock data or hallucinatory UI.

## Architecture

1. **Trigger**: The user initiates a disruption rebuild via the `Reschedule` Floating Action Button (FAB).
2. **Provider**: `ScheduleProvider.reschedule()` captures the existing `currentSchedule` into `previousSchedule`, then triggers the API.
3. **API**: `POST /api/v1/schedules/:versionId/reschedule` executes the mathematical solver, locking past chunks and generating a new `ScheduleVersion`.
4. **Change Summary**: The UI automatically mounts the `ChangeSummaryBanner` since `previousSchedule` exists and `currentSchedule.previousVersionId` matches it.

## Change Summary Calculation
Instead of querying separate endpoints or hallucinating changes, the `ChangeSummaryBanner` evaluates the payload directly:
- **Moved Tasks**: Compares the earliest `startTime` of a specific task across `previousSchedule.blocks` vs `currentSchedule.blocks`.
- **Deferred Tasks**: Counts `DecisionLog` entries where `decisionType == DEFERRED`.
- **Partially Scheduled**: Counts `DecisionLog` entries where `decisionType == PARTIALLY_SCHEDULED`.

## Task Detail Enrichment
The `TaskDetailSheet` dynamically intercepts the current `ScheduleVersion` out of the provider to sum actual placed chunks (`durationMinutes`) for the specific `taskId` to present the exact "Scheduled time" the math engine allocated.

This strict adherence to backend-driven UI ensures Equilibrium remains mathematically trustworthy.
