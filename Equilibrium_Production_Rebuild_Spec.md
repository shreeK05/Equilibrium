# EQUILIBRIUM — Production UI/UX & Full-Stack Rebuild Specification
## Version 2.0 — From-Scratch Student Productivity Platform

> **Purpose:** This document replaces the current visual/interaction implementation with a production-quality, student-first experience. Do not merely patch the existing screens. Rebuild the frontend UX layer and harden the backend/data flow so every visible feature is functional, persistent, testable, and resilient.

---

# 1. PRODUCT VISION

Equilibrium should feel like a **premium personal operating system for an Indian college student**, not a generic To-Do app or calendar.

The product must answer one question immediately:

> **"What should I do now, and can I realistically finish everything before my deadlines?"**

The application combines:

- Tasks and assignments
- Deadlines
- College timetable / fixed commitments
- Exams and preparation planning
- Custom routines
- Focus timer
- Actual study-time tracking
- Daily/weekly workload dashboard
- Notifications/reminders
- Rescheduling
- Progress analytics
- Student profile
- Light/Dark/System theme
- Offline-first behavior with backend synchronization

The design must be **calm, intelligent, premium, animated, and highly usable with one hand**.

---

# 2. IMPORTANT: CURRENT APP PROBLEMS TO FIX

The supplied APK screenshots show that the current implementation is technically recognizable but visually and functionally feels unfinished.

## 2.1 Visual problems

Current screens have:

- Very large empty/grey placeholder regions.
- Excessive unused vertical space.
- Weak information hierarchy.
- Generic dark UI.
- Flat cards with little visual identity.
- Bottom navigation that feels like a template.
- Empty states that dominate the screen.
- Buttons that look disconnected from the surrounding design.
- Profile screen resembles a form rather than a premium student profile.
- Schedule is visually heavy but does not communicate useful information quickly.
- "Running offline" is shown prominently instead of gracefully handling connection state.
- No strong sense of progress, achievement, momentum, or personalization.
- Limited animation/micro-interaction.
- No visual storytelling of the student's day.

## 2.2 Functional UX problems

The rebuild must prevent:

- Tasks disappearing because of incorrect state filters.
- Planned/remaining values becoming inconsistent.
- Schedule showing only a narrow time range without useful context.
- Routines being treated as immutable hard-coded items.
- Timer sessions not being associated with tasks.
- Completion state not propagating to dashboard analytics.
- Rescheduling not updating dependent reminders.
- Data being lost after app restart.
- Backend failures being exposed as confusing UI.
- Loading/error/empty states looking like broken screens.

---

# 3. CORE DESIGN PRINCIPLE

## The app should be "Now-first"

The Today screen should not be a list of everything.

It should intelligently show:

1. Current status
2. What is happening now
3. What needs attention next
4. Today's workload
5. Upcoming deadlines
6. Quick action

Example:

**Good evening, Shreeyash**

### Your day
**2h 40m** planned
**1h 15m** completed
**1h 25m** remaining

`██████████████░░░░░`

### Focus now
**DBMS Assignment**
Due tomorrow • 45 min estimated

[ Start Focus ]

### Coming up
6:30 PM — Gym
7:30 PM — Dinner
8:15 PM — DBMS Assignment

### Deadline radar
🔴 DBMS Assignment — Tomorrow
🟠 CN Lab Record — 2 days
🟡 Maths Revision — 5 days

This is much more useful than a blank page.

---

# 4. BRAND / VISUAL IDENTITY

## Product personality

Equilibrium should communicate:

- Calm
- Intelligent
- Focused
- Modern
- Academic
- Premium
- Personal
- Reliable

Avoid:

- Generic Material UI appearance
- Excessive gradients
- Excessive glassmorphism
- Neon gaming aesthetics
- Overly corporate dashboards
- Huge empty cards
- Excessive text
- Decorative animation that slows the user down

## Visual language

Use:

- Strong typography hierarchy
- Soft rounded cards
- Subtle depth
- Fine borders
- Contextual accent colors
- Large but purposeful numbers
- Progress rings/bars
- Timeline visualization
- Compact chips
- Smooth transitions
- Motion based on user action

