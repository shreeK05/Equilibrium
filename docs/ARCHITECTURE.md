# Equilibrium Architecture

## 1. System Overview
Equilibrium is a high-end student workload optimization system. It uses a deterministic backend scheduling engine to mathematically guarantee sleep protection while balancing academic workloads via a 0/1 Knapsack solver and heuristic placement algorithms. 

## 2. Component Hierarchy
1. **Frontend (Flutter)**: Handles UI, offline caching (Hive), user inputs, and schedule rendering (Day/Night timeline). It visually strictly enforces the Sleep Shield bounds but does not compute the schedule itself.
2. **Backend API (Node.js/Express)**: Stateless REST API validating requests via Zod and guarding resource access via JWT.
3. **Scheduling Engine (TypeScript Core)**: The isolated mathematical module. It parses constraints, runs the DP Knapsack algorithm, performs time-slot placement, and generates cryptographic-like decision logs.
4. **Persistence Layer (Prisma + PostgreSQL)**: Relational data store enforcing schema integrity, foreign keys, and version histories.

## 3. The 11 Core Architectural Concepts
1. **Schedule Versions/History**: Immutable records of every generated schedule. Enables exact state rollback and auditing of what changed.
2. **Disruption Records**: Explicit entities capturing deviations (e.g., "Task A took +2 hours"). Acts as the trigger for a reschedule re-solve.
3. **Decision Logs**: Mathematical audit trails explaining exactly why a task was included or deferred, tied directly to the Schedule Version.
4. **Schedule Debt History**: A running counter of how many times a task has been deferred due to capacity limits. Incrementally influences its priority.
5. **Energy Windows**: User-defined periods of peak cognitive function, acting as soft placement heuristics for heavy cognitive-load tasks.
6. **Fixed Commitments**: Hard blocks representing mandatory time (e.g., classes, imported Google Calendar events) that subtract from available capacity.
7. **Workload Capacity**: The exact integer count of available 30-minute slots remaining after subtracting sleep and fixed commitments.
8. **Task Completion State**: Real-time tracking of task progress to dynamically inform the remaining schedule capacity.
9. **Spatial Timeline UI**: Flutter visualization explicitly mapping the backend array into a strict mathematical absolute-positioned UI Stack, enforcing constraint mapping without regenerating data.
10. **Offline Local State**: Hive-backed cache allowing immediate rendering and limited interaction without an active network connection.
11. **Synchronization State**: A background synchronization queue that reconciles local edits with the backend engine.

## 4. Design Principles
- **Determinism Over AI Magic**: The scheduling engine must yield the exact same schedule given the exact same inputs and constraints. No black-box LLMs generate the schedule.
- **Fail-Safe Constraints**: The system must prefer to leave a task completely unscheduled (and explain why) rather than silently violate the Sleep Shield or a fixed commitment.
- **Portability**: All core logic runs in standard Node/TS containers. The DB is standard Postgres/SQLite. No proprietary or paid SaaS vendor lock-in.
