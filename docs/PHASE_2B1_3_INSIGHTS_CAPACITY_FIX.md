# Equilibrium Phase 2B.1.3: Workload Insights Sleep-Duration Capacity Remediation

## Executive Summary
Phase 2B.1.3 resolves a critical mathematical inconsistency identified during the sleep settings contract audit in the backend analytics pipeline (`server/src/routes/insights.routes.ts`).

Prior to this phase, the insights endpoint used `constraints.minSleepHours * 60` to calculate protected daily sleep minutes. Because `minSleepHours` is a minimum validation floor (defaulting to 7.0 hours) rather than the actual duration of the user's selected sleep window `[sleepStart, sleepEnd]`, the backend systematically overestimated daily available capacity for students with 8-hour, 9-hour, or longer sleep schedules by 60 to 120+ minutes per day (420 to 840+ minutes per week). This artificially deflated workload utilization metrics and masked burnout risk.

This remediation replaces the proxy floor substitution with the exact daily sleep duration computed from `sleepStart` and `sleepEnd` with robust overnight handling, while strictly preserving `minSleepHours` as the validation floor and maintaining 100% backward compatibility with the existing API contract.

---

## 1. Root Cause Analysis

### A. Floor vs. Window Conflation
In `server/prisma/schema.prisma` and `server/src/validation/schemas.ts`:
- `minSleepHours`: Health policy constraint floor ($\ge 7.0$ hours).
- `sleepStart` and `sleepEnd`: The student's actual selected sleep window (e.g., `23:00` to `07:00` = 8 hours; `22:00` to `07:00` = 9 hours).

In `server/src/routes/insights.routes.ts` (lines 17 & 26 prior to fix):
```typescript
const sleepMinutes = constraints ? Math.round(constraints.minSleepHours * 60) : 420;
...
const safeDailyMinutes = Math.max(0, 1440 - sleepMinutes - (constraints?.bufferMinutes ?? 30));
```

### B. Concrete Numerical Impact
When a student onboards with Equilibrium's standard default sleep window `23:00`–`07:00` (8.0 hours) and `minSleepHours: 7.0`, `bufferMinutes: 15`:
* **Expected Daily Sleep**: $8.0 \times 60 = 480$ minutes.
* **Expected Safe Daily Capacity**: $1440 - 480 - 15 = 945$ minutes ($6615$ minutes/week).
* **Actual Buggy Calculation**: Used $7.0 \times 60 = 420$ minutes.
* **Buggy Safe Daily Capacity**: $1440 - 420 - 15 = 1005$ minutes ($7035$ minutes/week).
* **Discrepancy**: Overestimated safe capacity by $+60$ minutes/day ($+420$ minutes/week).

For students selecting a 9.0-hour sleep window (`22:00`–`07:00`):
* **Expected Safe Daily Capacity**: $1440 - 540 - 15 = 885$ minutes ($6195$ minutes/week).
* **Buggy Calculation**: Reported $1005$ minutes/day.
* **Discrepancy**: Overestimated capacity by $+120$ minutes/day ($+840$ minutes/week).
* **Consequence**: A student with 5000 scheduled minutes had an actual utilization of $5000 / 6195 = 80.7\%$ (MEDIUM/HIGH burnout risk), but insights reported $5000 / 7035 = 71.0\%$ (LOW risk), completely defeating the purpose of the burnout warning system.

---

## 2. Mathematical Formulation & Solution

### A. Time String Parsing
A 24-hour time string `"HH:mm"` is converted to minutes from midnight:
$$\text{parseTimeToMinutes}(HH:mm) = H \times 60 + M \quad \text{for } 0 \le H \le 23, 0 \le M \le 59$$

### B. Sleep Duration with Overnight Wrapping
Given `sleepStart` and `sleepEnd`:
$$\Delta_{\text{raw}} = \text{endMin} - \text{startMin}$$
$$\Delta_{\text{sleep}} = \begin{cases}
\Delta_{\text{raw}} + 1440 & \text{if } \Delta_{\text{raw}} \le 0 \\
\Delta_{\text{raw}} & \text{if } \Delta_{\text{raw}} > 0
\end{cases}$$

### C. Validation Guards & Contract Fallback
1. **Equal Times**: If `sleepStart === sleepEnd`, the interval is degenerate (0 hours or ambiguous 24 hours). The function returns `null`.
2. **Protocol Ceiling**: If $\Delta_{\text{sleep}} > 16 \times 60$ ($960$ minutes), it violates the product protocol ceiling (per `constraintSchema` in `schemas.ts`) and returns `null`.
3. **Malformed/Missing Input**: If either time string is missing or invalid, the function returns `null`.
4. **Contract Fallback**:
   $$\text{sleepMinutes} = \begin{cases}
   \Delta_{\text{sleep}} & \text{if } \Delta_{\text{sleep}} \ne \text{null} \\
   \text{round}(\text{constraints.minSleepHours} \times 60) & \text{if } \Delta_{\text{sleep}} = \text{null} \land \text{constraints.minSleepHours} \ne \text{null} \\
   420 & \text{otherwise (default 7.0 hours)}
   \end{cases}$$