The app should feel closer to a premium productivity/finance/fitness app than a college CRUD project.

---

# 5. DESIGN SYSTEM

## Typography

Use a modern highly readable font available reliably on Android.

Suggested:

- Inter
- Plus Jakarta Sans
- SF-style system fallback

Typography scale:

- Display: 32–38sp
- H1: 28–32sp
- H2: 22–26sp
- H3: 18–20sp
- Body: 15–17sp
- Caption: 12–14sp

Do not make every label uppercase.

Use uppercase only for small section labels when useful.

## Shape

- Primary cards: 20–24dp radius
- Buttons: 14–18dp radius
- Chips: pill radius
- Inputs: 14–16dp radius
- Bottom sheet: 28dp top radius
- FAB: 18–22dp radius

## Spacing

Use an 8dp spacing system.

Avoid screens where content touches screen edges.

## Colors

Support three modes:

- System
- Light
- Dark

Do not simply invert dark colors.

Define separate semantic tokens:

- background
- surface
- surfaceElevated
- textPrimary
- textSecondary
- textMuted
- border
- accent
- success
- warning
- danger
- info

Task priority colors should remain understandable in both themes.

---

# 6. MOTION SYSTEM

Animations are REQUIRED but must remain fast and purposeful.

## Screen transitions

- 180–280ms
- Fade + slight horizontal/vertical movement
- Shared-element style transitions where practical

## Cards

On entry:

- Fade in
- 8–12dp upward movement

On completion:

- Checkmark animation
- Progress update animation
- Card slightly compresses then settles
- Optional subtle celebration for major milestones

## Timer

- Smooth progress ring
- Pulsing focus indicator
- Start/pause transition
- Completion animation

## Bottom sheets

- Spring-based entrance
- Proper drag-to-dismiss
- Backdrop fade

## Theme switch

Use a smooth crossfade rather than an abrupt color change.

## Accessibility

Respect Android reduced-motion settings where available.

Animations must never block interaction.

---

# 7. INFORMATION ARCHITECTURE

Replace the current bottom navigation with:

1. **Today**
2. **Plan**
3. **Tasks**
4. **Exams**
5. **Profile**

The timer should be globally accessible through:

- "Start Focus" button
- Task action
- Floating quick action
- Today screen

"Locked" should become **Profile → Routines/Commitments** rather than a confusing top-level destination.

---

# 8. TODAY SCREEN — PRIMARY EXPERIENCE

This is the most important screen.

## Header

Show:

- Greeting based on time
- Student name
- Date
- Profile avatar
- Sync state as a small indicator only

Do NOT display "Running offline." as a dominant heading.

Example:

**Good evening, Shreeyash**
Tuesday, 8 September

Small sync indicator:
`● Synced`

If offline:
`● Offline — changes saved locally`

## Daily progress

Show:

- Planned time
- Completed time
- Remaining time
- Completion percentage

Example:

`1h 15m / 2h 40m`

Circular or horizontal progress.

## Current focus card

If a task is active/upcoming:

- Task name
- Subject/category
- Estimated duration
- Deadline
- Priority
- Start button
- Mark complete button

## Next up timeline

Example:

`6:30` Gym
`7:30` Dinner
`8:15` DBMS Assignment
`9:15` Revision

Use a vertical timeline.

## Deadline radar

Show the 3–5 most urgent tasks.

Use urgency intelligently:

- Overdue
- Due today
- Due tomorrow
- Due this week
- Later

## Quick add

One FAB:

`+`

Tap opens a polished bottom sheet:

- Task
- Focus session
- Fixed commitment
- Exam
- Routine

---

# 9. TASK SYSTEM

Tasks must be first-class objects.

## Task fields

Required:

- id
- title
- description
- subject/category
- priority
- status
- estimatedMinutes
- actualMinutes
- dueDateTime
- createdAt
- updatedAt

Optional:

- scheduledStart
- scheduledEnd
- recurringRule
- tags
- color/icon
- examId
- reminder settings
- notes
- subtasks

## Status

Use:

- TODO
- SCHEDULED
- IN_PROGRESS
- COMPLETED
- OVERDUE
- ARCHIVED

## Task interaction

