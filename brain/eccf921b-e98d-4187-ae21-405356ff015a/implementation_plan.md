# Phase 7 — Signature Schedule UI Implementation Plan

## Goal Description
Build a production-quality "Signature Schedule" experience in Flutter. The UI will visually communicate that Equilibrium is an autonomous operations-research optimization engine by exposing true backend scheduling logic, protecting sleep, avoiding fixed commitments, splitting tasks, and indicating past (locked) blocks. 

## Open Questions
- None. The backend provides `ScheduleVersion` and `ScheduleBlock` correctly, mapped via `triggerType` and `type` (TASK, SLEEP, FIXED, BREAK, FREE).

## Proposed Changes

### Core Models & Providers
#### [MODIFY] `equilibrium_app/lib/models/task.dart`
- Add parsing for `cognitiveLoad` and `status` in `fromJson`.

#### [MODIFY] `equilibrium_app/lib/models/schedule.dart`
- Ensure `ScheduleVersion.previousVersionId` is parsed if available to support visual continuity later.

### Signature Timeline Components
#### [MODIFY] `equilibrium_app/lib/widgets/timeline/timeline.dart`
- Complete redesign. Instead of a vertical list of disjointed cards, implement a day-grouped `ListView` where each day is a continuous `Stack` (e.g. 1 minute = 1.5 pixels). 
- Introduce `TimelineGridBackground` to draw the time axis and 30-minute grid lines.
- Wrap the timeline in a `CustomScrollView` to gracefully handle headers and multiple days.

#### [MODIFY] `equilibrium_app/lib/widgets/timeline/timeline_block.dart`
- Make it absolute-positioned within the stack.
- Expand presentation to include chunks (e.g. "Part 1 of 2"), deadline context, and Cognitive Load where applicable.

#### [NEW] `equilibrium_app/lib/widgets/timeline/timeline_day.dart`
- Renders a single 24-hour day (or clipped day) using a `Stack` of blocks.

#### [NEW] `equilibrium_app/lib/widgets/timeline/current_time_indicator.dart`
- A red/accent line positioned dynamically over the timeline at the exact `DateTime.now()` vertical offset, updating on a 1-minute timer.

### Specialized Blocks
#### [MODIFY] `equilibrium_app/lib/widgets/timeline/sleep_shield.dart`
- Redesign as an absolute-positioned block that spans the timeline width with a hatched or deep-blue "protected" visual treatment, distinct from task blocks.

#### [NEW] `equilibrium_app/lib/widgets/timeline/fixed_commitment_block.dart`
- Distinct visual block for classes/labs to communicate "immovable constraint."

### Explainability & Empty States
#### [MODIFY] `equilibrium_app/lib/screens/schedule/schedule_screen.dart`
- Implement custom Empty, Partially Scheduled, and Overcapacity states using EqTokens.
- Pass tasks from the provider to the timeline so blocks can look up task metadata (title, estimate).

#### [MODIFY] `equilibrium_app/lib/widgets/forms/task_detail_sheet.dart`
- Add an "Explainability Hook" button ("Why was this scheduled?") pointing to a stub or future view.

## Verification Plan
### Automated Tests
- Run full Flutter widget tests verifying grid layout, time calculations, task metadata presentation, and empty states.
- Run `npx jest` to ensure no backend regressions occur (already stable from 6.5).

### Manual Verification
- Visual inspection of overnight sleep wrapping and chunk continuation on Flutter desktop/mobile targets.
