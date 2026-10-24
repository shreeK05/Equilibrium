# Phase 3A: Core Product UX Redesign

## 1. Executive Summary & Design Rationale
Phase 3A focuses on transforming Equilibrium from a technical scheduler demonstration into an everyday university workload manager. Before this phase, the product was burdened by:
- **Cramped primary mobile navigation:** 6 destinations (`Today`, `Schedule`, `Tasks`, `Exams`, `Locked`, `Analytics`) rendered in the bottom navigation bar at an unreadable 10px font size with high touch-error rates on narrow screens.
- **Ambiguous terminology:** Hard constraints were labelled "Locked", leaving students unclear whether it meant locked tasks, premium paywalls, or fixed commitments.
- **Visual hierarchy fragmentation:** The Today screen placed the "Up Next" study task after the daily meter and re-plan button, forcing students to scroll before answering the #1 operational question: *"What should I do right now?"* Furthermore, identical task cards were duplicated across both "Up Next" and "Today's Tasks".
- **Cluttered task capture:** Creating an ordinary assignment forced students through secondary fields (category dropdowns, description text areas, flexibility settings) before asking for duration or deadline, turning quick capture into a 60–90 second chore.
- **Ad-hoc design tokens:** Arbitrary one-off colors and inconsistent border radii (some 24dp, some 16dp, some 8dp, opacity-blended whites that washed out in light mode) compromised visual coherence and contrast accessibility.

### After Redesign: Core Principles Delivered
1. **Immediate Next Action:** The "Up Next" task is positioned prominently at the top of the Today screen with a 1-tap "Start Focus" CTA button and quick "Progress" action.
2. **Four-Destination Primary Navigation:** Bottom navigation streamlined to `Today`, `Plan`, `Tasks`, and `More`. Ambiguous "Locked" has been replaced with "Fixed Commitments" and organized cleanly under "More" alongside Exams, Analytics, and Imports.
3. **15–30 Second Task Capture:** `CreateTaskSheet` prioritizes Title, fast duration chips (`15m`, `30m`, `45m`, `1h`, `1.5h`, `2h`), and deadline presets (`Today`, `Tomorrow`, `In 3 Days`), keeping secondary details (Category, Notes, Daily Pacing Target) collapsed under an optional disclosure.
4. **Cohesive Design System:** `EqTokens` and `EqColors` refined with semantic color roles (`surfaceSubtle`, `textTertiary`, `cardBorder`, `commitment`, `commitmentMuted`), unified card radii (16dp), accessible contrast ratios (> 4.5:1 text, > 6.5:1 primary), and full dark/light theme support.
5. **Timeline Differentiation Without Relying on Color Alone:** Tasks (`STUDY`), Fixed Commitments (`FIXED COMMITMENT`), and Sleep Shield (`PROTECTED REST`) feature distinct icons (`assignment`, `push_pin`, `moon`), textual tags, and visual indicators.

---

## 2. Navigation Architecture

### Primary Navigation (4 Destinations)
| Destination | Screen | Route Role |
| :--- | :--- | :--- |
| **Today** | `TodayScreen` | Daily focal point: Greeting, "Up Next" hero card with "Start Focus" CTA, planned-vs-capacity meter, sleep shield, compact "Needs Attention" alert, and scheduled work list. |
| **Plan** | `ScheduleScreen` | Algorithmic timeline view with day-by-day swipe navigation, real-time current time indicator, capacity balance, and "Reschedule" FAB. |
| **Tasks** | `TasksScreen` | Master workload organizer with categorized tabs (`Pending`, `Scheduled`, `Completed`) and swipe-to-delete. |
| **More** | `MoreScreen` | Organized secondary hub housing academic constraints, exams, analytics, and data import tools. |

### Secondary Hub ("More") Structure
1. **Academic & Schedule:**
   - **Fixed Commitments:** Classes, laboratory sections, recurring routines (`CommitmentsScreen`). Replaces ambiguous "Locked" label. Shows live active commitment count.
   - **Exam Preparation:** Exam countdowns, review pacing tracks, and milestones (`ExamsScreen`). Shows active tracks count.
2. **Data & Imports:**
   - **Import Syllabus PDF:** Automated syllabus parsing and assignment extraction (`SyllabusImportScreen`).
   - **Import Academic Calendar (.ics):** University timetable sync via iCal format (`IcsImportScreen`).
3. **Insights & Account:**
   - **Workload & Capacity Analytics:** Weekly study distribution, sleep protection metrics, and workload balance (`AnalyticsScreen`).
   - **Profile & Sleep Constraints:** Student name, bedtime, wake time, buffer minutes, and theme preferences (`ProfileScreen`).

---

## 3. Screen-by-Screen Redesign Details

