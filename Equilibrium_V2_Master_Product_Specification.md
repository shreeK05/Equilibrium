# Equilibrium V2 — Master Product, Architecture & Implementation Specification

## Document Purpose

This document is the **master specification for rebuilding Equilibrium from the ground up** as a polished, production-quality, Indian-student-oriented autonomous academic workload management product.

The current repository is treated as a **reference/prototype and source of proven concepts**, not as an untouchable implementation. Existing functionality may be reused when it is correct, but the final V2 system must be audited and rebuilt wherever necessary.

The current README establishes the product vision around autonomous scheduling, Sleep Shield, cognitive-aware placement, explainability, disruption resilience, syllabus/calendar imports and burnout analytics. It also documents a Flutter frontend, Node.js/TypeScript/Express backend, Prisma, Render deployment and a 56-test backend suite. [Source: current project README]

> **Core principle:** Backend decides. Flutter visualizes, explains and interacts.

> **Quality principle:** A feature is not considered complete because it compiles or has a button. It is complete only when the full user flow works from UI → API → database → business logic → response → UI and is covered by meaningful tests.

---

# 1. Product Vision

## 1.1 What Equilibrium Is

Equilibrium is an **autonomous workload-balancing system for students**.

It is not:

- a generic Todo application
- a Google Calendar clone
- a reminder-only application
- a static timetable generator
- a Pomodoro timer with tasks attached
- a dashboard filled with artificial AI scores

It should behave like a **personal workload operating system**.

The student gives Equilibrium:

- academic tasks
- deadlines
- exams
- estimated effort
- cognitive load
- fixed classes/lectures/labs
- personal commitments
- routines
- sleep requirements
- availability
- study preferences
- actual completion history

Equilibrium then determines a safe, explainable schedule.

---

# 2. Primary Target User

## Indian Engineering / University Student

The product must be designed around realistic Indian student workflows.

Examples:

### Academic

- lectures
- practicals
- labs
- tutorials
- assignments
- journals
- practical files
- viva preparation
- internal assessments
- mid-semester exams
- end-semester exams
- backlog preparation
- project work
- group projects
- SIH/project competitions
- Coursera
- NPTEL
- certification preparation
- theory revision
- previous-year-question practice

### Personal

- sleep
- gym
- meals
- commute
- family commitments
- clubs
- events
- personal study
- hobbies
- custom routines

Nothing such as gym, dinner or breakfast may be hardcoded.

---

# 3. Product Goals

1. Reduce academic overload.
2. Protect sleep.
3. Make deadlines manageable.
4. Turn large workloads into executable sessions.
5. Respect classes and personal commitments.
6. Help students understand what to do next.
7. Record actual work performed.
8. Recalculate workload when reality differs from the plan.
9. Learn useful timing patterns from real usage.
10. Make exam preparation measurable.
11. Provide trustworthy explanations for scheduling decisions.
12. Work reliably on mobile and web.
13. Provide excellent light and dark experiences.
14. Remain usable for students with 10 tasks as well as 100+ blocks.

---

# 4. Non-Negotiable Product Principles

## 4.1 Backend Is the Source of Truth

The backend owns:

- prioritization
- scheduling
- capacity calculations
- deadline feasibility
- Sleep Shield constraints
- task chunking
- rescheduling
- deferral
- debt
- decision logs

Flutter must not reproduce scheduling mathematics.

Flutter may perform presentation calculations such as:

- timestamp → pixel position
- display grouping
- progress rendering
- local countdown display

---

## 4.2 No Fake Intelligence

Never introduce:

- fake AI scores
- fake recommendations
- random productivity percentages
- fake explanations
- hardcoded sample schedules
- artificial task completion
- fake historical learning
- fake "confidence" values

If there is insufficient data, show:

> Not enough history yet.

rather than inventing intelligence.

---

## 4.3 Every Feature Must Be End-to-End

For every feature:

```text
UI
 ↓
Provider / State
 ↓
Repository
 ↓
API
 ↓
Validation
 ↓
Service
 ↓
Database
 ↓
Response
 ↓
State update
 ↓
UI
```

A UI button without a working backend flow is incomplete.

---

# 5. Proposed High-Level Architecture

```text
                         EQUILIBRIUM V2
                              |
              +---------------+---------------+
              |                               |
         Flutter Client                  Backend API
              |                               |
      +-------+--------+             +--------+---------+
      |       |        |             |        |         |
   Screens  State   Local Cache    Auth   Scheduler   Analytics
      |       |        |             |        |         |
      +-------+--------+             +--------+---------+
              |                               |
           Repositories                    Services
              |                               |
              +---------------+---------------+
                              |
                           Prisma
                              |
                        PostgreSQL
                              |
                       Production DB
```

---

# 6. Frontend Architecture

## Flutter

Use a maintainable feature-based structure.