5. **Safe Daily Capacity**:
   $$\text{safeDailyMinutes} = \max\Big(0, \, 1440 - \text{sleepMinutes} - (\text{constraints.bufferMinutes} \mathbin{??} 30)\Big)$$
   $$\text{safeTotalMinutes} = \text{safeDailyMinutes} \times 7$$

---

## 3. Files Created and Modified

### A. New Pure Helper Module
**File**: [`server/src/utils/workload.helper.ts`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/src/utils/workload.helper.ts)
- `parseTimeToMinutes(timeStr?: string | null): number | null`: Validates and parses `"HH:mm"` times.
- `calculateSleepDurationMinutes(sleepStart?: string | null, sleepEnd?: string | null): number | null`: Implements the overnight wrapping formula, equal-time guard, and $>16$h bounds.
- `computeSafeDailyMinutes(constraints?: ConstraintLike | null): number`: Resolves safe daily capacity using actual sleep duration or fallback, accounting for buffer minutes.

### B. Insights Route Refinement
**File**: [`server/src/routes/insights.routes.ts`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/src/routes/insights.routes.ts)
- Replaced manual `constraints.minSleepHours * 60` calculation with `computeSafeDailyMinutes(constraints)`.
- Kept response payload structure, status codes, and error handlers completely identical.

### C. Automated Regression & Unit Tests
**File**: [`server/test/regression.insights-sleep-capacity.test.ts`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/server/test/regression.insights-sleep-capacity.test.ts)
- 16 focused unit and integration test assertions verifying overnight duration math, daytime windows, dynamic capacity shifts, fallback semantics, and full route response correctness.

---

## 4. Acceptance Tests & Verification Results

### A. TypeScript Typecheck
Command executed:
```bash
npx tsc --noEmit
```
Output: Clean exit with code **0**, zero type errors.

### B. Server Test Suite (including new Regression Suite)
Command executed:
```bash
npm test
```
Result: **7 passed test suites, 72 passed tests, 0 failures**.

```
PASS test/regression.secrets-hygiene.test.ts
PASS test/scheduler.test.ts
PASS test/regression.student-workflow.test.ts
PASS test/regression.deadline-feasibility.test.ts
PASS test/scheduler.extended.test.ts
PASS test/regression.insights-sleep-capacity.test.ts
PASS test/regression.exam-prep-sleep-shield.test.ts

Test Suites: 7 passed, 7 total
Tests:       72 passed, 72 total
Snapshots:   0 total
Time:        2.435 s
```

Key verified test assertions:
- **Overnight 22:00–07:00 (9h = 540m)**: Safe daily capacity evaluates to 870m with buffer 30 (previously miscalculated as 990m).
- **Overnight 23:00–07:00 (8h = 480m)**: Safe daily capacity evaluates to 930m with buffer 30.
- **Dynamic Capacity Sensitivity**: Safe capacity directly scales with sleep changes ($810$m for 10h, $870$m for 9h, $930$m for 8h, $990$m for 7h).
- **Daytime Windows**: `08:00`–`17:00` (9h = 540m) and `01:00`–`09:00` (8h = 480m) compute accurately.
- **Equal Times & Degenerate Windows**: `07:00`–`07:00` safely falls back to `minSleepHours * 60`.
- **Missing Constraints**: `null` constraints safely falls back to 420m sleep and 30m buffer (990m capacity).
- **HTTP Route Integration**: `GET /api/v1/insights` accurately recalibrates `safeDailyMinutes`, `utilization`, and `riskLevel` with authentic JWT tokens and fake database state.

### C. Flutter Client Verification
Command executed:
```bash
flutter test
```
Result: **5 passed test suites, 39 passed tests, 0 failures**. Confirms zero regressions in the Flutter client.

---

## 5. Git Working Tree Integrity
Inspection with `git status --short` confirms:
- Phase 1 security hygiene changes remain intact.
- Phase 2A/2A.2 scheduler fixes remain intact.
- Phase 2B.1 Today screen and workload calculator fixes remain intact.
- Phase 2B.1.3 changes are strictly confined to:
  - `server/src/utils/workload.helper.ts` (new)
  - `server/src/routes/insights.routes.ts` (modified: 3 lines changed)
  - `server/test/regression.insights-sleep-capacity.test.ts` (new)
  - `docs/PHASE_2B1_3_INSIGHTS_CAPACITY_FIX.md` (new)
