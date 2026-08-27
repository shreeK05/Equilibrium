# Schedule UI

## Timeline Rendering Strategy
The timeline uses a strict continuous spatial approach driven by operations-research mathematics rather than abstract CRUD lists.

1. **Grid Allocation**: The viewport is partitioned into a fixed 24-hour cycle. 
2. **Absolute Dimensions**: 1 minute of scheduled time equates to 1.5 logical pixels.
3. **Multi-Day Constraints**: Day boundaries are respected. Tasks crossing midnight (typically `SLEEP`) are rendered across split boundaries or constrained naturally by continuous scrolling.
4. **Desktop Responsiveness**: The grid restricts itself to an 800px max-width boundary on widescreen/desktop formats rather than stretching uncomfortably.
5. **No Visual Hallucination**: Flutter does not guess where a block goes. The backend `ScheduleVersion.blocks` array provides exact `startTime` and `durationMinutes`.

## Widget Architecture
* `ScheduleTimeline`: Wraps multi-day lists.
* `TimelineGridBackground`: The CustomPainter that draws the 30-minute interval hour-lines.
* `AbsoluteTimelineBlock`: The physical bounds-wrapper for `TASK`, `FIXED`, and `FREE` blocks, enforcing precise `top` and `height` properties.
* `AbsoluteSleepShield`: An immutable blocker simulating the constraint graph overlay for overnight sleep.
* `CurrentTimeIndicator`: A highly performant single-widget stateful clock that drifts down the timeline independently of parent rebuilds.