```text
equilibrium_app/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme/
│   ├── core/
│   │   ├── api/
│   │   ├── errors/
│   │   ├── storage/
│   │   ├── constants/
│   │   └── utils/
│   ├── models/
│   ├── repositories/
│   ├── providers/
│   ├── features/
│   │   ├── auth/
│   │   ├── onboarding/
│   │   ├── dashboard/
│   │   ├── schedule/
│   │   ├── tasks/
│   │   ├── commitments/
│   │   ├── timer/
│   │   ├── exams/
│   │   ├── analytics/
│   │   ├── imports/
│   │   ├── notifications/
│   │   └── profile/
│   └── widgets/
├── test/
└── integration_test/
```

Do not create multiple competing state-management systems.

---

# 7. Backend Architecture

Recommended:

- Node.js
- TypeScript
- Express
- Prisma
- PostgreSQL in production
- SQLite only for local development if desired
- Zod validation
- JWT authentication
- bcrypt/secure password hashing
- rate limiting
- helmet
- CORS
- structured logging
- correlation IDs
- sanitized errors
- Jest
- integration and end-to-end testing

Suggested structure:

```text
server/
├── src/
│   ├── app.ts
│   ├── server.ts
│   ├── config/
│   ├── middleware/
│   ├── routes/
│   ├── controllers/
│   ├── services/
│   ├── repositories/
│   ├── scheduler/
│   ├── analytics/
│   ├── imports/
│   ├── notifications/
│   ├── validation/
│   └── utils/
├── prisma/
│   ├── schema.prisma
│   └── migrations/
└── tests/
```

---

# 8. Core Data Model

The final database should support at minimum:

## User

- id
- name
- email
- passwordHash
- profile information
- timezone
- academic information
- theme preference
- notification preferences
- createdAt
- updatedAt

## Academic Profile

- college/university
- degree
- branch/program
- semester/year
- division/class
- optional roll metadata
- academic goals

Do not require sensitive information unnecessarily.

---

# 9. Task Model

A task should support:

- id
- title
- description
- subject
- category
- priority
- cognitiveLoad
- estimatedMinutes
- remainingMinutes
- completedMinutes
- deadline
- deadlineType
- status
- recurrence if applicable
- createdAt
- updatedAt

Statuses:

```text
TODO
IN_PROGRESS
PARTIALLY_COMPLETED
COMPLETED
DEFERRED
OVERDUE
CANCELLED
```

---

# 10. Deadline Customization

Students must be able to:

- select date
- select exact time
- edit deadline
- choose hard/flexible deadline
- optionally define preferred completion target
- see deadline proximity
- see overdue state

Example:

```text
Physics Assignment

Deadline
10 September 2026
11:59 PM

Deadline Type
Hard

Estimated Work
90 minutes

Cognitive Load
High
```

Changing the deadline must persist to the backend.

If the schedule is affected, the backend must recalculate it.

---

# 11. Task Completion

Completion is a first-class workflow.

A student can:

- start task
- pause task
- resume task
- record partial completion
- mark complete
- edit actual time if necessary
- view remaining work

Example:

```text
Physics Assignment

Scheduled       90 min
Completed       55 min
Remaining       35 min

[ Continue ]
[ Mark Complete ]
```

If 55 minutes are completed, the backend must record 55 minutes rather than treating the task as fully completed.

---

# 12. Focus Timer

## Core Requirement

The timer must record **actual work time**.

Example:

```text
DBMS Unit 3
Theory Revision

47:32

[ Pause ]
```

Timer capabilities:

- start
- pause
- resume
- stop
- complete session
- discard session with confirmation
- background-safe handling
- recovery after app restart where practical
- actual duration recording
- session history

---

# 13. Timer Session Data

Create a real entity:

```text
FocusSession

id
userId
taskId
startedAt
endedAt
elapsedSeconds
status
notes
createdAt
```

Potential statuses:

```text
RUNNING
PAUSED
COMPLETED
DISCARDED
```

---

# 14. Estimated vs Actual Learning

Every completed focus session can contribute to historical estimation.

Example:

```text
Estimated: 60 min
Actual: 48 min
Difference: -12 min
```

Over time:

```text
Theory Revision
Estimated: 60 min
Historical average: 51 min
Samples: 8
```

Only show learned estimates when sufficient data exists.

---

# 15. Exam Preparation Mode

This is a major student-oriented differentiator.

Student creates:

```text
Database Management Systems

Exam:
18 September

Units:
Unit 1
Unit 2
Unit 3
Unit 4
Unit 5
```

Each unit can contain:

- learning
- revision
- practice
- PYQs
- mock test
- weak-topic revision

Example:

```text
Unit 3

Revision      60m
PYQs          45m
Mock Test     60m
```

The scheduler distributes these sessions according to:

- exam date
- available capacity
- existing classes
- Sleep Shield
- cognitive load
- existing workload
- priority

---

# 16. Commitment System

Do not hardcode "gym", "dinner", "breakfast", etc.