### Today Screen (`today_screen.dart`)
- **Header:** Warm greeting (`GOOD MORNING` / `GOOD AFTERNOON` / `GOOD EVENING`), student name from profile, and formatted date (`Tuesday, October 24`).
- **Hero "Up Next" Card:** Highlights the active upcoming study chunk with scheduled time range (`10:00 AM – 11:30 AM`), focus duration, category, deadline, a high-visibility primary **"Start Focus"** button that opens `TimerScreen`, and a **"Progress"** action that opens `TaskProgressDialog`.
- **Daily Planned vs. Capacity Summary:** Displays `WorkloadMeter` with explicit status explanations (e.g. *"Balanced workload: 120 minutes scheduled cleanly within 480 minutes of daily study capacity"* or *"Workload exceeds available daily capacity (60m over). The scheduler has deferred low-priority tasks to protect your bedtime."*). Provides 1-tap "Re-plan remaining day" with `ReplanSummary` feedback.
- **Sleep Shield:** Visual reassurance of the protected sleep window (e.g. `11:00 PM – 7:00 AM • 8h 00m protected`).
- **Compact "Needs Attention":** Appears only when unscheduled tasks are due today or overdue. Highlights urgent items with amber warning iconography and 1-tap timer/progress actions.
- **Today's Scheduled Tasks:** Deduplicated chronological list with total scheduled minutes today and completion states.
- **First-Run Empty State:** When no tasks exist, displays a motivating empty state with one obvious action: **"Add First Task"** (immediately opens `CreateTaskSheet`).

### Quick-Add Flow (`create_task_sheet.dart`)
- **Autofocus Title:** Immediate keyboard focus for swift typing.
- **Estimated Effort Presets:** One-tap chips for common study durations (`15m`, `30m`, `45m`, `1h`, `1.5h`, `2h`), plus a `Custom` field.
- **Deadline Presets:** One-tap action chips for `Today 11:59 PM`, `Tomorrow`, `In 3 Days`, and custom date/time picker.
- **Collapsible "Additional Options":** Houses Category (`Assignment`, `Project`, `Lab Record`, `Prep`, etc.), Notes, Flexibility (`HARD` vs `FLEXIBLE`), and multi-day pacing target without cluttering the initial view.
- **What-If Schedule Preview:** "Preview schedule fit before adding" queries `simulateTask` to show whether the task fits safely before deadline without encroaching on bedtime.

### Task Progress Dialog (`task_progress_dialog.dart`)
- Refined action card backgrounds and borders to use `colors.surfaceElevated` and `colors.cardBorder` for accessible contrast in both light and dark modes.
- Preserved 100% of the Phase 2B.2.3 idempotency and recovery architecture:
  - `PendingOperationManager` persistent state in `SharedPreferences`.
  - Re-use of `operationId` across network timeouts and ambiguous failures.
  - Distinct handling of definite validation rejections (HTTP 400) vs. ambiguous server commits.
  - Ambiguous recovery banner with "Retry Pending Update" reconciliation.

### Schedule & Plan Screen (`schedule_screen.dart` & `timeline_block_absolute.dart`)
- Tasks (`STUDY` tag with assignment icon), Commitments (`FIXED COMMITMENT` tag with pushpin icon), and Sleep Shield (`PROTECTED REST` with night icon) are clearly distinguishable by typography and iconography, not just color.
- Reschedule FloatingActionButton uses accessible high-contrast typography (`Colors.white` on `colors.primary`).
- Responsive layout handles narrow phone widths (320px–360px) without horizontal flex overflows.

---

## 4. Design System Tokens & Color Roles

### Semantic Color Tokens (`colors.dart`)
| Token | Light Theme | Dark Theme | Purpose & Contrast |
| :--- | :--- | :--- | :--- |
| `primary` | `#4F46E5` (Indigo 600) | `#818CF8` (Indigo 400) | Brand primary, action buttons, active states (contrast > 5.5:1). |
| `background` | `#F8FAFC` (Slate 50) | `#0B0F19` (Deep Slate) | Calm, distraction-free screen canvas. |
| `surface` | `#FFFFFF` (White) | `#161E2E` (Slate 850) | Primary cards, sheets, navigation bars. |
| `surfaceElevated` | `#F1F5F9` (Slate 100) | `#222F44` (Slate 750) | Input fields, chips, secondary cards. |
| `textPrimary` | `#0F172A` (Slate 900) | `#F8FAFC` (Slate 50) | Headings, titles, primary text (AAA contrast > 10:1). |
| `textSecondary` | `#475569` (Slate 600) | `#94A3B8` (Slate 400) | Subtitles, helper text, labels (AA contrast > 5:1). |
| `cardBorder` | `#E2E8F0` (Slate 200) | `#263347` (Slate 700) | Subtle, structured card and input outlines. |
| `commitment` | `#0284C7` (Sky 600) | `#38BDF8` (Sky 400) | Fixed classes, labs, routines (distinct from study tasks). |
| `sleepShield` | `#4338CA` (Indigo 700) | `#818CF8` (Indigo 400) | Protected sleep window boundary. |
| `success` | `#059669` (Emerald 600) | `#34D399` (Emerald 400) | Completed tasks, fits safely status. |
| `warning` | `#D97706` (Amber 600) | `#FBBF24` (Amber 400) | Deferred tasks, capacity overload, needs attention. |
| `danger` | `#DC2626` (Red 600) | `#F87171` (Red 400) | Delete actions, errors, overdue tasks. |

