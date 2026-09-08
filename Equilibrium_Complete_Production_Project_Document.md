EQUILIBRIUM
Autonomous Student Workload Balancer
COMPLETE PRODUCTION-LEVEL PROJECT SPECIFICATION
Deep Learning Course Project • Architecture • Algorithms • ML Layer • UX • APIs • Security • Testing • Deployment

| PRODUCT PROMISE<br>The planner that mathematically cannot let a deadline eat your sleep — and shows its work when it says no. |
| --- |

Version 1.0 • September 2026
# Document Control

| Item | Value |
| --- | --- |
| Project | Equilibrium — Autonomous Student Workload Balancer |
| Document | Complete Product + Technical Specification |
| Target | Production-quality academic project / demonstrable MVP |
| Client | Flutter Android/Web application |
| Backend | Node.js + Express + TypeScript |
| Data | Prisma ORM; SQLite local; PostgreSQL recommended for production |
| Scheduling | Deterministic constraint engine + 0/1 Knapsack + energy-aware placement + rescheduling |
| Deep Learning | Advisory duration-estimation and workload-risk models; never overrides hard constraints |
| Quality bar | 0% sleep violations; explainable decisions; real end-to-end data flow |

| IMPLEMENTATION NOTE<br>This document is implementation-ready. It does not claim an implementation already passes every acceptance test. The project should be called production-ready only after the acceptance gates in Section 19 are demonstrated. |
| --- |

# Contents
1. Executive Summary
2. Problem Statement and Motivation
3. Product Vision, USP and Uniqueness
4. Scope and Requirements
5. End-to-End User Flow
6. Functional Modules
7. System Architecture
8. Scheduling Engine — Core Algorithm
9. Explainability and Decision Ledger
10. Disruption and Anti-Fragile Rescheduling
11. Proposed Deep Learning Layer
12. Data Model and Database Design
13. API Contract
14. Flutter UX/UI Specification
15. Offline-First, Notifications and Integrations
16. Security, Privacy and Reliability
17. Testing and Test-Case Matrix
18. Production Deployment and CI/CD
19. Acceptance Criteria and Definition of Done
20. Demo / Professor Presentation Flow
21. KPIs, Risks and Mitigations
22. Future Enhancements
23. Suggested Project Repository
24. Viva / Evaluation Questions and Answers
# 1. Executive Summary
Equilibrium is an academic workload-balancing system designed specifically for students. It is not a conventional to-do list and not merely a calendar. Its central job is to decide which academic work should fit into the student's available capacity, when it should happen, what should move when reality changes, and why a decision was made.
The defining safety invariant is a protected sleep window with a minimum seven-hour sleep floor. Sleep is treated as a mathematical hard constraint rather than a preference. The scheduling engine builds the academic plan around protected rest and fixed commitments instead of filling the day and sacrificing sleep.
The high-end version combines academic priority scoring, a 0/1 Knapsack selection stage, half-hour time slots, energy-aware placement, debt accrual for deferred tasks, disruption-aware rescheduling, decision logs, workload/burnout forecasting, calendar and syllabus imports, read-only team sharing, offline caching and local notifications.
For a Deep Learning course, the recommended enhancement is a non-critical learning layer. The model learns from completed-task history to estimate realistic task duration and predict workload risk. The learned model is advisory: it may improve estimates and warnings, but it can never override the deterministic sleep constraint or silently schedule unsafe work.
# 2. Problem Statement and Motivation
Students commonly manage work across disconnected systems such as notes, calendars, LMS portals, chats and reminders. This creates recurring problems:
Deadline-centric planning can push study sessions into sleep hours.
Static timetables become invalid when a task takes longer than expected.
Generic priority does not capture academic importance, team impact or cognitive load.
Deferred work becomes invisible and its accumulated pressure is hard to understand.
Automation often gives recommendations without enough evidence for the student to trust the result.
## Problem Definition
Given academic tasks, fixed commitments, a protected sleep interval, available capacity, deadlines, academic weights, team impact, cognitive load, energy preferences and historical completion behavior, produce a feasible schedule that maximizes academic value while never violating the protected sleep invariant.
# 3. Product Vision, USP and Uniqueness
## 3.1 Core questions
What should I do next?
When should I do it?
What happens if today's plan goes wrong?
Why did Equilibrium choose this task instead of another one?
## 3.2 Core USP
Sleep Shield: the seven-hour minimum is enforced by the scheduling engine and shown visually.
Explainable autonomy: every scheduled, deferred or moved task has a reason and priority breakdown.
Anti-fragile rescheduling: an overrun becomes a scheduling event, not a manual timetable repair exercise.
Academic priority combines urgency, academic weight, team impact and schedule debt.
Capacity-first planning calculates safe available hours before task selection.
Energy-aware placement prefers peak-focus windows for deep work without overriding hard constraints.
## 3.3 Differentiators
Weekly workload/burnout meter and forecast.
Schedule-debt ledger for deferred work.
Conflict/overload simulator before committing a new task.
Task splitting into bounded focus blocks.
Syllabus PDF candidate extraction with mandatory human confirmation.
Google Calendar fixed-commitment import.
Read-only team share links.
Offline-first schedule cache and local notifications.
Schedule version history: before vs after disruption.
Completion feedback for future estimate calibration.
## 3.4 Design principle
The scheduling core remains deterministic and inspectable. A black-box language model is not placed in the critical path. Intelligence comes from optimization, constrained rescheduling, learning-assisted estimates, risk prediction and transparent explanations.
# 4. Scope and Requirements
## 4.1 Functional requirements