Use a generic commitment model.

```text
Commitment

title
type
startTime
endTime
daysOfWeek
flexibility
priority
reminder
active
```

Types may include:

```text
FIXED
ROUTINE
PERSONAL
ACADEMIC
```

Examples:

- Gym
- Dinner
- College lecture
- Commute
- Club meeting
- Family event
- Custom study block

---

# 17. Custom Routine Builder

Student can create:

```text
Gym

Days:
Mon Tue Thu Sat

Time:
7:00 PM – 8:00 PM

Reminder:
30 minutes before

Flexibility:
Fixed
```

Another student can choose completely different timings.

The scheduler treats these as constraints according to their flexibility.

---

# 18. Sleep Shield

Sleep remains a hard safety constraint.

The system must guarantee:

```text
No TASK block overlaps protected sleep time.
```

Sleep settings:

- bedtime
- wake time
- minimum duration
- recurring schedule
- optional weekend variation

Overnight sleep must be handled correctly.

Example:

```text
23:30 → 07:00
```

The timeline must visually represent the overnight protected region.

---

# 19. Signature Schedule

The schedule must feel like an intelligent workload engine, not a calendar clone.

Include:

- 30-minute grid
- chronological time axis
- current time
- sleep shield
- fixed commitments
- tasks
- breaks
- free capacity
- deferred work
- partial work
- completed blocks
- schedule version
- change summary

Use spatial positioning where appropriate.

---

# 20. Schedule Block Types

```text
TASK
FIXED
SLEEP
BREAK
FREE
```

Every displayed block must originate from actual backend state.

---

# 21. Schedule Versioning

Each generated schedule should have a version.

Support:

- current version
- previous version
- previousVersionId
- createdAt
- generation reason
- decision logs

Do not fake schedule changes with random animations.

---

# 22. Autonomous Rescheduling

When reality changes:

```text
Task originally:
60 min

Actual:
85 min
```

Equilibrium should be able to:

1. record actual work
2. calculate remaining workload
3. preserve completed history
4. regenerate future schedule
5. respect sleep
6. respect fixed commitments
7. update deferred work
8. explain what changed

---

# 23. Explainability

Every important scheduling decision should be explainable.

Example:

```text
Why was this scheduled?

Physics Assignment

Scheduled before deadline because:
- deadline was approaching
- available capacity existed
- cognitive load matched available energy window
- higher priority work was already protected
```

The explanation must come from backend decision data.

No LLM hallucination is required.

---

# 24. Dashboard

The dashboard must become the student's operational home.

## Today

```text
Good evening

TODAY

Planned        4h 20m
Completed      2h 45m
Remaining      1h 35m

5 completed
2 remaining
1 partial
```

## Upcoming

```text
NEXT

7:30 PM
DBMS Revision
60m
HIGH

8:30 PM
Dinner
45m
FIXED
```

## Weekly

Show:

- planned time
- completed time
- remaining time
- deferred time
- overdue work
- study sessions
- workload distribution

All values must be real.

---

# 25. Completion Analytics

Include:

- tasks completed
- completion rate
- actual vs estimated time
- study time
- streak only if meaningful
- overdue tasks
- deferred work
- exam preparation coverage
- subject distribution

Avoid manipulative gamification.

---

# 26. Workload & Burnout Analytics

Use real workload signals.

Possible metrics:

- planned workload
- available capacity
- utilization
- remaining workload
- deferred debt
- overdue workload
- sleep protection
- sustained overload

Avoid claiming medical burnout detection.

Use wording such as:

> Workload is unusually high relative to your available capacity.

rather than:

> You are clinically burned out.

---

# 27. Notifications and Reminders

Implement real notification preferences.

Users can configure:

- task reminder
- upcoming deadline
- focus-session reminder
- schedule change
- overdue task
- exam reminder
- routine reminder

Allow:

- enable/disable
- notification timing
- quiet hours
- per-category controls

---

# 28. Profile

Create a polished student profile.

Sections:

### Personal

- name
- email
- profile image/avatar

### Academic

- college
- course
- branch
- year
- semester

### Scheduling

- sleep
- preferred study periods
- peak-energy windows
- default session length

### Preferences

- theme
- notifications
- language readiness
- week start preference

---

# 29. Dark / Light Mode

Provide:

```text
Appearance

○ System
○ Light
○ Dark
```

Requirements:

- every screen supports both modes
- no unreadable contrast
- no hardcoded white/black UI assumptions
- charts adapt correctly
- icons remain visible
- timeline remains legible
- persistence across restarts

Use one centralized design system.

---

# 30. Design System

Maintain centralized:

- colors
- typography
- spacing
- radius
- elevation
- motion
- semantic states

States must not rely on color alone.

Examples:

```text
DEFERRED
⚠

COMPLETED
✓

FIXED
🔒

SLEEP
Moon + Protected
```

---

# 31. Navigation

Recommended primary navigation:

```text
Home
Schedule
Tasks
Exams
Profile
```

Secondary access:

- Analytics
- Imports
- Settings
- Notifications
- Help

Do not overload the bottom navigation.

---

# 32. Onboarding

Onboarding should collect only what is needed.

Suggested flow:

```text
Welcome
 ↓
Student Profile
 ↓
Academic Details
 ↓
Sleep Shield
 ↓
Study Preferences
 ↓
Recurring Commitments
 ↓
First Task
 ↓
Generate First Schedule
```

The student should be able to skip optional information.

---

# 33. Empty States

Use meaningful states.

### No Schedule

> Your workload is ready to be balanced.

### No Tasks

> Nothing needs scheduling yet.

### Overcapacity

> Your workload exceeds today's available capacity.

### Partial

> Some work could not fit safely today.

### Deferred

> Moved forward to protect your constraints.

Never call mathematically infeasible workload a generic "scheduler failure".

---

# 34. Error Handling

Never expose:

- SQL errors
- Prisma errors
- stack traces
- raw HTTP responses
- JWT internals

Map errors to user-friendly messages.

Examples:

```text
Network unavailable.
Please check your connection.

Session expired.
Please sign in again.

We couldn't save that task.
Please try again.
```

---

# 35. Offline Support

The application should remain useful during temporary connectivity loss.

Offline-capable operations where practical:

- viewing cached schedule
- viewing tasks
- viewing profile
- viewing previous timer sessions
- starting timer locally
- recording timer session locally

When connection returns:

```text
Local changes
 ↓
Sync queue
 ↓
Conflict resolution
 ↓
Backend confirmation
 ↓
UI update
```

Do not pretend an operation was synced when it was only saved locally.

---

# 36. Syllabus Import

Support PDF syllabus parsing where implemented.

Workflow:

```text
Upload PDF
 ↓
Parse
 ↓
Extract subjects / units / topics
 ↓
Preview
 ↓
Student confirms
 ↓
Save
```

Never silently create dozens of tasks from uncertain OCR/parsing.

Always provide a confirmation step.

---

# 37. Calendar Import

Support `.ics` import.

Workflow:

```text
Import calendar
 ↓
Parse events
 ↓
Preview conflicts
 ↓
Select events
 ↓
Create commitments
```

Do not overwrite existing commitments without confirmation.

---

# 38. Conflict Detection

Detect:

- overlapping commitments
- task vs sleep conflicts
- task vs fixed class
- impossible deadlines
- insufficient capacity
- duplicate imported events

Provide actionable messages.

---

# 39. Search and Filtering

Tasks should support:

- search
- subject filter
- status filter
- deadline filter
- priority filter
- cognitive-load filter

Schedule can filter by:

- task
- fixed
- sleep
- completed
- deferred

---

# 40. Task Organization

Support:

- subject
- tags
- category
- priority
- cognitive load

Example categories:

```text
Assignment
Revision
Lab
Project
Exam
Practice
Viva
Administrative
Personal
```

---

# 41. Subject Management

Student can create subjects.

Example:

```text
Database Management Systems
Operating Systems
Deep Learning
MLOps
Mathematics
```

Each subject can show:

- active tasks
- completed tasks
- upcoming deadlines
- exam status
- time spent

---

# 42. Academic Semester Structure

Support:

- semester
- subjects
- academic year
- exam dates
- holidays if configured
- recurring class schedule

This makes Equilibrium substantially more useful for Indian university students.

---

# 43. Intelligent Task Breakdown

Large tasks should support subtasks/chunks.

Example:

```text
Complete DBMS Assignment

Part 1
Research          30m

Part 2
Write             60m

Part 3
Review            30m
```

The scheduler can schedule chunks while preserving parent-task identity.

---

# 44. Actual vs Planned Learning Loop

The product should eventually learn from real sessions.

```text
Estimated
    ↓
Scheduled
    ↓
Timer
    ↓
Actual
    ↓
Difference
    ↓
Historical data
    ↓
Better future estimate
```

This is a legitimate data-driven intelligence layer.

Do not label it AI until there is sufficient training data and a validated model.

---

# 45. Deep Learning Layer

If a Deep Learning component is required for the academic project, keep it clearly separated from deterministic scheduling.

Possible model:

### Duration Prediction

Inputs:

- task category
- subject
- cognitive load
- historical actual duration
- task size
- time of day
- student-specific history

Output:

```text
Predicted duration
Confidence
```

The scheduler may consume the prediction as an input, while all hard constraints remain deterministic.

The DL model must never be allowed to violate:

- sleep
- fixed commitments
- capacity
- hard deadlines

---

# 46. Security

Implement:

- password hashing
- JWT authentication
- refresh/session strategy where appropriate
- ownership checks
- IDOR protection
- rate limiting
- secure headers
- CORS restrictions
- input validation
- payload size limits
- sanitized error responses
- secrets via environment variables
- HTTPS in production