Every task should support:

- Complete
- Edit
- Delete/archive
- Reschedule
- Start timer
- Change priority
- Change deadline
- Change duration
- Add note
- Add reminder

Swipe actions may be used, but never as the only way to perform important actions.

---

# 10. DEADLINE CUSTOMIZATION

User explicitly needs customizable deadlines.

When creating/editing a task:

### Deadline

- No deadline
- Today
- Tomorrow
- Custom date
- Custom date + time

### Reminder

- At deadline
- 10 min before
- 30 min before
- 1 hour before
- 3 hours before
- 1 day before
- Custom

The user must be able to change these later.

Changing a deadline must update:

- Dashboard
- Schedule
- Deadline radar
- Notifications
- Workload calculations

---

# 11. COMPLETION SYSTEM

Every task must have a clearly visible completion action.

When completed:

- Status changes to COMPLETED
- completion timestamp is stored
- actual focus time remains stored
- dashboard recalculates
- schedule recalculates
- task moves to Completed
- analytics update
- optional celebration animation

Allow:

**Undo completion**

for a short period.

---

# 12. TIMER / FOCUS MODE

This is a major differentiating feature.

## Timer types

### Stopwatch mode

For:

> "How long did I actually take to finish this assignment?"

Start → work → stop.

Record:

- start time
- end time
- duration
- task
- subject

### Countdown mode

For:

> "I want to study for 60 minutes."

User selects:

- 15 min
- 25 min
- 45 min
- 60 min
- Custom

### Pomodoro

Optional:

- 25/5
- 50/10
- Custom

## Focus screen

Full-screen distraction-free interface:

**DBMS Assignment**

`42:18`

Progress ring

[ Pause ]

[ Finish Session ]

[ Cancel ]

Show task context without unnecessary controls.

## On finish

Ask:

**How did the session go?**

- Completed
- Partially completed
- Need more time

Then:

- Save actual duration
- Update task
- Update analytics
- Offer reschedule if unfinished

---

# 13. STUDY ANALYTICS

Add an Analytics section under Profile or Today.

Track:

- Total study time
- Focus sessions
- Tasks completed
- Average session duration
- Planned vs actual time
- Completion rate
- Most productive day
- Most productive time
- Subject-wise study time

Weekly visualization:

`Mon Tue Wed Thu Fri Sat Sun`

Avoid meaningless charts.

Every chart must answer a useful question.

---

# 14. SCHEDULE / PLAN SCREEN

Current schedule must be rebuilt.

## Features

- Day view
- Week view
- Date selector
- Current time indicator
- Scrollable 24-hour timeline
- Fixed commitments
- Scheduled tasks
- Study sessions
- Routines

## Important

The schedule should NOT automatically occupy the entire screen with a sleep block.

Show meaningful time ranges.

Allow:

- Zoom/scroll
- Tap event
- Edit
- Drag to reschedule where practical

## Smart reschedule

If the user moves a task:

Check:

- Fixed commitments
- Sleep
- Other tasks
- Exam deadlines

Then suggest a feasible alternative.

---

# 15. ROUTINES / CUSTOMIZABLE COMMITMENTS

This replaces the concept of hard-coded gym/dinner/sleep assumptions.

## Routine examples

- Gym
- Breakfast
- Lunch
- Dinner
- Commute
- College
- Library
- Sleep
- Prayer/meditation
- Part-time work
- Custom

Everything must be customizable.

## Routine configuration

Each routine can have:

- Name
- Icon
- Start time
- End time
- Days
- Enabled/disabled
- Flexible/fixed
- Reminder
- Color

Example:

**Gym**
Mon/Wed/Fri
7:00 PM – 8:00 PM

The student can change it to:

**Gym**
Tue/Thu/Sat
6:30 AM – 7:30 AM

No hard-coded assumptions.

---

# 16. SLEEP SHIELD

Sleep is a special routine because the planner should avoid scheduling study during it.

But it must be configurable.

Fields:

- Sleep start
- Sleep end
- Minimum sleep duration
- Enabled/disabled

If a deadline conflicts with sleep, show:

> "You have 3h 20m of work left before tomorrow's deadline. Your current schedule leaves only 2h 10m."