| ID | Module | Requirement |
| --- | --- | --- |
| FR-01 | Authentication | Register, login, secure session, logout and ownership checks. |
| FR-02 | Onboarding | Collect sleep window, fixed commitments, energy windows and notification preferences. |
| FR-03 | Task management | Create, edit, delete, complete, split and inspect tasks. |
| FR-04 | Scheduling | Generate daily/weekly schedules using hard constraints and priority optimization. |
| FR-05 | Sleep Shield | Prevent generated task blocks from overlapping protected sleep. |
| FR-06 | Explainability | Expose score components, constraints, alternatives and reason codes. |
| FR-07 | Rescheduling | Re-optimize after overrun, disruption or user-triggered change. |
| FR-08 | Debt | Increase pressure for deferred work and expose debt history. |
| FR-09 | Burnout | Compare scheduled workload with safe capacity and forecast overload. |
| FR-10 | Imports | Import calendar commitments and syllabus PDF candidates. |
| FR-11 | Team view | Generate revocable, expiring read-only schedule sharing. |
| FR-12 | Offline | Display cached schedules during network loss and synchronize later. |
| FR-13 | Notifications | Upcoming work, overload and rescheduling alerts. |
| FR-14 | Simulation | Preview impact of adding/changing a task before saving. |

## 4.2 Non-functional requirements
Determinism: same inputs plus controlled currentDateTime produce the same scheduling result.
Safety: sleep violation rate must be 0% in release acceptance testing.
Performance: normal schedule regeneration target is under 3 seconds for the normal demo workload.
Security: hashed passwords, protected tokens, externalized secrets and ownership checks.
Reliability: schedule replacement and decision-log writes are transactional.
Accessibility: reduced motion, focus/pressed/disabled states, contrast and keyboard navigation on web.
Observability: request/correlation IDs and structured errors.
Maintainability: scheduler isolated from HTTP/database concerns and covered by automated tests.
# 5. End-to-End User Flow
Launch → branded splash screen.
Onboarding → configure protected sleep window.
Set fixed commitments → classes, commute, appointments or imported calendar blocks.
Set peak-focus windows.
Create/import tasks → title, deadline, estimate, subject, academic weight, team impact and cognitive load.
Run impact simulator → preview overload/conflicts before saving.
Generate schedule → calculate safe capacity, score tasks, select work and place blocks.
Today view → see next action, workload state and Sleep Shield.
Tap task → open explainability sheet and inspect the actual decision.
Task overruns → record actual duration or trigger a simulated disruption.
Reschedule → reduce remaining capacity, preserve sleep, move affected tasks and create a new schedule version.
Review Burnout and Debt → inspect safe capacity, forecast and deferred-work pressure.
Import syllabus → parser returns candidates; user edits/accepts; only confirmed items become tasks.
Team view → generate read-only link and verify from another browser.
Network loss → cached schedule remains available; refresh occurs when connection returns.
Complete task → actual duration feeds the learning/estimate layer.

| SIGNATURE DEMO MOMENT<br>After an overrun, task cards should visibly settle into new positions around the Sleep Shield. The animation demonstrates that the constraint is not merely a label: the engine and UI both respect it. |
| --- |