Never store secrets in source control.

---

# 47. API Design

Use consistent versioning:

```text
/api/v1
```

Core endpoint families:

```text
/auth
/users
/profile
/tasks
/subjects
/commitments
/routines
/schedules
/schedules/:id/decisions
/reschedule
/focus-sessions
/exams
/exam-topics
/imports
/analytics
/notifications
```

Every endpoint requires:

- validation
- authorization
- predictable error contract
- tests

---

# 48. API Contract Rule

Flutter must not infer undocumented fields.

If the backend returns:

```json
{
  "remainingMinutes": 35
}
```

the frontend uses that value.

Do not recreate it using:

```text
estimated - completed
```

unless that is explicitly part of the frontend presentation model and is guaranteed by the API contract.

---

# 49. Database Integrity

Use:

- foreign keys
- unique constraints
- indexes
- timestamps
- transaction boundaries
- appropriate cascading behavior
- migration files

Production should use PostgreSQL.

SQLite can remain for local development if useful.

---

# 50. Scheduler Requirements

The scheduler must account for:

### Hard constraints

- sleep
- fixed commitments
- unavailable periods
- user-defined hard blocks

### Soft optimization

- deadline urgency
- priority
- cognitive load
- energy window
- deferral debt
- task fragmentation
- fairness across workload

The backend must produce a schedule plus provenance.

---

# 51. Scheduler Output

Return enough information for the frontend to render the decision without reconstructing it.

Example:

```text
ScheduleVersion
 ├── id
 ├── previousVersionId
 ├── generatedAt
 ├── horizon
 ├── blocks[]
 └── decisionLogs[]
```

---

# 52. Decision Log

Every important decision can contain:

```text
decisionType
reasonCode
taskId
scheduleVersionId
priorityScore
metadata
```

The frontend formats this information.

---

# 53. Rescheduling UX

When a new version arrives:

```text
Schedule Updated

3 tasks moved
1 task deferred
45 minutes rescheduled
```

Allow the user to inspect changes.

Do not fake movement.

Use actual version lineage.

---

# 54. Timer + Rescheduling Integration

This is critical.

Example:

```text
Task:
90 minutes

Scheduled:
7:00–8:30

Actual:
7:00–8:55

Remaining:
0
```

or:

```text
Scheduled:
90 minutes

Actual:
55 minutes

Remaining:
35 minutes
```

When the session changes workload, the backend can reschedule the remaining work.

---

# 55. Dashboard + Timer Integration

Dashboard should update after completed sessions.

Example:

```text
Today

Planned       4h
Completed     2h 20m
Remaining     1h 40m

Focus time
2h 05m
```

No stale fake values.

---

# 56. Reminder Architecture

Use a notification service abstraction.

```text
NotificationScheduler
        |
        +-- task reminders
        +-- deadlines
        +-- routines
        +-- exams
        +-- schedule changes
```

Avoid scattering notification logic throughout widgets.

---

# 57. Accessibility

Support:

- semantic labels
- screen readers
- keyboard navigation on web
- large text
- sufficient contrast
- non-color-only states
- logical focus order
- accessible timer controls
- accessible timeline blocks

---

# 58. Responsive UI

## Mobile

Prioritize:

- one-handed actions
- bottom sheets
- compact schedule
- quick task creation

## Tablet

Use:

- two-column layouts
- larger schedule view
- dashboard + upcoming schedule

## Desktop/Web

Use:

```text
Sidebar
    |
Main content
    |
Optional detail panel
```

Do not simply stretch the mobile layout.

---

# 59. Performance

Target:

- smooth scrolling
- lazy rendering
- minimal rebuilds
- paginated history
- efficient schedule rendering
- cached profile/settings
- no unnecessary network calls

Target scenarios:

- 100+ tasks
- 100+ schedule blocks
- 7-day schedule
- hundreds of focus sessions
- frequent schedule refreshes

---

# 60. Observability

Production backend should provide:

- structured logs
- request IDs/correlation IDs
- latency measurements
- error counts
- scheduler execution timing
- database error tracking

Never log:

- passwords
- JWT secrets
- sensitive personal data unnecessarily

---

# 61. Deployment

## Backend

Recommended:

- Render
- PostgreSQL
- environment variables
- HTTPS
- health check
- production migration strategy

Environment example:

```env
NODE_ENV=production
PORT=10000
DATABASE_URL=...
JWT_SECRET=...
ALLOWED_ORIGINS=...
```

Never commit `.env`.

Provide `.env.example`.

---

# 62. Flutter Production Configuration

Use:

```text
API_BASE_URL
```

injected through build-time configuration.