---

## 5. Files Changed

| File Path | Description of Changes |
| :--- | :--- |
| `lib/core/theme/colors.dart` | Added semantic tokens (`cardBorder`, `surfaceSubtle`, `textTertiary`, `commitment`, `commitmentMuted`), refined WCAG-accessible light/dark palettes. |
| `lib/core/theme/tokens.dart` | Added fine-grained spacing tokens (`space2`, `space6`, `space10`, `space28`, `space40`), `shadowSubtle`, and `shadowCard`. |
| `lib/core/theme/theme.dart` | Unified component themes (`cardTheme`, `bottomNavigationBarTheme`, `inputDecorationTheme`, `elevatedButtonTheme`, `outlinedButtonTheme`, `chipTheme`, `bottomSheetTheme`, `dividerTheme`). |
| `lib/widgets/layout/app_shell.dart` | Simplified navigation to 4 tabs (`Today`, `Plan`, `Tasks`, `More`), polished `_showQuickAdd` sheet, preserved timer FAB and offline indicator. |
| `lib/screens/more/more_screen.dart` | **New file:** Secondary hub organizing Commitments, Exams, Analytics, Syllabus/ICS Imports, and Profile settings. |
| `lib/screens/today/today_screen.dart` | Implemented Up Next hero card with "Start Focus" CTA, clear planned-vs-capacity explanations, compact Needs Attention, and actionable empty state. |
| `lib/widgets/forms/create_task_sheet.dart` | Streamlined quick capture: Title, Duration chips, Deadline presets, collapsed secondary options, What-If simulation preview. |
| `lib/widgets/cards/task_card.dart` | Unified card radius to `border16`, subtle elevation, accessible borders. |
| `lib/widgets/timeline/timeline_block_absolute.dart` | Added distinct icons and type tags (`STUDY`, `FIXED COMMITMENT`, `REST BREAK`) to differentiate commitments without relying on color alone. |
| `lib/screens/schedule/schedule_screen.dart` | Improved small-screen usability, accessible navigation labels, high-contrast reschedule CTA. |
| `lib/widgets/dialogs/task_progress_dialog.dart` | Refined action tile styling using `surfaceElevated` and `cardBorder` while preserving all idempotency and recovery logic. |
| `test/phase_3a_ux_test.dart` | **New file:** 8 comprehensive widget tests verifying navigation, More hub, Today visual priority, Up Next card, quick add validation, and narrow phone rendering. |

---

## 6. Verification & Test Results

### 1. Flutter Unit & Widget Test Suite
```bash
flutter test
```
**Result:** **66 passed, 0 failed** across all test suites:
- 18 baseline correctness tests (`phase_2b1_correctness_test.dart`)
- 19 task progress & persistent idempotency tests (`phase_2b2_progress_test.dart`)
- 8 Phase 3A UX & navigation redesign tests (`phase_3a_ux_test.dart`)
- 21 legacy widget & routing tests (`widget_test.dart`, `v3_widget_test.dart`, `auth_routing_test.dart`)

### 2. Flutter Static Analysis
```bash
flutter analyze --fatal-infos --fatal-warnings
```
**Result:** **0 issues found** (Clean analysis).

### 3. Flutter Web Release Build
```bash
flutter build web --release
```
**Result:** **Built build/web in 101.1s** with tree-shaken font assets and 0 compile errors.

### 4. Server Regression Test Suite
```bash
npm test
```
**Result:** **98 passed, 98 total** across all 8 backend test suites (scheduler knapsack, placement, idempotency operations, secrets hygiene, and sleep capacity).

---

## 7. Remaining Boundaries & Phase 3B Recommendations
1. **Interactive Focus Session Transitions:** While "Start Focus" directly opens `TimerScreen` with the task preset, Phase 3B can introduce inline ambient timers directly on the Today screen.
2. **Weekly Calendar View on Tablet/Desktop:** On large screens, the Plan view currently defaults to single-day scrolling. A responsive multi-day grid can be expanded in Phase 3B.
3. **Data Integrity Guarantee:** Zero backend schemas, API contracts, or database migrations were altered in this phase. All progress semantics, persistent idempotency, and sleep protection algorithms remain completely intact.
