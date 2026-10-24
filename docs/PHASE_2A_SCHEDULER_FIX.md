# Equilibrium Phase 2A: Deadline-Feasibility Scheduling Engine Fix & Correctness Review

## 1. Executive Summary & Root Cause Analysis

### The Flaw
In the original implementation of the Equilibrium scheduling engine (`server/src/scheduler/rescheduler.ts`), task selection for the 0/1 Knapsack optimization was passed an aggregate capacity number (`availableSlots`) representing all free 30-minute slots across the entire planning horizon (up to 7 days, or 336 slots):

```typescript
// Legacy implementation:
const availableSlots = slots.filter(s => s.available && s.start >= now).length;
...
knapsackItems.push({
  task,
  priority: p.score,
  weightSlots: Math.min(Math.ceil(task.remainingMinutes / 30), availableSlots)
});
const selectedIds = solveKnapsack(knapsackItems, availableSlots);
```

During the subsequent greedy placement stage (`server/src/scheduler/placement.ts`), each slot was checked against the task's individual deadline:
```typescript
const canUse = slot.available
  && (!energyRequired || slot.energyBonus)
  && slot.start >= now
  && slot.end <= task.deadline
  && !dayQuotaReached;
```

### The Failure Mode
If a high-priority task (Task A) had an urgent deadline occurring before any usable capacity was available (for instance, during a fixed commitment, sleep window, or immediately after `now`), Task A was still evaluated by Knapsack against the aggregate horizon capacity. Because Task A had high urgency and high priority, Knapsack selected it, consuming capacity budget.

When placement executed:
1. Task A found zero valid slots where `slot.end <= task.deadline`.
2. Task A failed to be placed (0 slots scheduled) and was deferred with reason code `NO_AVAILABLE_SLOTS`.
3. Meanwhile, Task B (which had a later deadline and sufficient valid slots) was rejected during Knapsack selection because Task A consumed the available selection capacity.
4. Consequently, feasible work was crowded out, resulting in unutilized capacity and zero scheduled tasks.

Furthermore, a simplistic approach of independently filtering available capacity per task (i.e., verifying only that Task A fits individually and Task B fits individually) does not prevent two tasks from competing for and exceeding the same early time slots prior to an early deadline.

---

## 2. Review Finding 1: Partial-Work Scoring Distortion & Quantification

### The Problem
When a task's demand exceeds the available slots before its deadline, capping its Knapsack weight (`weightSlots = Math.min(neededSlots, deadlineSlots)`) without adjusting its value introduces a severe mathematical distortion:
- If Task A requires 16 slots (480 minutes, e.g. an extensive thesis draft) but only 1 slot is available before its deadline, setting `weightSlots = 1` while assigning the full priority score $p.score = 4.0$ inflates Task A's value density by a factor of 16 ($4.0 / 1 = 4.0$ per slot instead of $4.0 / 16 = 0.25$ per slot).
- If Task B requires 1 slot (30 minutes, e.g. a quiz) and has 1 slot available before its deadline with priority score $p.score = 2.70$, its value density is $2.70 / 1 = 2.70$ per slot.
- Under unweighted scoring, Knapsack compares Task A ($4.0$) against Task B ($2.70$) for that single slot and selects Task A.
- Placement then schedules Task A for 30 minutes (achieving only $6.25\%$ progress and leaving 450 minutes deferred past deadline), while Task B (which could have reached $100\%$ completion) is completely unscheduled.

### The Quantified Effect
| Task | Needed Slots | Usable Slots | Base Priority | Unscaled Knapsack Value | Proportional Progress Value |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Task A** | 16 slots (480m) | 1 slot (30m) | 4.00 | **4.00** (16x inflated) | **0.25** ($4.0 \times \frac{1}{16}$) |
| **Task B** | 1 slot (30m) | 1 slot (30m) | 2.70 | **2.70** (1x true) | **2.70** ($2.7 \times \frac{1}{1}$) |

Awarding unscaled priority for partial work rewards microscopic progress on oversized tasks over genuine task completions.

---

## 3. Review Finding 2: Explicit Objective Formulation over Capped Task Bundles

### Chosen Objective: Total Weighted Academic Progress over Capped Bundles
Equilibrium defines its scheduler selection objective as **Total Weighted Academic Progress over Capped Task Bundles**:

$$\max_{S \subseteq \mathcal{T}} \sum_{i \in S} \text{Value}_i$$

where for each selected task $i$:
$$\text{Value}_i = P(t_i) \cdot \frac{w_i}{w_{\text{needed}, i}}$$

subject to:
1. **Joint Prefix Deadline Feasibility**:
   For every slot index $k \in \{1, \dots, M\}$:
   $$\sum_{i \in S : D_i \le k} w_i \le k$$
2. **Horizon Capacity Bound**:
   $$\sum_{i \in S} w_i \le \text{availableSlots}$$
3. **Task-Specific Usable Demand**:
   $$w_i = \text{maxAllocatableSlots}_i$$