# 6. Functional Modules

| Module | Purpose |
| --- | --- |
| Onboarding | Sleep constraints, commitments, energy windows, notifications. |
| Today | Current workload, next best action, timeline slice, disruption and reschedule. |
| Schedule | Full-day/week timeline, task blocks, deadlines and workload density. |
| Tasks | Create/edit/complete/split, academic metadata and estimate history. |
| Explain | Priority math, constraint proof, alternatives and decision reason. |
| Reschedule | Disruption state, remaining capacity, affected tasks and new plan. |
| Burnout / Insights | Safe-hours gauge, utilization and overload forecast. |
| Debt Ledger | Deferred tasks, deferral count, debt growth and resolution. |
| Calendar Import | OAuth/import fixed commitments with minimum scopes. |
| Syllabus Import | PDF → candidates → confirmation → tasks. |
| Team View | Read-only share token, expiry and revoke. |
| Settings | Sleep window, buffers, energy and notification preferences. |

# 7. System Architecture
Flutter App
 ├─ Presentation / Design System
 ├─ Riverpod State
 ├─ Repository Layer
 ├─ Dio HTTP Client
 ├─ Hive/Isar Offline Cache
 └─ Local Notifications
              │ HTTPS REST
              ▼
Node.js + Express + TypeScript
 ├─ Auth Middleware
 ├─ Task Service
 ├─ Schedule Service
 ├─ Import Service
 ├─ Team Share Service
 ├─ Insights Service
 └─ Scheduling Engine
      ├─ Constraint Guard
      ├─ Priority Scorer
      ├─ 0/1 Knapsack Solver
      ├─ Slot Generator
      ├─ Energy-Aware Placement
      ├─ Rescheduler
      └─ Decision Logger
              │
              ▼
Prisma ORM
              │
      PostgreSQL (production)
      SQLite (local/dev)
## 7.1 Architectural rules
The scheduling engine is a pure input→output module.
The engine must not perform database, HTTP or UI operations.
Identical controlled inputs must produce identical outputs.
Controllers validate input and delegate to services.
Database migrations are version-controlled.
Every user-owned resource is authorized.
Significant schedule changes create a new schedule version.
## 7.2 Request lifecycle
Flutter sends authenticated request.
Express validates token and body.
Service loads constraints and pending work.
Scheduler builds deterministic candidate.
Validator checks hard constraints.
Transaction writes version, blocks and decision logs.
API returns normalized schedule data.
Flutter updates state and local cache.
# 8. Scheduling Engine — Core Algorithm
## 8.1 Hard constraints
Minimum protected sleep is 7 hours.
No task block may overlap protected sleep.
Fixed commitments consume unavailable capacity.
Blocks must fit allowed windows.
Unscheduled work becomes DEFERRED with a reason.
Constraint-violating solver output is rejected, not silently patched.
## 8.2 Capacity
available_work_minutes = 1440 - protected_sleep_minutes - fixed_commitment_minutes - configured_buffers
The day is discretized into half-hour slots. Long tasks can be represented as bounded blocks while retaining one parent task.
## 8.3 Explainable priority
Priority = α·AcademicWeight + β·Urgency + γ·TeamImpact + δ·Debt + ε·EnergyFit − ζ·FragmentationPenalty
Urgency rises as the deadline approaches; debt rises after deferral; energy fit rewards peak windows. Coefficients are version-controlled so results remain reproducible.
## 8.4 0/1 Knapsack
maximize Σ(vᵢ·xᵢ) subject to Σ(wᵢ·xᵢ) ≤ C, where xᵢ ∈ {0,1}
Here wᵢ is effort, vᵢ is explainable value and C is safe capacity. Tasks that do not fit are deferred rather than deleted.
## 8.5 Placement
Generate half-hour slots outside sleep and fixed commitments.
Reject invalid slots using hard constraints first.
Prefer peak-energy windows for deep work.
Penalize unnecessary fragmentation and context switching.
Prefer adjacent blocks when continuity helps.
Respect deadline feasibility.
Validate the complete result before publishing it.
## 8.6 Worked example

| Task | Effort | Value | Capacity 9h | Result |
| --- | --- | --- | --- | --- |
| Research report | 3h | 8 | 9h | Selected |
| Exam preparation | 6h | 9 | 9h | Selected |
| Low-value formatting | 2h | 4 | 9h | Deferred |

