# Equilibrium Phase 2B.1 & 2B.1.1: Frontend Correctness Remediation

## Executive Summary
Phase 2B.1 and 2B.1.1 resolve critical correctness and constraint-alignment defects identified during the product and architectural audit in the Flutter client (`equilibrium_app/`):
1. **Today Dashboard Correctness**: Corrected task filtering so "Today's Tasks" exclusively reflects tasks with active blocks overlapping the user's local calendar day, aggregates multiple blocks without duplicate task cards, and surfaces urgent overdue/due-today unscheduled tasks in a compact "Needs Attention" section.
2. **Workload Capacity Calculation**: Replaced the broken `FREE` block lookup with an interval-union capacity calculation based on the user's local-day window, protected sleep shield, and buffered fixed commitments, eliminating misleading 100% load figures and hardcoded fallbacks.
3. **Onboarding Validation & Resilience (Phase 2B.1.1 Aligned)**: Aligned client sleep validation to the exact backend-supported sleep range of **7.0 to 12.0 hours inclusive** (`minSleepHours: z.number().min(7.0).max(12.0)`), rejecting equal start/end times, durations $< 7.0$ hours, and durations $> 12.0$ hours. Guaranteed that save failures preserve user inputs and prevent silent progression.

---

## 1. Root Cause Analysis

### Defect 1: Today Screen Listing Active Tasks From Entire Horizon
- **Root Cause**: In `TodayScreen` (`today_screen.dart`), the list of tasks rendered under "Today's Tasks" was sourced directly from `provider.activeTasks` (`final tasks = provider.activeTasks; ...tasks.map(...)`). Active tasks for the entire 7-day horizon (and unscheduled tasks) were displayed under "Today's Tasks".
- **Date Matching Flaw**: Where date checks existed, they relied on string formatting `DateFormat('yyyy-MM-dd').format(b.startTime) == nowStr`, which failed on timezone differences, overnight blocks crossing midnight, and UTC dates.
- **Lost Urgent Work**: Unscheduled or deferred tasks due today or overdue were either conflated with scheduled work or hidden behind an empty state if no schedule blocks existed today.

### Defect 2: Workload Meter Searching for Non-Existent `FREE` Blocks
- **Root Cause**: `today_screen.dart` iterated through schedule blocks checking `if (b.type == 'FREE' || b.type == 'TASK') availableMinutes += b.durationMinutes;`. The backend scheduling pipeline (`rescheduler.ts`, `placement.ts`) only places and returns `TASK` blocks (and locked blocks); it never emits `FREE` blocks.
- **Fallback Flaw**: If `availableMinutes == 0`, the UI fell back to `availableMinutes = plannedMinutes`. This produced an artificial 100% workload ratio on any day with scheduled tasks, misleading students into believing they were always at full capacity.

### Defect 3: Onboarding Permitting Sub-7-Hour and Super-12-Hour Sleep Windows
- **Root Cause**: The backend constraint schema (`server/src/validation/schemas.ts`) defines `minSleepHours: z.number().min(7.0).max(12.0)`. The initial client code permitted sleep under 5 hours, and an initial pass capped it at 16 hours. A user selecting $> 12$ hours (e.g., 13 hours) or $< 7$ hours could either be rejected with HTTP 400 or misaligned with backend scheduler invariants.
- **Silent Advancement Flaw**: In `onboarding_screen.dart`'s `_nextPage()`, the `catch (e)` block displayed a transient warning toast and immediately called `_pageCtrl.nextPage()`. The user was silently advanced to the next screen and into the app without their sleep settings ever persisting.

---

## 2. Implemented Code Changes

### A. Mathematical Workload & Interval Union Utility
**File**: [`equilibrium_app/lib/core/utils/workload_calculator.dart`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/lib/core/utils/workload_calculator.dart)
- Created `TimeInterval` class with boundary clamping (`clamp(rangeStart, rangeEnd)`).
- Defined backend-aligned boundary constants:
  - `minSleepHours = 7.0;`
  - `maxSleepHours = 12.0;`
  - `isValidSleepDuration(double hours) => hours >= 7.0 && hours <= 12.0;`