### Scope of Solver Optimality
- **Discrete Capped-Bundle Optimality**: The dynamic programming solver in `server/src/scheduler/knapsack.ts` is **globally optimal over the discrete 0/1 choice of defined capped task bundles** $\{ (w_i, \text{Value}_i) \}$ under joint prefix deadline constraints.
- **Boundaries**: It does **not** dynamically explore all arbitrary sub-allocations $w \in \{1, \dots, w_i - 1\}$ per task simultaneously (which would represent a continuous multi-choice fractional knapsack). The bundle size $w_i = \text{maxAllocatableSlots}_i$ is pre-determined by the task's remaining demand and daily pacing limits.
- **Preservation of Priority Score Meaning**:
  $P(t_i) = \alpha \cdot \text{Academic} + \beta \cdot \text{Urgency} + \gamma \cdot \text{Team} + \delta \cdot \text{ScheduleDebt}$ continues to represent the task's intrinsic priority and is displayed unmodified in `DecisionLog.priorityScore`. Only the Knapsack solver's internal bundle evaluation scales with $\frac{w_i}{w_{\text{needed}, i}}$.

---

## 4. Review Finding 3: Separation of Chronological Deadline Capacity vs. Allocation Limits

### The Distinction
In Phase 2A.2, the engine strictly separates two distinct concepts that must never be conflated or assumed interchangeable:
1. **`deadlineCapacity` (or Chronological Deadline Capacity)**:
   - The exact count and chronological index of genuinely available 30-minute slots ending on or before the task's actual deadline.
   - It is strictly **independent of task-specific daily workload targets** (`dailyTargetMinutes`) or remaining duration.
   - It is used for **Earliest Deadline First (EDF) chronological sorting** and the **joint prefix-feasibility constraint** $\sum_{j \in S : D_j \le k} w_j \le k$.
2. **`maxAllocatableSlots` (or Task Allocation Limit)**:
   - The maximum number of slots that an individual task may receive after accounting for its remaining duration and its `dailyTargetMinutes` constraint across eligible calendar days.
   - It is used strictly to cap that specific task's weight bundle ($w_i$).

### Why This Separation is Essential
Suppose Task 1 is due on Day 1 (scarce capacity, 6 slots available before deadline) and requires 6 slots.
Suppose Task 2 is due on Day 2 (abundant capacity, 22 slots available before deadline), requires 8 slots, but has `dailyTargetMinutes = 60` (2 slots/day, meaning at most 4 slots across 2 days).
- Task 2 has a smaller allocatable slot count ($4 < 6$).
- But Task 2 has a **later** deadline than Task 1.
- If `maxAllocatableSlots` were mistakenly used as the deadline limit, Task 2 would be sorted before Task 1 ($4 < 6$), stealing Day 1's early slots and starving Task 1 of its required 6 slots before its Day 1 deadline.
- By using chronological `deadlineCapacity` ($6$ for Task 1, $22$ for Task 2), Task 1 is correctly prioritized for Day 1 slots, while Task 2 is placed on Day 2, satisfying both deadlines and daily target limits.

---

## 5. Review Finding 4: Joint Prefix Deadline Feasibility & Mathematical Equivalence

### Dynamic Programming with Prefix Bounds
In `server/src/scheduler/knapsack.ts`:
1. Items are sorted by:
   - Primary: `deadlineCapacity` ascending ($D_i$)
   - Secondary: `deadline` timestamp ascending (chronological tie-breaking when two tasks have identical slot counts)
   - Tertiary: `priority` descending
   - Quaternary: `academicWeight` descending, then `task.id` ascending (`localeCompare`).
2. State $dp[i][w]$ represents the maximum objective value using a feasible subset of the first $i$ items with total weight exactly $w$ ($-1$ if unreachable, $dp[0][0] = 0$).
3. Transition:
   When adding item $i$ with weight $w_i$, value $v_i$, and deadline capacity $D_i$:
   $$\text{For all } w_{prev} \text{ where } dp[i-1][w_{prev}] \ge 0: \quad w_{new} = w_{prev} + w_i \le D_i$$
   $$dp[i][w_{new}] = \max(dp[i][w_{new}], dp[i-1][w_{prev}] + v_i)$$

### Exhaustive Brute-Force Equivalence Validation
To mathematically prove the optimality of `solveKnapsack` under prefix deadline constraints, an exact combinatorial brute-force solver (`solveKnapsackBruteForce`) was constructed in `server/test/regression.deadline-feasibility.test.ts`.

The brute-force solver evaluates all $2^n$ subsets ($n \le 12$), validates the prefix feasibility condition $\sum_{j \in S : D_j \le k} w_j \le k$ for every $k \in \{1, \dots, M\}$, and finds the global maximum objective score.

In regression test Section 10, across diverse instances (same-deadline clusters, multi-stage deadline cascades, scarce early capacity followed by late capacity), **`solveKnapsack` achieved 100% exact numerical match with the exhaustive global maximum score**.

---

## 6. Review Finding 5: Selection-Placement Consistency & Decision Logs