Example:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR_BACKEND/api/v1
```

Do not hardcode localhost into release builds.

---

# 63. Application Branding

Display name:

```text
Equilibrium
```

Do not expose:

```text
equilibrium_app
```

Use the approved Equilibrium launcher icon.

Splash screen must use the same brand language.

---

# 64. Testing Strategy

Testing must exist at four levels.

## Unit

Test:

- models
- validators
- scheduler functions
- scoring
- capacity
- timer calculations
- date handling

## Integration

Test:

```text
API → Service → Repository → Database
```

## Flutter Widget

Test:

- dashboard
- task cards
- timeline
- timer
- profile
- themes
- empty states
- error states

## End-to-End

Test real flows:

```text
Register
 ↓
Onboarding
 ↓
Create commitment
 ↓
Create task
 ↓
Generate schedule
 ↓
Start timer
 ↓
Complete partially
 ↓
Reschedule
 ↓
View explanation
 ↓
Dashboard update
 ↓
Logout
```

---

# 65. Mandatory Scheduler Invariants

At minimum test:

## Sleep invariant

```text
TASK blocks ∩ SLEEP = ∅
```

## Fixed invariant

```text
TASK blocks ∩ FIXED = ∅
```

## Completion invariant

```text
completedMinutes <= original workload
```

unless explicit correction workflow exists.

## Version invariant

Previous schedule remains immutable.

## Ownership invariant

A user cannot access another user's resources.

---

# 66. Test Matrix

| Area | Required |
|---|---|
| Registration | Yes |
| Login | Yes |
| Logout | Yes |
| Profile | Yes |
| Theme persistence | Yes |
| Task creation | Yes |
| Task editing | Yes |
| Deadline editing | Yes |
| Task completion | Yes |
| Partial completion | Yes |
| Commitments | Yes |
| Recurring routines | Yes |
| Sleep Shield | Yes |
| Schedule generation | Yes |
| Overnight sleep | Yes |
| Split tasks | Yes |
| Fixed commitments | Yes |
| Timer | Yes |
| Pause/resume | Yes |
| Actual duration | Yes |
| Dashboard | Yes |
| Exam mode | Yes |
| Explainability | Yes |
| Rescheduling | Yes |
| Notifications | Yes |
| Import | Yes |
| Offline cache | Yes |
| Security | Yes |
| API errors | Yes |
| Responsive UI | Yes |
| Accessibility | Yes |

---

# 67. Quality Gates

A phase cannot be declared complete if:

- code merely compiles
- UI button is not connected
- backend endpoint is missing
- data is mocked
- feature works only with hardcoded IDs
- tests were deleted to make failures disappear
- failures are ignored
- production API is replaced by localhost
- scheduler math was duplicated in Flutter

---

# 68. Demo Dataset

Production must contain zero demo data.

For development/testing, fixtures may exist only in:

```text
test/
integration_test/
```

They must never be loaded automatically for real users.

---

# 69. UX Principles

The interface should feel:

- calm
- intelligent
- premium
- academic
- trustworthy
- focused
- non-gamified

Avoid:

- excessive gradients
- excessive animations
- neon AI styling
- meaningless badges
- cluttered dashboards
- giant cards for every field
- childish gamification

---

# 70. High-End Product Details

Consider:

- subtle haptic feedback
- polished transitions
- skeleton loading
- optimistic UI only where safe
- pull-to-refresh
- swipe actions where appropriate
- undo for safe actions
- confirmation only for destructive actions
- contextual empty states
- smart quick-add
- recent task suggestions based on actual data
- keyboard shortcuts on web
- deep links
- accessible date/time controls

---

# 71. Quick Add

Provide a fast task entry flow.

Example:

```text
+ Add Task

Physics Assignment
Due Friday 11:59 PM
90m
High
```

Advanced fields can be expanded.

The student should not need a 10-field form for every task.

---

# 72. Today Experience

The first screen should answer:

1. What do I need to do today?
2. What am I doing now?
3. What is next?
4. How much remains?
5. Am I overloaded?
6. What changed?

This is more useful than showing generic statistics first.

---

# 73. Exam Countdown

For active exams:

```text
DBMS EXAM

8 days remaining

Coverage
78%

Revision
82%

Practice
61%