This shows why Equilibrium maximizes academic value inside safe capacity rather than simply filling the calendar.
# 9. Explainability and Decision Ledger
Every meaningful scheduling decision is inspectable. A user can understand what factors mattered and which alternatives were rejected.

| Component | Example |
| --- | --- |
| Academic weight | 0.80 × α |
| Urgency | Deadline in 36 hours → elevated urgency |
| Team impact | Group dependency → positive contribution |
| Debt | Deferred twice → debt contribution increased |
| Energy fit | Deep-work task placed in peak window |
| Capacity | 2.0h free before protected sleep |
| Constraint proof | Block does not intersect Sleep Shield |
| Reason code | DEFERRED_CAPACITY / SCHEDULED_HIGH_VALUE / MOVED_OVERRUN |
| Alternatives | Candidate slots rejected due to fixed commitment |

## Decision log fields
decisionLog {
  id
  taskId
  scheduleVersionId
  action              // SCHEDULED | DEFERRED | MOVED
  reasonCode
  priorityComponentsJson
  alternativesJson
  capacityBefore
  capacityAfter
  algorithmVersion
  generatedAt
}
# 10. Disruption and Anti-Fragile Rescheduling
A real schedule must survive overruns. A task estimated at 60 minutes may consume 100 minutes; Equilibrium treats this as a first-class disruption event.
Detect/record actual duration.
Calculate remaining capacity.
Freeze hard constraints and fixed commitments.
Re-score affected pending tasks using updated urgency/debt.
Re-run selection and placement.
Create a new schedule version.
Write decision logs for every moved/deferred/scheduled item.
Return the delta so the UI can animate changed blocks.
## Reschedule invariants
Sleep remains untouched.
Fixed commitments remain untouched.
Idempotent repeated requests do not create duplicate versions.
Every affected task has an explicit outcome.
Before/after schedule versions remain inspectable.
# 11. Proposed Deep Learning Layer

| COURSE-PROJECT EXTENSION<br>The product concept is strongest when the scheduling core remains deterministic. For the Deep Learning course, add learning modules around the scheduler rather than replacing the safety-critical optimizer. |
| --- |

## 11.1 Model A — Task Duration Estimator
Predict realistic completion time from task metadata and user history: estimate, cognitive load, subject, task type, deadline distance, time-of-day, prior actual duration and recent workload.
Task metadata + history → MLP / tabular neural network → predicted duration + confidence
The prediction is advisory and remains user-editable.
## 11.2 Model B — Workload Risk Predictor
Predict overload probability from scheduled hours, safe capacity, deadline density, cognitive load, recent overruns and unresolved debt.
Features → Dense layers → sigmoid → P(overload) → warning / insight
## 11.3 Training pipeline
Collect consented task/completion outcomes.
Clean impossible durations and missing values.
Encode categorical fields.
Split by time or user to reduce leakage.
Normalize numeric features.
Train a baseline before the MLP.
Train and tune the neural model.
Evaluate MAE/RMSE and classification metrics.
Version the model artifact.
Deploy inference as advisory service.
Monitor drift and prediction error.
## 11.4 Safety boundary

| ML NEVER OVERRIDES SAFETY<br>The neural network can suggest an estimate or risk score. It cannot schedule work inside protected sleep, remove a fixed commitment or silently change a hard constraint. |
| --- |

| Model | Primary metric | Secondary | Product use |
| --- | --- | --- | --- |
| Duration estimator | MAE | RMSE / calibration | Improve effort estimates |
| Overload predictor | F1 / ROC-AUC | Precision / Recall | Early warning |
| Optional next-action model | Top-k hit rate | NDCG | Advisory ranking |

# 12. Data Model and Database Design