### Bounded Chunk Placement & Explainability
- In `server/src/scheduler/placement.ts`, tasks are placed in **Earliest Deadline First (EDF)** order:
  ```typescript
  const sortedTasks = [...tasks].sort((a, b) => {
    if (a.deadline.getTime() !== b.deadline.getTime()) {
      return a.deadline.getTime() - b.deadline.getTime();
    }
    if (Math.abs(priorities[b.id].score - priorities[a.id].score) > 0.0001) {
      return priorities[b.id].score - priorities[a.id].score;
    }
    return a.id.localeCompare(b.id);
  });
  ```
- Chunks are bounded between 1 slot (30 min) and 8 slots (4 hours).
- Placement logs actual committed blocks:
  - If `placedSlots === originalSlots`: `FULLY_SCHEDULED`, `SUCCESS`.
  - If `placedSlots > 0 && placedSlots < originalSlots`: `PARTIALLY_SCHEDULED`, with reason code `DAILY_TARGET_PACING` if constrained by daily target, or `FRAGMENTED_CAPACITY` if broken by sleep/fixed commitments.
  - If `placedSlots === 0`: `DEFERRED`, `NO_AVAILABLE_SLOTS`.
- All `DecisionLog` records report exact `scheduledMinutes` and `deferredMinutes` that match the emitted `ScheduleBlock[]`.

---

## 7. Reason Code & Contract Compatibility

No new reason codes were added. The enum contract remains:
- `SUCCESS`: Task fully placed.
- `PARTIALLY_SCHEDULED` (`DAILY_TARGET_PACING` or `FRAGMENTED_CAPACITY`): Task partially placed.
- `CAPACITY_EXCEEDED`: Task had valid slots before deadline but was out-prioritized in Knapsack.
- `NO_AVAILABLE_SLOTS`: Task had zero valid slots before deadline.

Both backend API consumers and the Flutter client (`equilibrium_app/lib/models/decision_log.dart`) remain 100% compatible.

---

## 8. Files Changed

| File Path | Description of Changes |
| :--- | :--- |
| `server/src/scheduler/knapsack.ts` | Added `deadlineCapacity` (with backward-compatible `deadlineSlots` alias) to `KnapsackItem`. Implemented chronological EDF sorting and prefix deadline feasibility condition ($w_{new} \le D_i$) in DP transition and backtracking. |
| `server/src/scheduler/rescheduler.ts` | Implemented `computeTaskSlotLimits`, cleanly separating `deadlineCapacity` from `maxAllocatableSlots`. Filtered $deadlineCapacity = 0$ tasks to `NO_AVAILABLE_SLOTS`; filtered $maxAllocatableSlots = 0$ to `DAILY_TARGET_PACING`; scaled partial work priority proportionally to achievable progress ($P(t) \cdot \frac{weightSlots}{neededSlots}$); preserved deterministic input order in decision logs. |
| `server/src/scheduler/placement.ts` | Updated task placement order to Earliest Deadline First (EDF) with priority and ID tie-breaking to align placement with prefix knapsack feasibility. |
| `server/test/regression.deadline-feasibility.test.ts` | Added 12 comprehensive regression test suites covering impossible urgent tasks, same-deadline competition, staged prefix feasibility, overnight sleep/buffers, over-capacity periods, partial placement, 100-run determinism, direct knapsack unit test, 16-slot vs 1-slot partial work scoring, exhaustive brute-force equivalence, daily target pacing consistency, and deadline order vs daily target allocation limits conflict. |

---

## 9. Verification & Test Evidence

### Test Execution Commands
The test suite was verified using the official scheduler test configuration:
```bash
npm test
# Equivalent to: jest --config jest.scheduler.config.js
```
TypeScript compilation was verified using:
```bash
npx tsc --noEmit
```

### Verification Results
- **TypeScript Compilation**: `npx tsc --noEmit` exited with code `0` (zero errors, zero warnings).
- **Test Suites**: **6 passed, 6 total** (100% passing).
- **Tests**: **51 passed, 51 total** (100% passing).
- **Execution Time**: ~3.57 seconds.

#### Summary of Test Suites Executed:
1. `test/regression.deadline-feasibility.test.ts` (12 tests: primary regression, same-deadline, staged EDF, overnight sleep/buffers, over-capacity, partial scheduling, 100-run determinism, direct knapsack unit test, 16-slot vs 1-slot partial work scoring, exhaustive brute-force equivalence, daily target pacing consistency, deadline order vs daily target allocation limit conflict) — **PASSED**
2. `test/regression.secrets-hygiene.test.ts` (Phase 1 security remediation) — **PASSED**
3. `test/regression.student-workflow.test.ts` (Fixed commitments, daily targets, overnight sleep shield) — **PASSED**
4. `test/regression.exam-prep-sleep-shield.test.ts` (Exam preparation topic scheduling & timezone handling) — **PASSED**
5. `test/scheduler.test.ts` (Sleep shield, fixed commitments, knapsack determinism, splitting, priority breakdown, disruption) — **PASSED**
6. `test/scheduler.extended.test.ts` (15 extended scheduler invariants, 50 randomized property runs, validator safety net) — **PASSED**