- Implemented `WorkloadCalculator.mergeIntervals(List<TimeInterval>)`: Computes the mathematical union of overlapping and contiguous unavailable intervals, strictly avoiding double-counting overlaps between sleep shields, fixed commitments, and buffers.
- Implemented `WorkloadCalculator.calculateSleepIntervals(DateTime, sleepStart, sleepEnd)`:
  - Correctly splits overnight sleep crossing midnight (e.g., 23:00 to 07:00) into morning sleep `[00:00, 07:00]` and evening sleep `[23:00, 24:00]`.
  - Handles same-day sleep (e.g., 01:00 to 09:00), zero-duration windows (`start == end`), and clamps all intervals to local calendar day `[dayStart, dayEnd)`.
- Implemented `WorkloadCalculator.calculateCapacity(...)`:
  - Determines local 24-hour day duration ($1440$ minutes).
  - Merges sleep intervals and buffered fixed commitments.
  - Available capacity $= totalDayMinutes - unavailableMinutes$.
  - Planned minutes $= \sum$ overlap duration of `TASK` blocks with today.
  - Computes exact load ratio and remaining capacity without synthetic defaults.

### B. Today Dashboard Remediation
**File**: [`equilibrium_app/lib/screens/today/today_screen.dart`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/lib/screens/today/today_screen.dart)
- **Today's Active Blocks**: Filtered blocks to `b.type == 'TASK' && b.taskId != null && b.startTime.isBefore(dayEnd) && b.endTime.isAfter(dayStart)`.
- **Deduplication & Multi-Block Aggregation**: Grouped today's blocks by `taskId`. Tasks with multiple blocks on the same day now display a single unified `TaskCard` showing the sum of scheduled minutes for today.
- **Future Tasks Excluded**: Tasks scheduled only for tomorrow or later days are excluded from "Today's Tasks".
- **"Needs Attention" Section**: Active non-completed tasks without scheduled blocks today that are overdue (`isOverdue`), due today (`isDueToday`), or whose deadline occurs before the end of the local day are rendered in a compact, warning-styled "Needs Attention" section.
- **Graceful Empty State**: If no blocks or commitments exist today but urgent tasks need attention, the screen renders the dashboard with the "Needs Attention" list rather than hiding urgent assignments behind an empty state.
- **Accurate Capacity**: Wired `WorkloadCalculator.calculateCapacity` into the dashboard metrics.

### C. Workload Meter Polish
**File**: [`equilibrium_app/lib/widgets/status/workload_meter.dart`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/lib/widgets/status/workload_meter.dart)
- Added explicit secondary label: `out of X daily capacity` to clarify planned load versus available capacity.
- Accurately highlights overload (indicator color switches to danger if planned load exceeds capacity or available capacity is zero with planned load).

### D. Onboarding Validation & Failure Handling (Phase 2B.1.1 Correction)
**File**: [`equilibrium_app/lib/screens/onboarding/onboarding_screen.dart`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/lib/screens/onboarding/onboarding_screen.dart)
- **Source-Verified Backend Alignment**:
  - `minSleepHours`: exactly $7.0$ hours (`sleepHours < WorkloadCalculator.minSleepHours`).
  - `maxSleepHours`: exactly $12.0$ hours (`sleepHours > WorkloadCalculator.maxSleepHours`).
  - Equal times: rejected (`_sleepStart == _sleepEnd`).
  - Clear inline error messages preventing progression:
    - Below 7h: `'Equilibrium requires at least 7 hours of protected sleep (selected: Xh).'`
    - Above 12h: `'Sleep window cannot exceed 12 hours (selected: Xh). Please check your times.'`
    - Equal start/end: `'Sleep start and wake-up time cannot be the same.'`
- **Guaranteed Persistence**: If `updateConstraints()` throws an exception (HTTP 400 or network failure), the catch block sets an inline retryable error message, displays a SnackBar, and **does not advance** `_pageCtrl`. The user remains on Step 1, with their inputs preserved, until persistence succeeds.
- **Viewport Resilience**: Wrapped onboarding page contents in `SingleChildScrollView(physics: BouncingScrollPhysics())` to eliminate `RenderFlex` overflows on compact viewports and smaller mobile screens.

### E. Schedule Block Data Model
**File**: [`equilibrium_app/lib/models/schedule.dart`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/lib/models/schedule.dart)
- Added `final bool isCompleted;` to `ScheduleBlock` with default `false`, preserving full backward-compatibility.