Then offer:

- Reschedule
- Reduce planned duration
- Move flexible routine
- Continue anyway

Never silently destroy the user's schedule.

---

# 17. EXAM MANAGEMENT

## Exam object

- Subject
- Exam name
- Date
- Time
- Location
- Syllabus/topics
- Preparation target
- Priority

## Preparation

Each exam can contain topics:

Example:

**DBMS**

- ER Model
- SQL
- Normalization
- Transactions
- Indexing

Each topic:

- Not started
- Learning
- Practiced
- Confident

## Exam dashboard

Show:

- Days remaining
- Preparation %
- Topics remaining
- Planned study hours
- Completed study hours

## Smart preparation planning

Break available preparation time across topics while respecting:

- Existing commitments
- Sleep
- Other deadlines
- Daily workload limits

---

# 18. INDIAN COLLEGE STUDENT ORIENTATION

The app should support realistic student workflows.

## Common academic tasks

Examples:

- Assignment
- Lab record
- Journal
- Viva preparation
- Practical preparation
- Internal exam
- End-sem exam
- Unit test
- Presentation
- Seminar
- Mini project
- Major project
- Coursera/NPTEL work
- Coding practice
- Placement preparation
- Internship applications

## Subjects

Allow custom subjects such as:

- DSA
- DBMS
- OS
- CN
- AI/ML
- Mathematics
- Deep Learning
- MLOps
- Blockchain
- Electives

Do not hard-code a particular college.

---

# 19. SYLLABUS IMPORT

Keep the existing import concept, but improve it.

User can:

- Upload PDF
- Upload document
- Paste syllabus text

System extracts:

- Subjects
- Units
- Topics

Always show a confirmation screen before creating data.

Example:

**We found 6 subjects**

[ Review ]

User can edit before importing.

---

# 20. PROFILE

Profile should feel like a real student profile, not a settings form.

## Header

Avatar

**Shreeyash Satish Kamble**

B.Tech • Computer Engineering

Semester 7

College/University

## Profile completion

`80% complete`

Allow editing:

- Full name
- College
- Degree
- Branch
- Semester/year
- Academic goals
- Daily study target

## Preferences

- Theme
- Notifications
- Default focus duration
- Start-of-day
- End-of-day
- Week starts on
- Time format

---

# 21. THEME

Three options:

- System
- Light
- Dark

Theme must apply to the entire app consistently.

No hard-coded black backgrounds.

No hard-coded white text.

All UI must use theme tokens.

Test every screen in both Light and Dark mode.

---

# 22. NOTIFICATIONS

Notifications should be useful rather than noisy.

Types:

- Upcoming task
- Deadline warning
- Exam reminder
- Focus session complete
- Overload warning
- Reschedule suggestion
- Daily brief

Allow individual toggles.

User must be able to disable every category.

---

# 23. DAILY BRIEF

Optional morning/evening summary.

Example:

**Good morning, Shreeyash**

Today:

- 3 tasks
- 2h 30m planned
- 1 deadline tomorrow
- 1 exam in 6 days

**Priority:** DBMS Assignment

**Suggested focus:** 9:00–9:45 AM

---

# 24. SMART WORKLOAD ENGINE

The backend/service layer should calculate:

- plannedMinutes
- completedMinutes
- remainingMinutes
- overdueMinutes
- availableMinutes
- workloadRatio

Example:

Available study time:
`4h 30m`

Required work:
`5h 20m`

Then:

**Overloaded by 50 minutes**

Offer automatic rescheduling.

Never simply display contradictory values such as:

`30m planned`
`0m remaining`

unless 30m is genuinely completed.

---

# 25. RESCHEDULING ENGINE

When a task is unfinished:

Inputs:

- task duration remaining
- deadline
- fixed commitments
- routines
- sleep
- daily study target
- existing scheduled tasks

Output:

1. Best slot
2. Alternative slot
3. Another-day option

Example:

> DBMS Assignment needs 45 minutes.
>
> Recommended:
> Today 8:30–9:15 PM
>
> Alternative:
> Tomorrow 7:30–8:15 AM

User must approve rescheduling.

---