| Entity | Important fields | Purpose |
| --- | --- | --- |
| User | id, name, email, passwordHash, timezone, createdAt | Identity |
| UserConstraint | userId, minSleepHours, sleepStart, sleepEnd, bufferPercent, mandatoryHoursJson, peakEnergyWindowsJson | Rules/preferences |
| Task | id, ownerId, title, deadline, estimateMinutes, academicWeight, teamImpactWeight, cognitiveLoad, subject, deferralCount, priorityScore, status | Academic workload |
| TaskEstimate | taskId, estimatedMinutes, actualMinutes, source, createdAt | Estimate history |
| ScheduleVersion | id, userId, triggerType, generatedAt, capacityMinutes, algorithmVersion | Plan history |
| ScheduleBlock | id, versionId, taskId, startTime, endTime, blockType, status | Rendered schedule |
| DecisionLog | id, scheduleBlockId/taskId, reasonCode, priorityComponentsJson, alternativesJson, generatedAt | Explainability |
| DisruptionEvent | id, userId, taskId, plannedMinutes, actualMinutes, detectedAt | Reschedule trigger |
| ImportJob | id, userId, type, status, sourceName, metadataJson, createdAt | Import tracking |
| ImportCandidate | id, importJobId, title, deadline, estimate, confidence, rawText, confirmed | Human-in-the-loop import |
| TeamShare | id, ownerId, shareTokenHash, expiresAt, revokedAt | Read-only sharing |
| NotificationPreference | userId, burnoutAlerts, upcomingTaskAlerts, rescheduleAlerts | Notifications |

## 12.1 Relationships
User 1──1 UserConstraint
User 1──N Task
Task 1──N TaskEstimate
User 1──N ScheduleVersion
ScheduleVersion 1──N ScheduleBlock
Task 1──N DecisionLog
ScheduleVersion 1──N DecisionLog
User 1──N DisruptionEvent
User 1──N ImportJob
ImportJob 1──N ImportCandidate
User 1──N TeamShare
User 1──1 NotificationPreference
# 13. API Contract

| Method | Path | Purpose |
| --- | --- | --- |
| POST | /api/auth/register | Create account |
| POST | /api/auth/login | Authenticate |
| GET | /api/me | Current user |
| POST | /api/tasks | Create task |
| GET | /api/tasks | List pending tasks |
| PATCH | /api/tasks/:id | Edit task |
| POST | /api/tasks/:id/complete | Complete / record actual duration |
| POST | /api/tasks/:id/split | Split long task |
| POST | /api/schedule/generate | Generate schedule |
| GET | /api/schedule/:userId | Current schedule |
| POST | /api/schedule/reschedule | Re-optimize after disruption |
| GET | /api/schedule/:blockId/explain | Decision explanation |
| GET | /api/schedule/:userId/burnout | Burnout/workload state |
| GET | /api/tasks/:userId/debt-ledger | Debt ledger |
| POST | /api/schedule/simulate | Preview impact |
| POST | /api/team/share | Create share link |
| GET | /api/team/:shareToken | Read-only schedule |
| POST | /api/import/syllabus | Parse syllabus candidates |
| POST | /api/import/syllabus/:jobId/confirm | Confirm candidates |
| POST | /api/import/calendar/sync | Sync fixed commitments |
| GET | /api/health | Health check |

## 13.1 API rules
Validate every request body and query parameter.
Return structured errors with code, message and recovery guidance.
Never return hashes, OAuth credentials or stack traces.
Protect every user-owned resource.
Rate-limit authentication, imports and share-link creation.
Expose scheduler algorithm version in schedule metadata.
Use idempotency keys for mutation endpoints where duplicates are possible.
# 14. Flutter UX/UI Specification
## 14.1 Visual identity

| Token | Value | Use |
| --- | --- | --- |
| inkNavy | #14192B | Base/night background |
| duskIndigo | #2A2F6B | Cards/surfaces |
| dawnAmber | #F2A65A | Primary action/priority/energy |
| restLavender | #B8A9E8 | Sleep Shield |
| alertCoral | #E8613C | Overrun/risk/disruption |
| mistWhite | #F4F2FA | Primary text |

| Typography | Use |
| --- | --- |
| Fraunces | App name, major titles, burnout hero number |
| Manrope | Body, labels, navigation, buttons |
| IBM Plex Mono | Times, durations, priority math and explanations |

## 14.2 Signature timeline
24-hour day/night timeline.
Persistent glowing Sleep Shield.
Duration-proportional task cards.
Deadline proximity and priority indicators.
Live Now marker.
Overrun/disruption state.
Reschedule settle animation around the Shield.
Reduced-motion mode snaps instantly.
## 14.3 Screen specification

