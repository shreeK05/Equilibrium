# Equilibrium Traceability Matrix

Every feature requested in the Master Blueprint maps directly to a strict technical requirement, implementation target, and validation test.

| Blueprint Requirement | Architecture Component | Implementation File / Module | API Endpoint | UI Surface | Testing Target |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Hard Sleep Constraint** | Constraint Guard | `server/src/scheduler/guard.ts` | `PUT /constraints` | Onboarding / Settings / Sleep Shield | `test/guard.test.ts` (Asserts throw on <7h or overlap) |
| **0/1 Knapsack Selection** | DP Solver | `server/src/scheduler/knapsack.ts` | `POST /schedule/generate` | (Invisible Backend) | `test/knapsack.test.ts` (Asserts optimal value subset) |
| **Task Splitting & Partial Scheduling** | Placement Engine | `server/src/scheduler/placement.ts` | `POST /schedule/generate` | Timeline (split cards) | `test/split.test.ts` (Asserts chunks respect max limit and gaps) |
| **Capacity Calculation** | Slot Math Engine | `server/src/scheduler/capacity.ts` | `POST /schedule/generate` | Workload/Burnout Gauge | `test/capacity.test.ts` (Validates modulo 24h wrapping) |
| **Priority Scoring** | Math Priority Scorer | `server/src/scheduler/priority.ts` | (Internal to Scheduler) | Explainability Sheet | `test/priority.test.ts` (Asserts correct factor weights) |
| **Anti-Fragile Rescheduling**| Pipeline & Disruption | `server/src/scheduler/reschedule.ts` | `POST /schedule/reschedule` | Reschedule FAB / Motion | `test/reschedule.test.ts` (Asserts locked past chunks & remaining dur) |
| **Explainability** | Decision Logger | `server/src/scheduler/logger.ts` | `GET /schedules/:id/decisions` | `ExplanationSheet` UI | `test/logger.test.ts`, `api.test.ts` (Asserts IDOR protections) |
| **Schedule Debt** | Debt Tracker | `server/src/scheduler/priority.ts` | `GET /tasks/debt-ledger` | Debt Ledger UI | `test/debt.test.ts` (Asserts $P_i$ increases with partial/full deferrals) |
| **Energy Windows** | Placement Heuristic | `server/src/scheduler/placement.ts` | `PUT /constraints` | Task Edit / Onboarding | `test/energy.test.ts` (Asserts HIGH load shifts to peak) |
| **Syllabus PDF Import** | Extraction Service | `server/src/integrations/pdf.ts` | `POST /import/syllabus` | Candidate Confirmation UI| `test/pdf.test.ts` (Asserts no silent task creation) |
| **Calendar Import** | Google OAuth Service | `server/src/integrations/cal.ts` | `POST /calendar/connect` | Import Settings | `test/cal.test.ts` (Asserts fetched events become FIXED) |
| **Team Share** | Share Link Generator | `server/src/routes/team.ts` | `POST /team/share` | Web Read-only View | `test/team.test.ts` (Asserts no PII leak, read-only token) |
| **Offline Cache** | Hive Storage Layer | `mobile/lib/core/storage/` | (Client-side) | App Startup Timeline | `widget/offline.test.dart` (Asserts render without net) |
