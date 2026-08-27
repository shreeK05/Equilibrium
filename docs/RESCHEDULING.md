# Autonomous Rescheduling

Equilibrium reacts to disruptions without destroying history.

## The Rescheduling Lifecycle

When a disruption occurs (e.g., Task finished early/late, New fixed commitment added, Capacity reduced):

1. **State Update**: The database records the raw reality (e.g., `Task.completedMinutes` is updated).
2. **Reschedule Trigger**: The client calls `POST /api/v1/schedules/:versionId/reschedule`.
3. **History Extraction**: The backend fetches all `isLocked=true` blocks from the old `ScheduleVersion`. These represent time that has already passed and work that was already executed.
4. **Capacity Re-evaluation**: New capacity is generated for the remaining horizon (from `now` -> +7 days).
5. **Re-Optimization**: The 0/1 Knapsack problem is solved again for the *remaining* duration of active tasks.
6. **New Version**: A *new* `ScheduleVersion` is created.
7. **Lineage Linking**: The new version stores `previousVersionId = old.id` and `triggerType = 'DISRUPTION'`.
8. **Explainability**: New `DecisionLog`s are attached to explain the state of the new schedule.

## Immutable Past
The scheduler strictly protects the past. Blocks that occurred before `now` are locked. The mathematical solver treats locked blocks identically to fixed commitments—it places future capacity around them.

## Types of Disruptions Supported
- **Task Completed Early**: Remaining estimate drops, freeing up future capacity.
- **Task Overrun**: Remaining estimate increases, potentially triggering deferred logs for lower priority tasks.
- **Skipped Block**: The task didn't gain `completedMinutes`, so its remaining duration stays high, and it will be pushed forward.