| Screen | Design intent |
| --- | --- |
| Splash | Brand + calm day/night metaphor |
| Onboarding | Sleep, commitments, energy, notifications, first task |
| Today | Next action, workload, timeline, reschedule |
| Week | Seven-day overview, density, deadlines, debt |
| Task Create | Progressive form + impact preview |
| Task Detail | Metadata, estimates, history, decision |
| Explainability | Score, constraints, alternatives, reason |
| Reschedule Center | Disruption → impact → new plan → confirm |
| Burnout | Safe-hours gauge + forecast |
| Debt | Deferred work ranked by pressure |
| Imports | Calendar/syllabus workflow |
| Team | Read-only shared schedule |
| Settings | Constraints/preferences |

# 15. Offline-First, Notifications and Integrations
## 15.1 Offline strategy
Cache latest schedule locally.
Render cached data immediately.
Attempt background refresh.
Display explicit sync state.
Queue safe mutations where appropriate.
Resolve conflicts using schedule versions and timestamps.
final box = await Hive.openBox('scheduleCache');
await box.put('userId_$userId', jsonEncode(scheduleBlocks));
final cached = box.get('userId_$userId');
if (cached != null) emitCachedSchedule(cached);
final fresh = await api.getSchedule(userId);
emitFreshSchedule(fresh);
## 15.2 Notifications
Upcoming task alert.
Overload warning.
Reschedule completed.
High-debt reminder.
Daily readiness brief.
## 15.3 Syllabus import
PDF → text extraction → candidate detection → confidence score → editable candidate list → explicit confirmation → task creation. No imported candidate may silently become a task.
## 15.4 Calendar import
Use minimum OAuth scopes and convert imported busy blocks into mandatory capacity constraints. Store only information required for scheduling.
# 16. Security, Privacy and Reliability

| Area | Requirement |
| --- | --- |
| Passwords | Argon2id or bcrypt; never plaintext |
| JWT | Short-lived access token; secure refresh if used |
| Secrets | Environment variables/secret manager |
| Authorization | Every task/schedule endpoint checks ownership |
| Share links | Random token, hashed at rest, expiry and revoke |
| Transport | HTTPS in production |
| CORS | Known deployed origins only |
| PDF privacy | Delete temporary uploads after parsing unless retention requested |
| Database | Transactions for schedule replacement and decision logs |
| Observability | Correlation/request IDs |

## Failure behavior
Scheduler failure → do not publish partial schedule.
Constraint violation → reject output with actionable error.
Network failure → cached schedule with explicit offline state.
Import failure → retryable job status.
Invalid task → structured validation response.
Unauthorized access → generic authorization error without ownership leakage.
# 17. Testing and Test-Case Matrix
## 17.1 Scheduler tests

| ID | Scenario | Input | Expected |
| --- | --- | --- | --- |
| TC-SCH-001 | 7-hour floor | Attempt sleep < 7h | Rejected |
| TC-SCH-002 | No sleep overlap | Generate around midnight | Zero task blocks intersect Shield |
| TC-SCH-003 | Capacity | Tasks exceed safe capacity | Excess deferred with reasons |
| TC-SCH-004 | Knapsack | 3h/8 + 6h/9, capacity 9h | Both selected |
| TC-SCH-005 | Debt | Defer same task repeatedly | Debt/priority increases |
| TC-SCH-006 | Energy | Tie, one deep-work task | Peak window preferred |
| TC-SCH-007 | Deadline | Deadline moves closer | Urgency increases |
| TC-SCH-008 | Overrun | Actual > planned | Capacity reduced; sleep unchanged |
| TC-SCH-009 | Idempotency | Repeat reschedule | No duplicate version |
| TC-SCH-010 | Explainability | Schedule/defer tasks | Decision log exists |

## 17.2 Property/randomized tests
Run 50–100 randomized task sets and assert no schedule exceeds capacity.
Assert zero sleep intersections for randomized sleep windows.
Assert every unscheduled task is DEFERRED with a reason.
Assert deterministic output for identical input snapshots.
## 17.3 Flutter tests
Sleep slider cannot express < 7 hours.
Timeline bounds never intersect Sleep Shield.
Reduced-motion disables animation.
Explainability sheet renders all mandatory components.
Offline schedule appears before network refresh.
Syllabus candidates cannot create tasks before confirmation.
Interactive elements expose pressed/focus/disabled states.
## 17.4 End-to-end test
Onboard with 7h sleep and two peak windows.
Add five mixed academic tasks and a fixed commitment.
Generate schedule.
Assert zero sleep overlap.
Open two explanations and verify math.
Force an overrun.
Reschedule and verify movement.
Check burnout and debt.
Import syllabus and confirm candidates.
Create and open team share.
## 17.5 Visual QA
Test small phone and larger phone/tablet.
Test long titles and large estimates.
Test midnight-crossing sleep windows.
Test empty schedule.
Test extreme workload.
Disconnect network.
Resize web browser.
Verify contrast and reduced motion.
# 18. Production Deployment and CI/CD

