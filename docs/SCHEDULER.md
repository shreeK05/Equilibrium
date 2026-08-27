# Equilibrium Scheduling Engine Specification

This document explicitly defines the determinism, mathematical models, and pipeline of the Equilibrium Scheduling Engine.

## 1. Input Models & Durations
To correctly handle task lifecycles, the engine explicitly distinguishes between four duration states:
1. **Estimated Task Duration**: The initial total effort defined by the user (e.g., 4h).
2. **Completed Duration**: The time historically executed and locked as finished (e.g., 2h).
3. **Remaining Task Duration**: `max(0, Estimated - Completed)`. This is the workload that actually enters the scheduler (e.g., 2h).
4. **Scheduled Duration**: The sum of block durations actively placed in the current `ScheduleVersion`.

### Task Input Model
- `id`: UUID
- `estimateMinutes`: Integer
- `completedMinutes`: Integer
- `academicWeight`: Float [0.0 - 1.0]
- `teamImpact`: Float [0.0 - 1.0]
- `cognitiveLoad`: Enum (LOW, MEDIUM, HIGH)
- `deadline`: ISO-8601 Timestamp
- `deferralCount`: Integer (Schedule Debt)

### Fixed Commitment Model
- `startTime`: ISO-8601 Timestamp
- `endTime`: ISO-8601 Timestamp
- Cannot be moved, optimized, or deleted by the scheduler.

### Sleep Shield Representation
- `sleepStart`: Time (e.g., "23:00")
- `sleepEnd`: Time (e.g., "06:00")
- `minSleepHours`: Float >= 7.0
Represented as a circular continuous blocked interval on the 24-hour timeline.

## 2. Capacity & Constraints
### Available-Capacity Calculation
Time is discretized into 30-minute slots. A 24-hour period contains 48 slots.
`Available_Capacity_Slots = 48 - Sleep_Slots - Fixed_Slots`

### Hard Constraints vs. Soft Preferences
**HARD CONSTRAINTS** (Absolute boundaries; violation throws an error / drops the task):
- **Sleep Shield**: No task slot can intersect `[sleepStart, sleepEnd]`.
- **Fixed Commitments**: No task slot can intersect existing mandatory events.
- **Duration/Capacity**: The sum of scheduled task durations cannot exceed `Available_Capacity_Slots`.
- **Past/Locked Blocks**: Time flows forward; past blocks cannot be altered.

**SOFT PREFERENCES** (Heuristics for placement and ordering; can be compromised):
- **Energy Match**: Placing HIGH cognitive load tasks in Peak Energy Windows.
- **Priority Balancing**: Scheduling higher priority tasks earlier in the day.
- **Workload Balancing**: Avoiding packing all work continuously if gaps exist.

## 3. Priority Scoring
Every candidate task is scored before selection.
$$ P_i = (\alpha \times W_{academic}) + (\beta \times U_{deadline}) + (\gamma \times W_{team}) + (\delta \times D_{debt}) $$

## 4. Phase A: TASK SELECTION (0/1 Knapsack Formulation)
The 0/1 Knapsack stage treats each task as a selectable unit ($x_i \in \{0,1\}$). 
A selected task ($x_i = 1$) means the scheduler *intends* to allocate its full **Remaining Task Duration** within the scheduling horizon.

**Objective:** Maximize the total priority of scheduled tasks.
$$ \text{Maximize} \sum_{i=1}^{n} (P_i \times x_i) $$

**Subject to:**
$$ \sum_{i=1}^{n} (W_i \times x_i) \le C $$

Where:
- $x_i \in \{0, 1\}$
- $P_i$ = "Value" (Priority score)
- $W_i$ = "Weight" (**Remaining Task Duration** in 30-minute slots)
- $C$ = "Capacity" (`Available_Capacity_Slots`)

## 5. Phase B: TASK PLACEMENT
After selection, the placement engine assigns the selected workload ($W_i$) into actual available time slots on the timeline, strictly respecting all HARD constraints (Sleep Shield, Fixed Commitments).
- **Sorting**: Selected tasks are sorted by $P_i$ descending.
- **Energy Windows**: The engine attempts to align the starting slots of HIGH cognitive-load tasks with user-defined Peak Energy Windows.

## 6. Phase C: TASK SPLITTING & CONFLICT RESOLUTION
**Equilibrium EXPLICITLY SUPPORTS Task Splitting.**
Because a task might require 6 hours (12 slots) but the maximum continuous gap is 3 hours (6 slots), the engine must split tasks to fit the capacity.

**Splitting Rules:**
- **Minimum Chunk Duration**: 30 minutes (1 slot).
- **Maximum Chunk Duration**: 4 hours (8 slots) to prevent burnout. If a task exceeds 4 hours, it is automatically split.
- **Cross-Day Splitting**: Chunks may cross days within the scheduling horizon (e.g., 2h today, 2h tomorrow).

**Conflict Resolution & Partial Scheduling:**
If the placement engine cannot find enough free slots to fit the *entire* selected $W_i$:
1. It places as many minimum chunks (30m) as possible into the remaining gaps.
2. The task becomes **Partially Scheduled**. 
3. **Schedule Debt**: The unscheduled remainder of the task increments the `deferralCount`.
4. **Explanations**: The decision log explicitly notes: "Partially Scheduled: 2h placed, 2h deferred due to fragmented capacity bounds."

## 7. Rescheduling & Disruption Handling
Triggered by: Task overrun, early completion, missed task, or new unexpected event.
**Pipeline:**
1. **Freeze**: Past slots and completed chunks are locked. `completedDuration` is updated.
2. **Recalculate Remaining**: $W_i$ for all tasks is updated to `max(0, Estimated - Completed)`.
3. **Recalculate Capacity**: `Remaining_C = Total_Slots - Sleep - Fixed - Completed_Slots`.
4. **Recalculate Priorities**: Overdue tasks spike in urgency. Partially scheduled tasks from previous runs have higher debt.
5. **Re-run Task Selection**: 0/1 Knapsack executes on the remaining tasks.
6. **Re-run Task Placement/Splitting**.
7. **Create new ScheduleVersion**.

## 8. Determinism & Edge Cases
- **Determinism**: Given exact same `Remaining Durations`, priorities, and constraints, the Selection and Placement outputs are mathematically identical.
- **Infeasible Schedules**: If a task's $W_i$ is larger than the entire week's capacity, the Knapsack will attempt to place what it can. The placement layer splits it. The remainder is deferred, raising an explicit Burnout/Infeasible warning in the UI.

*Example Splitting Walkthrough*:
- Task: DSA Assignment (Estimated: 4h, Completed: 0h). Remaining: 4h.
- Capacity gap 1: 09:00–11:00 (2h)
- Capacity gap 2: 13:00–15:00 (2h)
- *Placement*: Engine splits the task into Chunk 1 (09:00-11:00) and Chunk 2 (13:00-15:00). Scheduled Duration = 4h. Remaining Duration = 4h. The task is fully scheduled.