Remaining
4h 35m
```

All values must come from real data.

---

# 74. Student-Friendly Language

Prefer:

> Some work could not fit safely today.

Instead of:

> Optimization infeasible.

Prefer:

> Your schedule changed because the assignment took longer than expected.

Instead of:

> Rescheduler recomputed the knapsack.

Technical information can remain accessible in explanations/debug documentation.

---

# 75. Privacy

Collect only necessary information.

Provide:

- account deletion
- data export where practical
- privacy explanation
- notification controls
- permission controls

Never sell or expose personal academic data.

---

# 76. Reliability

Handle:

- app killed during timer
- network lost during save
- token expiry
- duplicate requests
- server restart
- stale schedule
- database migration errors
- malformed imports
- timezone changes
- daylight-saving edge cases where relevant
- midnight crossing
- leap dates
- exam date already passed

---

# 77. Timezone

Store timestamps consistently.

User profile should have timezone.

Display local time.

Never silently interpret a server timestamp as device-local without explicit conversion.

---

# 78. Date/Time Edge Cases

Test:

- overnight sleep
- midnight task
- deadline at 11:59 PM
- deadline exactly at current time
- task spanning midnight
- daylight-saving transitions where applicable
- semester rollover
- past deadline
- future semester

---

# 79. Data Synchronization

Use clear synchronization states:

```text
Synced
Syncing
Offline
Sync failed
Conflict
```

Do not hide synchronization failure.

---

# 80. Conflict Resolution

If the same task is modified on two devices:

- detect version mismatch
- preserve latest valid backend state
- avoid silent data loss
- explain conflict when user action is needed

---

# 81. Account and Session Security

Implement:

- token expiry
- automatic logout on unauthorized responses
- secure token storage
- password requirements
- login rate limiting
- account recovery strategy if required

---

# 82. Documentation Requirements

Maintain:

```text
docs/
├── ARCHITECTURE.md
├── API.md
├── DATABASE.md
├── SCHEDULER.md
├── AUTONOMY.md
├── RESCHEDULING.md
├── FIXED_COMMITMENTS.md
├── SCHEDULE_UI.md
├── EXPLAINABILITY.md
├── TIMER.md
├── DASHBOARD.md
├── EXAMS.md
├── IMPORTS.md
├── NOTIFICATIONS.md
├── OFFLINE_SYNC.md
├── SECURITY.md
├── TESTING.md
└── RELEASE_READINESS.md
```

Documentation must match the actual implementation.

---

# 83. Production Readiness Checklist

## Backend

- [ ] Production database
- [ ] Migrations
- [ ] Environment variables
- [ ] HTTPS
- [ ] CORS
- [ ] Rate limiting
- [ ] Security headers
- [ ] Error sanitization
- [ ] Logging
- [ ] Health endpoint
- [ ] Backups

## Flutter

- [ ] Production API URL
- [ ] App name = Equilibrium
- [ ] Launcher icon
- [ ] Splash branding
- [ ] Light mode
- [ ] Dark mode
- [ ] Offline behavior
- [ ] Accessibility
- [ ] Responsive layouts
- [ ] Release build

---

# 84. Definition of Done

Equilibrium V2 is complete only when:

### Functional

- every advertised feature works
- real database persistence works
- real API integration works
- user can complete real workflows

### Scheduling

- hard constraints are guaranteed
- rescheduling works
- explainability works
- schedule versions work

### Student Experience

- profile works
- tasks work
- deadlines work
- commitments work
- routines work
- timer works
- dashboard works
- exams work
- reminders work

### Quality

- tests pass
- no production mocks
- no known critical bugs
- release build succeeds
- production backend is reachable
- database is persistent
- security checks pass

---

# 85. Final Product Flow

```text
INSTALL
  ↓
OPEN EQUILIBRIUM
  ↓
REGISTER / LOGIN
  ↓
BUILD STUDENT PROFILE
  ↓
SET ACADEMIC INFORMATION
  ↓
SET SLEEP SHIELD
  ↓
CREATE PERSONAL ROUTINES
  ↓
ADD SUBJECTS
  ↓
ADD TASKS + DEADLINES
  ↓
ADD EXAMS
  ↓
ADD FIXED COMMITMENTS
  ↓
GENERATE SCHEDULE
  ↓
SIGNATURE TIMELINE
  ↓
DO TASK
  ↓
START FOCUS TIMER
  ↓
PAUSE / RESUME
  ↓
COMPLETE OR PARTIALLY COMPLETE
  ↓
RECORD ACTUAL TIME
  ↓
UPDATE WORKLOAD
  ↓
RESCHEDULE IF REQUIRED
  ↓
SHOW CHANGE SUMMARY
  ↓
EXPLAIN WHY
  ↓
UPDATE DASHBOARD
  ↓
LEARN FROM ACTUAL HISTORY
  ↓
IMPROVE FUTURE ESTIMATES
```

---

# 86. Example Complete Student Day

```text
07:00
Wake

08:00
Breakfast

09:00–10:00
College Lecture

10:15–11:15
Operating Systems Assignment
HIGH

11:15–12:00
FREE / Travel

12:00–01:00
College Lab

01:00–02:00
Lunch

02:00–03:00
DBMS Revision

03:00–03:30
Break

03:30–04:30
Deep Learning Project

05:00–06:00
FREE

07:00–08:00
Gym
FIXED ROUTINE

08:30–09:15
Dinner
FIXED ROUTINE

09:15–10:15
Physics Revision

10:15
Wind-down

23:30
SLEEP SHIELD
```

The exact times are always user/backend generated, not hardcoded.

---

# 87. Example Disruption

Original:

```text
7:00–8:00
DBMS Revision
```

Student works for 1h 25m.

Equilibrium records:

```text
Estimated: 60m
Actual: 85m
```

The system then:

```text
Record completion
 ↓
Update task state
 ↓