# 26. BACKEND ARCHITECTURE

The backend must be production-oriented.

Recommended structure:

```text
backend/
├── auth/
├── users/
├── profiles/
├── tasks/
├── schedules/
├── routines/
├── commitments/
├── exams/
├── topics/
├── focus-sessions/
├── notifications/
├── analytics/
├── sync/
└── common/
```

Use:

- DTOs
- validation
- service layer
- repository/data-access layer
- centralized exception handling
- authentication
- authorization
- database migrations
- logging
- transaction management
- pagination where required

Do not put business logic directly in controllers.

---

# 27. DATABASE MODEL

Minimum entities:

```text
User
StudentProfile
Subject
Task
SubTask
Routine
Commitment
ScheduleBlock
Exam
ExamTopic
FocusSession
NotificationPreference
Notification
DailySummary
WeeklyAnalytics
```

Important relationships must use foreign keys.

Use indexes on:

- user_id
- due_date
- status
- scheduled_start
- exam_date

Store timestamps consistently.

---

# 28. API CONTRACT

Minimum REST endpoints:

## Auth

```text
POST /api/auth/login
POST /api/auth/register
POST /api/auth/refresh
POST /api/auth/logout
```

## Profile

```text
GET /api/profile
PUT /api/profile
```

## Tasks

```text
GET /api/tasks
POST /api/tasks
GET /api/tasks/{id}
PUT /api/tasks/{id}
DELETE /api/tasks/{id}
POST /api/tasks/{id}/complete
POST /api/tasks/{id}/reschedule
```

## Timer

```text
POST /api/focus-sessions/start
POST /api/focus-sessions/{id}/pause
POST /api/focus-sessions/{id}/resume
POST /api/focus-sessions/{id}/complete
GET /api/focus-sessions
```

## Schedule

```text
GET /api/schedule/day
GET /api/schedule/week
POST /api/schedule
PUT /api/schedule/{id}
DELETE /api/schedule/{id}
POST /api/schedule/reschedule
```

## Routines

```text
GET /api/routines
POST /api/routines
PUT /api/routines/{id}
DELETE /api/routines/{id}
```

## Exams

```text
GET /api/exams
POST /api/exams
GET /api/exams/{id}
PUT /api/exams/{id}
DELETE /api/exams/{id}
POST /api/exams/{id}/topics
```

## Dashboard

```text
GET /api/dashboard/today
GET /api/dashboard/week
GET /api/analytics
```

---

# 29. OFFLINE-FIRST REQUIREMENT

The current "Running offline" experience must be redesigned.

When offline:

- App remains usable.
- New tasks can be created.
- Tasks can be completed.
- Timer can run.
- Local changes are stored.
- UI shows a subtle offline indicator.
- Changes sync automatically when connection returns.

Conflict handling:

- Server timestamp
- Client timestamp
- deterministic merge rules
- user notification for conflicts that cannot be safely merged

Never lose user data because of temporary connectivity.

---

# 30. LOADING STATES

Do NOT show huge grey rectangles.

Use:

- Small skeleton cards
- Shimmer only where useful
- Correct content-shaped placeholders

Example:

Task skeleton should resemble an actual task card.

Never block the whole screen for a small API request.

---

# 31. EMPTY STATES

Empty states must be useful.

Instead of:

"No exams yet"

Use:

**No exams added**

Add your next exam and Equilibrium will help break preparation into manageable sessions.

[ Add Exam ]

Use an illustration/icon that matches the product identity.

---

# 32. ERROR STATES

Example:

**Couldn't sync your schedule**

Your changes are safe on this device.

[ Retry ]

No raw exception messages.

No blank screens.

No crashes.

---

# 33. ACCESSIBILITY

Support:

- Screen reader labels
- Minimum touch target 44–48dp
- Sufficient contrast
- Dynamic font scaling
- Reduced motion
- Clear focus states
- Semantic buttons
- No icon-only critical actions without labels

---

# 34. PERFORMANCE

Targets:

- Fast cold start
- Smooth 60fps scrolling
- No unnecessary API calls
- Debounced search
- Cached dashboard data
- Paginated large task lists
- Efficient image loading
- No memory leaks
- Timer must remain accurate when app goes background