| Environment | Purpose |
| --- | --- |
| Local | SQLite, seeded test data, debugging |
| Staging | Production-like PostgreSQL and integration testing |
| Production/Demo | Hosted API + PostgreSQL + installable Android/Web build |

## 18.2 CI pipeline
Install dependencies.
Lint/format checks.
Run scheduler unit/property tests.
Run backend API tests.
Run Flutter unit/widget tests.
Run integration tests.
Run 0% sleep-violation gate.
Build Flutter web.
Build Android release.
Deploy backend.
Run health checks and smoke tests.
## 18.3 Production checklist
HTTPS configured.
Migrations applied.
Secrets externalized.
CORS restricted.
Rate limits enabled.
Backups enabled.
Health endpoint monitored.
Physical-device release installed.
Demo data prepared safely.
# 19. Acceptance Criteria and Definition of Done
0% sleep violations across deterministic, randomized and end-to-end tests.
Seven-hour sleep floor cannot be bypassed through UI, API or import.
Core tasks persist to the database.
Schedule generation uses real task and constraint data.
Every scheduled/deferred/moved decision has an explanation record.
Rescheduling creates a new version and preserves history.
Debt increases after deferral and is visible.
Energy-aware placement is demonstrated.
Burnout compares safe capacity against scheduled workload.
Syllabus import requires explicit confirmation.
Calendar commitments affect capacity.
Team sharing is read-only, expiring and revocable.
Offline cached schedule appears without network.
Notifications work on supported platform.
API errors are actionable and do not expose stack traces.
Authentication and ownership isolation are tested.
Android release works on a physical device.
Web build works in Chrome.
All critical CI tests pass.

| RELEASE GATE<br>Do not claim “working perfectly” merely because the UI opens. Use the acceptance list as evidence. The strongest academic demonstration is a live end-to-end flow plus automated proof of the hard sleep invariant. |
| --- |

# 20. Demo / Professor Presentation Flow
Open Equilibrium and show the premium dark day/night identity.
Show onboarding and demonstrate the sleep slider cannot go below seven hours.
Create five academic tasks with different weights, deadlines and cognitive loads.
Generate the week and point out the Sleep Shield.
Open a high-priority task and show its actual score.
Open a deferred task and show exactly why it was not selected.
Trigger an overrun and tap Reschedule.
Show cards moving around the Shield.
Open Burnout and show safe capacity vs scheduled workload.
Open Debt and show deferred-task pressure increasing.
Upload a syllabus PDF; show candidates, edit one and confirm.
Generate a read-only team link and open it elsewhere.
Turn off the network and show the cached schedule.
Explain the Deep Learning layer: duration/risk predictions improve planning but cannot violate hard constraints.
Closing line: “Equilibrium is not a reminder app. It is a constrained academic workload optimizer that protects sleep, adapts when reality changes, and explains every important trade-off.”
# 21. KPIs, Risks and Mitigations

| KPI | Target |
| --- | --- |
| Sleep violation rate | 0% — non-negotiable |
| Reschedule recovery | < 3 seconds on normal demo workload |
| Reschedule success | > 95% in chaos tests |
| Explainability engagement | > 40% in pilot usage |
| Schedule generation | Immediate-feeling for typical workloads |
| Offline first paint | Cached schedule visible immediately |
| Import confirmation safety | 100% of candidates require confirmation |
| API error clarity | 100% actionable errors in tested flows |

| Risk | Mitigation |
| --- | --- |
| Valid but impractical schedule | Separate selection from placement; energy/continuity/fragmentation penalties. |
| Hard sleep feels rigid | Explain guarantee and show safe alternatives. |
| Feature overload | Keep Today → Schedule → Explain → Reschedule dominant. |
| Wrong PDF tasks | Confidence + mandatory confirmation + editing. |
| ML prediction wrong | Advisory only, confidence and user override. |
| Offline conflict | Schedule versions and explicit sync state. |