Recalculate future capacity
 ↓
Preserve completed history
 ↓
Generate new schedule version
 ↓
Respect sleep
 ↓
Respect fixed commitments
 ↓
Update dashboard
 ↓
Show:
"Schedule Updated"
```

---

# 88. Example Partial Completion

```text
Assignment:
120m

Completed:
50m

Remaining:
70m
```

The remaining 70 minutes must remain schedulable.

The original completed 50 minutes must not be scheduled again.

---

# 89. Example Overcapacity

If:

```text
Available:
3h

Required:
6h
```

Equilibrium must not squeeze 6 hours into 3 hours.

It should explain:

```text
Your workload exceeds today's available capacity.

3h can be safely scheduled.
3h remains for later.
```

---

# 90. What Makes V2 Unique

The strongest differentiator is not one isolated feature.

It is the loop:

```text
PLAN
 ↓
SCHEDULE
 ↓
EXECUTE
 ↓
MEASURE ACTUAL TIME
 ↓
UNDERSTAND
 ↓
RESCHEDULE
 ↓
LEARN
 ↓
PLAN BETTER
```

combined with:

```text
SLEEP PROTECTION
+
ACADEMIC CONSTRAINTS
+
PERSONAL ROUTINES
+
EXAM PREPARATION
+
REAL WORK HISTORY
```

This is what separates Equilibrium from a normal planner.

---

# 91. Recommended Implementation Order

## Stage 0 — Audit

- inspect current repository
- identify duplicate/legacy backend code
- inspect existing scheduler
- inspect database
- inspect API
- inspect Flutter architecture
- run all tests
- run APK against production
- document gaps

## Stage 1 — Foundation

- clean architecture
- database schema
- authentication
- profile
- theme
- API contract

## Stage 2 — Academic Core

- subjects
- tasks
- deadlines
- commitments
- routines
- Sleep Shield

## Stage 3 — Scheduler

- scheduling
- chunking
- fixed constraints
- sleep
- capacity
- priority
- cognitive load
- explainability

## Stage 4 — Signature Experience

- dashboard
- timeline
- task details
- completion
- rescheduling
- change summaries

## Stage 5 — Focus System

- timer
- focus sessions
- actual duration
- partial completion
- history

## Stage 6 — Exam System

- exams
- syllabus
- topics
- revision
- practice
- PYQs
- coverage

## Stage 7 — Intelligence

- duration learning
- workload analytics
- optional DL model
- prediction confidence

## Stage 8 — Imports & Notifications

- PDF syllabus
- ICS
- reminders
- notifications

## Stage 9 — Offline & Reliability

- cache
- sync
- conflict resolution
- timer recovery

## Stage 10 — Production

- security
- performance
- accessibility
- deployment
- monitoring
- final testing

---

# 92. Agent Instructions

Any coding agent working on this project must obey:

1. Inspect before modifying.
2. Never delete functionality just to make tests pass.
3. Never invent API fields.
4. Never create production mocks.
5. Never hardcode user schedules.
6. Never duplicate scheduler mathematics in Flutter.
7. Never claim end-to-end completion from compilation alone.
8. Test both success and failure paths.
9. Preserve data ownership boundaries.
10. Verify migrations.
11. Verify production API connectivity.
12. Verify real database persistence.
13. Update documentation after architectural changes.
14. Report exact files changed.
15. Report exact tests run.
16. Report exact failures.
17. Do not hide limitations.
18. Do not automatically move to another phase without approval.
19. Do not introduce unnecessary dependencies.
20. Prefer simple, maintainable architecture over clever code.

---

# 93. Final Acceptance Standard

The final question must not be:

> "Does the app look good?"

It must be:

> **"Can a real Indian engineering student install Equilibrium, create their profile, configure sleep and routines, add subjects/tasks/exams/deadlines, generate a safe schedule, execute work using the timer, mark partial/completed work, receive reminders, understand scheduling decisions, survive disruptions through rescheduling, see accurate dashboard progress, and trust that every displayed number comes from real persisted data?"**

If the answer is **yes**, and the complete test suite verifies it, Equilibrium V2 is ready.

---

# 94. Final Architecture Statement

## Backend

**Equilibrium decides.**

It owns:

- constraints
- optimization
- scheduling
- rescheduling
- workload state
- provenance
- persistence

## Flutter

**Equilibrium visualizes, explains and interacts.**

It owns:

- user interaction
- presentation
- navigation
- timer UI
- accessibility
- responsive rendering
- local presentation state

## Student

**The student remains in control.**

Equilibrium should optimize the student's workload — never pretend to own the student's life.

---

# 95. Final Success Definition

Equilibrium V2 should feel like:

> **A calm, intelligent academic operating system built specifically for real student life.**

Not a Todo app.

Not a calendar.

Not a fake AI dashboard.

A system that understands:

**what the student needs to do, when they can realistically do it, what they actually completed, what changed, and how to safely adapt.**