Timer must calculate elapsed time using timestamps, not just increment a UI counter.

---

# 35. SECURITY

Implement:

- Secure password handling
- Token-based authentication
- Refresh token strategy
- Password validation
- Authorization checks
- Input validation
- SQL injection protection
- No secrets committed to Git
- Environment variables
- HTTPS-ready configuration
- Secure local token storage

IMPORTANT:

Never hard-code the test credentials in the application source.

---

# 36. TESTING REQUIREMENTS

## Backend

Unit tests for:

- Task creation
- Completion
- Deadline changes
- Rescheduling
- Workload calculations
- Exam preparation
- Routine conflicts
- Timer sessions
- Authentication

Integration tests for:

- Auth → API
- Task → dashboard
- Task → schedule
- Timer → analytics
- Exam → preparation
- Offline sync

## Frontend

Test:

- Login
- Navigation
- Create task
- Edit task
- Complete task
- Reschedule
- Start timer
- Pause timer
- Finish timer
- Add exam
- Add routine
- Change theme
- Edit profile
- Notification settings

---

# 37. CRITICAL END-TO-END TEST SCENARIO

Perform this exact scenario before calling the app complete.

### Step 1
Login.

### Step 2
Create:

**DBMS Assignment**

- Due tomorrow
- Estimated 60 minutes
- High priority

### Step 3
Verify it appears on:

- Today
- Tasks
- Dashboard

### Step 4
Schedule it for 8:00 PM.

Verify it appears on Schedule.

### Step 5
Start Focus Timer from the task.

### Step 6
Run for a test duration.

### Step 7
Finish session.

Verify:

- Actual time stored
- Task progress updated
- Dashboard completed time updated
- Analytics updated

### Step 8
Mark task completed.

Verify:

- Task moves to Completed
- Remaining workload decreases
- Completion timestamp stored

### Step 9
Change deadline.

Verify all dependent screens update.

### Step 10
Turn on airplane mode.

Create another task.

Verify local persistence.

### Step 11
Reconnect.

Verify automatic sync.

### Step 12
Switch:

System → Light → Dark.

Verify every screen.

### Step 13
Add:

**Gym**

Mon/Wed/Fri
7:00–8:00 PM

Change it to:

Tue/Thu/Sat
6:30–7:30 AM

Verify schedule updates.

### Step 14
Add exam:

**DBMS**
10 days away.

Add 5 topics.

Verify preparation dashboard.

---

# 38. UI SCREEN CHECKLIST

The final app must contain polished versions of:

- Splash
- Onboarding
- Login
- Register
- Forgot password
- Today
- Schedule day
- Schedule week
- Task list
- Task details
- Add task
- Edit task
- Focus timer
- Focus session result
- Exams
- Exam details
- Exam preparation
- Add exam
- Routines
- Add routine
- Commitments
- Analytics
- Profile
- Edit profile
- Notifications
- Appearance
- Import syllabus
- Sync/error states

Every screen needs:

- Loading state
- Empty state
- Error state
- Success state where relevant

---

# 39. QUICK ACTIONS

Global `+` action should intelligently expose:

```text
Add Task
Start Focus
Add Exam
Add Routine
Add Commitment
```

The selected action should open the appropriate form immediately.

---

# 40. MICRO-INTERACTIONS

Implement:

- Haptic feedback on important actions where supported
- Animated checkbox completion
- Button press scale
- Progress animation
- Timer ring animation
- Pull-to-refresh
- Swipe-to-complete where appropriate
- Snackbar for success
- Undo action
- Smooth bottom sheets
- Animated tab indicator
- Animated counters

Do not over-animate.

---

# 41. DASHBOARD METRICS

Today:

```text
Planned
Completed
Remaining
Completion %
Focus time
Tasks remaining
Deadlines
```

Week:

```text
Total planned
Total completed
Average daily focus
Completion rate
Overloaded days
Upcoming exams
```

---

# 42. REALISTIC STUDENT EXAMPLE

A student may have:

```text
8:00–9:00 College
9:00–11:00 Lectures
11:30–12:30 Lab
1:00 Lunch
2:00–4:00 Free
5:00–6:00 Assignment
7:00–8:00 Gym
8:30 Dinner
9:00–10:00 Exam preparation
11:30 Sleep
```

The system should understand that only certain periods are available for flexible study.

It should not blindly stack tasks on top of fixed commitments.

---

# 43. FINAL UI QUALITY BAR

Before completion, compare the application against this standard:

### It must NOT look like:

- College CRUD project
- Generic Material template
- Blank dashboard
- Prototype
- Form-heavy admin panel

### It SHOULD look like:

- A premium consumer productivity application
- Personalized to the student
- Visually calm
- Data-rich without being cluttered
- Fast
- Responsive
- Animated
- Trustworthy
- Production-ready

---

# 44. NON-NEGOTIABLE IMPLEMENTATION RULES FOR ANTIGRAVITY

1. **Do not only modify colors.**
2. **Do not keep the current generic layouts just with new cards.**
3. **Do not use grey placeholder blocks as final UI.**
4. **Do not hard-code routines such as gym/dinner.**
5. **Do not fake API responses.**
6. **Do not use mock data in production flows.**
7. **Every button must perform a real action.**
8. **Every mutation must persist.**
9. **Every screen must handle loading/error/empty states.**
10. **Every feature must be connected end-to-end.**
11. **Do not break existing authentication.**
12. **Do not hard-code credentials.**
13. **Do not silently discard data.**
14. **Do not claim a feature works without testing it.**
15. **Do not stop at UI implementation.**
16. **Backend, database, API, frontend, persistence, notifications and synchronization must work together.**
17. **Use reusable components and design tokens.**
18. **Avoid duplicated business logic between screens.**
19. **Run automated tests before completion.**
20. **Build a release APK after successful validation.**

---

# 45. REQUIRED FINAL DELIVERABLE

Antigravity must produce:

### Frontend

- Complete redesigned UI
- Light mode
- Dark mode
- System mode
- Animations
- Responsive layouts
- Accessibility
- Error/loading/empty states

### Backend

- Fully connected APIs
- Authentication
- Database persistence
- Validation
- Error handling
- Scheduling logic
- Workload calculations
- Timer persistence
- Analytics
- Sync

### Quality

- Unit tests
- Integration tests
- End-to-end validation
- No critical crashes
- No fake/mock production flows
- Release APK

### Documentation

Provide:

```text
README.md
ARCHITECTURE.md
API_DOCUMENTATION.md
DATABASE_SCHEMA.md
TESTING.md
DEPLOYMENT.md
```

---

# 46. DEFINITION OF DONE

The project is **NOT DONE** when:

- Screens look good.
- APK builds.
- Login works.

The project is DONE only when:

```text
USER
 ↓
LOGIN
 ↓
PROFILE
 ↓
TASK / EXAM / ROUTINE
 ↓
DATABASE
 ↓
SCHEDULE ENGINE
 ↓
TODAY DASHBOARD
 ↓
FOCUS TIMER
 ↓
COMPLETION
 ↓
ANALYTICS
 ↓
NOTIFICATIONS
 ↓
RESCHEDULE
 ↓
OFFLINE STORAGE
 ↓
SYNC
```

works reliably.

---

# 47. FINAL INSTRUCTION

Treat this as a **production rebuild**, not a cosmetic redesign.

First inspect the current repository and identify:

- existing architecture
- database schema
- API endpoints
- authentication flow
- broken features
- duplicate logic
- incomplete screens
- hard-coded values
- mock data
- current navigation
- current theme implementation

Then create a migration/rebuild plan.

After that implement the system in phases:

1. Architecture cleanup
2. Design system
3. Authentication
4. Core data models
5. Tasks
6. Schedule
7. Routines
8. Exams
9. Timer
10. Dashboard
11. Notifications
12. Offline sync
13. Analytics
14. Profile/settings
15. Animations
16. Testing
17. Release build

After each phase, verify functionality before proceeding.

**Do not optimize for finishing quickly. Optimize for a reliable, polished, genuinely usable product.**

The final Equilibrium application should feel like something a real Indian college student could use every day for assignments, labs, exams, routines, focus sessions and placement preparation.