---

## 3. Automated Verification & Test Results

### Flutter Client Test Suite
Command executed:
```bash
flutter test
```
Result: **39 passing tests across 5 test files (100% pass rate)**.

Detailed breakdown of [`test/phase_2b1_correctness_test.dart`](file:///d:/3rd%20Year%20I%20Sem/DTPLM/Equilibrium%20CP/equilibrium_app/test/phase_2b1_correctness_test.dart) (18 tests):
- `Workload capacity for an eight-hour overnight sleep window (23:00 to 07:00)`: Verified $1440 - 480 = 960$ min available.
- `Workload capacity with fixed commitments and buffers`: Verified 120m commitment + 15m buffers yields $630$m blocked, $810$m available.
- `Workload capacity with overlapping blocked intervals avoids double-counting`: Verified morning sleep (00:00–07:00) overlapping commitment (06:00–08:00) yields unified block [00:00, 08:00] ($540$m blocked, $900$m available).
- `Workload capacity on an empty day has 1440 minutes available`: Verified 0 blocked, 1440 available.
- `Midnight boundaries handle overnight intervals properly`: Verified cross-midnight commitment clamped to [23:30, 24:00] (30m).
- `Sleep duration calculation for 23:00 to 07:00 returns 8.0 hours and is valid`: Verified overnight window arithmetic and range validity.
- `Sleep duration calculation for invalid short window 23:00 to 05:00 is less than 7 hours`: Verified 6.0h $< 7.0$h and invalid.
- `Sleep duration for equal start and end returns 0.0 hours and is invalid`: Verified 0.0h and invalid.
- `Minimum boundary check: 7.0h is valid, 6.9h is invalid`: Verified exact minimum threshold behavior.
- `Maximum boundary check: 12.0h is valid, durations above 12.0h are invalid`: Verified 12.0h is valid, 12.1h is invalid, 13.0h is invalid.
- `Onboarding validation rejects duration above 12 hours with inline error and blocks navigation`: Verified 13h input shows `'Sleep window cannot exceed 12 hours'`, prevents Step 2 advancement, and avoids calling API.
- `Onboarding validation rejects duration below 7 hours with inline error and blocks navigation`: Verified 6h input shows `'Equilibrium requires at least 7 hours of protected sleep'`, prevents Step 2 advancement, and avoids calling API.
- `Onboarding validation rejects equal start and end times with inline error`: Verified 0h input shows `'Sleep start and wake-up time cannot be the same.'` and blocks navigation.
- `Onboarding accepts valid boundaries 7.0h and 12.0h and advances on save success`: Verified 12.0h and 7.0h persist and advance to Step 2 ("Let's Go").
- `API save failure does not advance onboarding, retains settings, and displays retryable error`: Verified widget stays on Step 1, retains selections, and displays retry message upon repository exception.
- `Today's scheduled task appears, task scheduled only tomorrow does not appear`: Verified date-boundary filtering.
- `Multiple task blocks on the same day are handled without duplicate task cards`: Verified deduplication and duration sum (120m).
- `Due-today or overdue unscheduled task appears in Needs Attention and is not silently lost`: Verified section rendering and overdue badge.

### Flutter Strict Static Analysis
Command executed:
```bash
flutter analyze --fatal-infos --fatal-warnings
```
Output:
```
Analyzing equilibrium_app...
No issues found! (ran in 15.7s)
```
Exit code: **0**.

### Backend Regression Verification
Command executed in `server/`:
```bash
npm test
```
Result: **6 test suites passed, 51 tests passed, 0 failures**.
Confirmed no regressions in Phase 1 security hygiene or Phase 2A/2A.2 scheduling logic.

---

## 4. Git Working Tree Integrity
Inspection with `git status --short` confirms:
- All changes from Phase 1 (environment ignore, secret hygiene) and Phase 2A/2A.2 (deadline-feasibility solver, prefix constraint, daily targets) remain intact.
- Modifications are strictly confined to the Flutter client:
  - `equilibrium_app/lib/models/schedule.dart`
  - `equilibrium_app/lib/screens/onboarding/onboarding_screen.dart`
  - `equilibrium_app/lib/screens/today/today_screen.dart`
  - `equilibrium_app/lib/widgets/status/workload_meter.dart`
  - `equilibrium_app/lib/core/utils/workload_calculator.dart` (new)
  - `equilibrium_app/test/phase_2b1_correctness_test.dart` (new)

---

## 5. Remaining Limitations
1. **Focus Timer & Partial Completion**: In-progress tracking, countdown timer synchronization, and partial-session block rescheduling belong to Phase 2B.2.
2. **Offline Mutation Queue**: While onboarding now blocks navigation on failure, background offline sync for general CRUD operations (tasks/commitments) still requires local SQLite/Hive persistence before full offline tolerance is achieved.
3. **Multi-Timezone Transitions**: Interval calculations currently evaluate local calendar day boundaries using device local time; daylight saving transition boundaries (23h or 25h days) are handled via `difference.inMinutes`, but time-zone changing mid-day requires a fresh dashboard reload.

---

## 6. Phase 2B.1.2: Sleep Settings Contract Review & Audit Findings

A read-only contract review of Equilibrium's sleep settings across the server schema, constraint repositories, data models, Flutter onboarding pipeline, and scheduling engine was conducted.

### 1. Meaning of `minSleepHours` vs. Actual Sleep Window
- **Code Reference**:
  - `server/src/validation/schemas.ts` lines 83 & 108:
    ```typescript
    minSleepHours: z.number().min(7.0).max(12.0),
    ...
    if (sleepDuration < data.minSleepHours) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Sleep interval cannot be strictly less than minSleepHours',
        path: ['sleepEnd']
      });
    }
    ```
  - `server/prisma/schema.prisma` line 43:
    ```prisma
    model UserConstraint {
      ...
      minSleepHours Float // >= 7.0 logic enforced in API
      sleepStart    String // e.g., "23:00"
      sleepEnd      String // e.g., "06:00"
    ```
- **Contract Definition**:
  - `minSleepHours` defines a **minimum required sleep duration floor** (a baseline health policy requirement), **NOT** the actual selected sleep-window duration.
  - The actual protected sleep window is defined by `[sleepStart, sleepEnd]`.
  - The backend schema allows the user's selected window (`sleepDuration`) to be larger than `minSleepHours`, but never strictly less than `minSleepHours`.
  - In `server/src/routes/insights.routes.ts` line 17 (`const sleepMinutes = constraints ? Math.round(constraints.minSleepHours * 60) : 420;`), `minSleepHours` serves as a baseline floor for safe daily minute capacity calculations.

### 2. Value Sent by Onboarding for `minSleepHours`
- **Code Reference**:
  - `equilibrium_app/lib/screens/onboarding/onboarding_screen.dart` lines 106–113:
    ```dart
    await context.read<ConstraintRepository>().updateConstraints({
      'sleepStart': _sleepStart,
      'sleepEnd': _sleepEnd,
      'minSleepHours': 7.0,
      'bufferMinutes': 15,
      'peakEnergyWindowsJson': '[{"start":"09:00","end":"12:00"},{"start":"15:00","end":"17:00"}]',
    });
    ```
- **Contract Definition**:
  - Onboarding sends the literal float **`7.0`** for `minSleepHours`.
  - It is **NOT calculated from `sleepStart` and `sleepEnd`**.
  - The onboarding UI allows users to configure their sleep start and wake-up times via time pickers; `minSleepHours` is sent as the fixed baseline health requirement (`7.0` hours) below which Equilibrium will not permit students to schedule work.

### 3. Limits Applying to the Difference Between `sleepStart` and `sleepEnd`
- **Code Reference**:
  - `server/src/validation/schemas.ts` lines 90–114:
    ```typescript
    const start = parseTime(data.sleepStart);
    const end = parseTime(data.sleepEnd);
    let sleepDuration = end - start;
    if (sleepDuration <= 0) {
      sleepDuration += 24; // Overnight logic
    }
    if (sleepDuration > 16) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Sleep interval cannot exceed 16 hours. Please check your AM/PM logic.',
        path: ['sleepEnd']
      });
    }
    if (sleepDuration < data.minSleepHours) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Sleep interval cannot be strictly less than minSleepHours',
        path: ['sleepEnd']
      });
    }
    ```
- **Boundary Rules**:
  - **Overnight Windows**: If `end <= start`, the window wraps across midnight by adding 24 hours (`sleepDuration += 24`). E.g., `23:00` to `07:00` evaluates to `7 - 23 + 24 = 8.0` hours.
  - **Equal Start and End**: If `start == end` (e.g., `07:00` to `07:00`), `end - start = 0 <= 0` yields `sleepDuration = 24.0` hours, which triggers the `sleepDuration > 16` error and is rejected.
  - **Lower Bound**: `sleepDuration >= data.minSleepHours`. Since `minSleepHours >= 7.0`, the lowest permissible sleep interval on the backend is $7.0$ hours.
  - **Upper Bound**: `sleepDuration <= 16.0` hours at the protocol layer.

### 4. Frontend 7–12-Hour Validation vs. Intended Product Contract
- **Code Reference**:
  - `equilibrium_app/lib/screens/onboarding/onboarding_screen.dart` lines 77–95:
    ```dart
    bool _validateSleepTimes() {
      if (_sleepStart == _sleepEnd) {
        setState(() => _errorMessage = 'Sleep start and wake-up time cannot be the same.');
        return false;
      }
      final sleepHours = WorkloadCalculator.calculateSleepDurationHours(_sleepStart, _sleepEnd);
      if (sleepHours < WorkloadCalculator.minSleepHours) {
        setState(() => _errorMessage =
            'Equilibrium requires at least 7 hours of protected sleep (selected: ${sleepHours.toStringAsFixed(1)}h).');
        return false;
      }
      if (sleepHours > WorkloadCalculator.maxSleepHours) {
        setState(() => _errorMessage =
            'Sleep window cannot exceed 12 hours (selected: ${sleepHours.toStringAsFixed(1)}h). Please check your times.');
        return false;
      }
      setState(() => _errorMessage = null);
      return true;
    }
    ```
  - `equilibrium_app/lib/core/utils/workload_calculator.dart` lines 12–15:
    ```dart
    static const double minSleepHours = 7.0;
    static const double maxSleepHours = 12.0;
    static bool isValidSleepDuration(double hours) =>
        hours >= minSleepHours && hours <= maxSleepHours;
    ```
- **Contract Evaluation**:
  - **Deliberately Stricter Product Design**: The frontend is deliberately stricter than the backend's protocol ceiling ($16.0$ hours). In a university workload-balancing application, recurring daily sleep windows exceeding 12 hours leave fewer than 12 hours for classes, study sessions, and meals, causing schedule generation to become permanently infeasible.
  - **No Inadvertent Restriction**: The frontend validates the actual sleep window duration (`sleepHours`) against $[7.0, 12.0]$. It does not validate the wrong field.
  - **Full Compatibility**: Because the frontend sends `minSleepHours: 7.0` and ensures `7.0 <= sleepHours <= 12.0`, every valid onboarding selection satisfies backend validation (`7.0 <= sleepDuration <= 16.0` and `sleepDuration >= minSleepHours`). No valid intended student configuration is prevented, and no code modification is needed.

### 5. Onboarding Navigation Safety & Protected Sleep Guarantee
- **Save Failure Safety**:
  - In `equilibrium_app/lib/screens/onboarding/onboarding_screen.dart` lines 102–135, `_pageCtrl.nextPage()` is strictly placed inside the `try` block following successful `await updateConstraints(...)`.
  - If the API call fails or throws, execution jumps to `catch (e)`, `_pageCtrl.nextPage()` is never called, the user remains on Step 1, inputs are retained, and an inline retryable error message is displayed.
  - Verified by widget test: `API save failure does not advance onboarding, retains settings, and displays retryable error` (Passed).
- **Scheduler Sleep Protection**:
  - In `server/src/scheduler/capacity.ts` lines 40–57, the scheduler constructs exact Date objects for `constraints.sleepStart` and `constraints.sleepEnd` for every day across the horizon (including previous-day midnight wrap-around) and marks every intersecting 30-minute slot as `slot.available = false`.
  - In `server/src/scheduler/validator.ts` lines 32–44, the validator checks `intervalsIntersect(block.start, block.end, sleepStart, sleepEnd)` and rejects any schedule containing overlapping blocks.
  - Verified by regression test `server/test/regression.exam-prep-sleep-shield.test.ts` lines 93–119:
    `places ZERO exam-prep blocks inside 23:00–07:00 IST for an app-registered user` (Passed).

