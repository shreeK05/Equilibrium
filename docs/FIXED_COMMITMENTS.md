# Fixed Commitments

Equilibrium treats scheduled events (classes, labs, recurring meetings) as **Hard Constraints**.

## The Philosophy
Traditional planners place tasks and meetings side by side. Equilibrium places tasks **around** commitments.
Fixed commitments are structurally treated identically to the Sleep Shield.

## Data Model
`FixedCommitment`
- `startTime`: Exact ISO string
- `endTime`: Exact ISO string
- `type`: Enum (CLASS, LAB, EXAM, PERSONAL, CUSTOM)
- `isActive`: Boolean flag

## Integration with Scheduler
1. **Capacity Extraction**: Before the Knapsack algorithm runs, the `capacity.ts` module generates 30-minute available capacity slots.
2. **Intersection**: It runs an `intervalsIntersect` check against every active `FixedCommitment`.
3. **Availability**: If a slot intersects a fixed commitment, `slot.available = false`.
4. **Validation**: The final `validator.ts` pass guarantees that no generated `ScheduleBlock` overlaps with any Fixed Commitment.

## API Endpoints
- `POST /api/v1/commitments`: Create new
- `GET /api/v1/commitments`: List active
- `PATCH /api/v1/commitments/:id`: Modify
- `DELETE /api/v1/commitments/:id`: Remove (frees up capacity for the next schedule run)