# 22. Future Enhancements
Local-only Ollama summaries, never in critical scheduling.
Personal estimate calibration.
Exam-period mode.
Subject analytics and semester heatmaps.
Progressive web access to shared schedules.
Expanded accessibility.
Privacy-preserving/federated learning.
Multi-semester planning.
Bidirectional calendar sync.
Research-grade optimizer benchmarking.
# 23. Suggested Project Repository
equilibrium/
├── README.md
├── docs/
│   ├── product_specification.md
│   ├── architecture/
│   ├── api/
│   ├── testing/
│   └── demo/
├── app/
│   ├── lib/
│   │   ├── core/{theme,network,storage,routing,accessibility}/
│   │   ├── features/
│   │   │   ├── onboarding/
│   │   │   ├── today/
│   │   │   ├── tasks/
│   │   │   ├── schedule/
│   │   │   ├── explain/
│   │   │   ├── reschedule/
│   │   │   ├── burnout/
│   │   │   ├── debt_ledger/
│   │   │   ├── calendar_import/
│   │   │   ├── syllabus_import/
│   │   │   └── team_view/
│   │   ├── models/
│   │   └── main.dart
│   └── test/
├── server/
│   ├── src/{scheduler,services,routes,middleware,parsing,utils}/
│   ├── prisma/
│   └── tests/
├── ml/
│   ├── data/
│   ├── notebooks/
│   ├── src/
│   ├── models/
│   └── evaluation/
└── .github/workflows/
# 24. Viva / Evaluation Questions and Answers
Q: Why is Equilibrium different from a to-do list?
A: A to-do list stores work; Equilibrium computes a feasible workload plan under hard constraints and adapts after disruptions.
Q: Why is seven-hour sleep a hard constraint?
A: It is the product's core safety promise and is enforced mathematically rather than only warned about.
Q: Why use Knapsack?
A: It models selecting the highest-value subset of work that fits within safe capacity.
Q: Why not use an LLM for scheduling?
A: A deterministic optimizer is easier to verify, reproduce and prove safe. LLMs can remain optional for summaries.
Q: Where is Deep Learning used?
A: A learning layer predicts realistic task duration and workload risk from historical completion data; these predictions improve planning without overriding constraints.
Q: What happens when everything cannot fit?
A: Lower-value work is deferred, a reason is logged and debt increases so the work remains visible.
Q: How is explainability achieved?
A: Structured priority components, reason codes, alternatives, capacity and algorithm version are persisted.
Q: What happens after an overrun?
A: Remaining capacity is recomputed and the plan is re-optimized while sleep and fixed commitments remain protected.
Q: How do you prove the Sleep Shield is real?
A: The backend rejects invalid schedules, automated tests assert zero overlap, and the UI timeline also respects the Shield.
Q: How does syllabus import avoid mistakes?
A: Parsing creates editable candidates with confidence; only explicit confirmation creates tasks.
Q: How is privacy handled?
A: Ownership checks, hashed credentials/tokens, minimum OAuth scopes, HTTPS, externalized secrets and controlled retention.
# Appendix A — Implementation Order

| Phase | Deliverable |
| --- | --- |
| 0 | Freeze requirements, UX flows, design tokens and architecture. |
| 1 | Repository, Flutter app, Node server, Prisma, environments and CI. |
| 2 | Database, migrations, authentication and authorization. |
| 3 | Scheduler engine: constraints, scoring, Knapsack, placement, energy, debt, validator. |
| 4 | Decision logging and schedule versions. |
| 5 | Backend APIs. |
| 6 | Flutter design system and navigation. |
| 7 | Core screens. |
| 8 | Timeline polish, Shield visualization, reschedule animation, reduced motion. |
| 9 | Burnout, debt, calendar, syllabus and team sharing. |
| 10 | Offline cache and notifications. |
| 11 | Unit, widget, integration, property and chaos testing. |
| 12 | Security and production hardening. |
| 13 | Deployment and physical-device release. |
| 14 | Demo evidence, screenshots, documentation and final acceptance. |

# Appendix B — Final Build Philosophy
Build and prove the scheduler before polishing every screen. The project's uniqueness depends on a correct, explainable optimizer. The strongest evidence is a verifiable chain: constraints → optimization → schedule → explanation → disruption → re-optimization → measurable outcome.
