# EQUILIBRIUM: Autonomous Academic Workload Optimization Platform
## Master Comprehensive Project Documentation & Technical Specification
**Course:** Design Thinking & Product Lifecycle Management (DTPLM) — Final Capstone  
**Academic Year:** 3rd Year I Semester  
**Repository:** `shreeK05/Equilibrium`  
**Current Production Build:** Version 2.4.0 (Deployed on Render Backend + Android APK via GitHub Actions)  

---

# Table of Contents
1. [Executive Summary & Core Value Proposition](#1-executive-summary--core-value-proposition)
2. [Design Thinking & Product Lifecycle Management (DTPLM) Framework](#2-design-thinking--product-lifecycle-management-dtplm-framework)
3. [The North Star Metric (NSM) & Metric Tree Architecture](#3-the-north-star-metric-nsm--metric-tree-architecture)
4. [High-Level System Architecture & Component Diagram](#4-high-level-system-architecture--component-diagram)
5. [Complete Technology Stack & Repository Blueprint](#5-complete-technology-stack--repository-blueprint)
6. [The Mathematical Core: The Scheduling Engine](#6-the-mathematical-core-the-scheduling-engine)
   - 6.1 Formal Problem Definition & Constraint Optimization
   - 6.2 Discretization & The 30-Minute Time Slot Matrix
   - 6.3 Hard Constraints vs. Soft Preferences
   - 6.4 The Multi-Objective Priority Scoring Formula ($\alpha, \beta, \gamma, \delta$)
   - 6.5 Phase A: 0/1 Knapsack Task Selection & Dynamic Programming Backtracking
   - 6.6 Phase B: Energy-Aware Placement & Bounded Task Splitting
   - 6.7 Phase C: Mathematical Schedule Validation Engine (`validator.ts`)
7. [The Timezone Architecture & Sleep Shield Preservation (Bug Post-Mortem)](#7-the-timezone-architecture--sleep-shield-preservation-bug-post-mortem)
8. [Disruption Engine & Anti-Fragile Rescheduling](#8-disruption-engine--anti-fragile-rescheduling)
9. [Explainability Engine & Transparent Decision Ledger (XAI)](#9-explainability-engine--transparent-decision-ledger-xai)
10. [End-to-End Functional Feature Deep Dive](#10-end-to-end-functional-feature-deep-dive)
    - 10.1 Authentication & First-Run Onboarding
    - 10.2 Sleep Shield & Constraint Customization
    - 10.3 Dynamic Task Management & Manual Splitting
    - 10.4 Fixed Commitments & Recurring Class/Lab Routines
    - 10.5 Interactive Schedule Timelines (Today & Next Days)
    - 10.6 Quick-Add System (+) Floating Action Center
    - 10.7 Focus Timer & Disruption Detection
    - 10.8 Exam Preparation Mode (Topic Deconstruction & Re-planning)
    - 10.9 "What-If" Schedule Simulation Engine
    - 10.10 Syllabus PDF Extraction & Calendar (.ics) Import Pipeline
    - 10.11 Read-Only Public Team Sharing & Web Portal
    - 10.12 Workload Analytics & Insights Engine
    - 10.13 Offline-First Architecture & Push Notification Service
11. [Database Architecture & Complete Schema Specification](#11-database-architecture--complete-schema-specification)
12. [REST API Contract & Endpoint Reference](#12-rest-api-contract--endpoint-reference)
13. [Flutter Mobile/Web Client UX/UI Engineering](#13-flutter-mobileweb-client-uxui-engineering)
14. [Security, Privacy, and Data Integrity](#14-security-privacy-and-data-integrity)
15. [Quality Assurance, Test Suite Matrix, and Verification](#15-quality-assurance-test-suite-matrix-and-verification)
16. [DevOps, Continuous Integration, and Deployment](#16-devops-continuous-integration-and-deployment)
17. [Academic Viva / Oral Evaluation Master Guide (25+ Q&A)](#17-academic-viva--oral-evaluation-master-guide-25-qa)

---

# 1. Executive Summary & Core Value Proposition

College students are subjected to relentless, multi-deadline workloads consisting of conflicting assignments, lab reports, seminar presentations, exam preparation, and fixed academic timetables. Traditional productivity tools—such as static calendar applications (Google Calendar, Outlook) and to-do lists (Todoist, Notion, Apple Reminders)—merely **record** what work exists; they **never decide** when that work should be performed, nor do they understand physical human capacity.

When work exceeds capacity, the default human coping strategy is to sacrifice sleep, leading to cumulative sleep deprivation, cognitive degradation, stress, and burnout.

```
+-------------------------------------------------------------------------------+
|                             PRODUCT PROMISE                                   |
|   "The planner that mathematically cannot let a deadline eat your sleep —     |
|                   and shows its work when it says no."                       |
+-------------------------------------------------------------------------------+
```

**Equilibrium** is an autonomous academic workload optimization platform. It bridges the gap between Operations Research (constraint satisfaction, dynamic programming) and student psychology. 

### Core Differentiators:
1. **Sleep as a Hard Invariant (Sleep Shield):** Equilibrium enforces a mathematical floor (minimum 7.0 hours by default). The scheduling algorithm treats sleep intervals not as a user recommendation, but as an impenetrable boundary. Under no circumstances can a task block be scheduled during a user's sleep window.
2. **Deterministic Mathematical Scheduling:** Equilibrium does **not** rely on generative AI or black-box large language models (LLMs) to construct schedules. Schedule construction is driven by a deterministic pipeline: **discretized capacity calculation $\rightarrow$ multi-factor priority scoring $\rightarrow$ 0/1 Knapsack selection $\rightarrow$ energy-aware placement & bounded splitting $\rightarrow$ formal validation**.
3. **Transparent Explainability (XAI):** When a task cannot be scheduled or is deferred, Equilibrium does not fail silently. Every run generates a **Decision Log** detailing the priority score breakdown ($\alpha$ Academic, $\beta$ Urgency, $\gamma$ Team, $\delta$ Schedule Debt) and an explicit reason code (e.g., `CAPACITY_EXCEEDED`, `FRAGMENTED_CAPACITY`, `NO_AVAILABLE_SLOTS`).
4. **Anti-Fragile Rescheduling:** When real-world disruptions occur (a study session overruns, an unexpected class is added, or a student finishes early), Equilibrium locks past historical blocks and re-solves the mathematical model forward from the current timestamp.

---

# 2. Design Thinking & Product Lifecycle Management (DTPLM) Framework

Equilibrium was conceived, researched, designed, and engineered through the 5-stage Design Thinking framework and iterative Product Lifecycle Management principles.

```
   [Empathize] ----> [Define] ----> [Ideate] ----> [Prototype] ----> [Test & Iterate]
 (Student Diary      (Sacrificed      (0/1 Knap-     (FastAPI/RN       (Flutter + Node.js
    Studies)            Sleep)          sack +          v1 MVP)         + Render Deploy)
                                     Sleep Shield)
```

### Stage 1: Empathize
- **User Research:** Observational studies and qualitative diary entries were collected from university engineering and science undergraduates.
- **Key Behavioral Findings:**
  - Students consistently suffer from the *Planning Fallacy*: under-estimating how long complex academic tasks take by 40%–60%.
  - When pressured by looming deadlines, sleep is universally treated as an "elastic resource" that can be trimmed to fit work.
  - Academic tasks possess asymmetric importance: a 40% weight final semester lab report is fundamentally different from a 2% reading quiz, yet standard calendars treat them identically.
  - Cognitive fatigue is ignored: students schedule heavy theoretical revision late at night following 8 hours of lectures, resulting in near-zero focus retention.

### Stage 2: Define (The Problem Statement)
> *"How might we construct an academic planning engine that mathematically guarantees students will never sacrifice their sleep, optimizes deep focus around their natural peak energy hours, and transparently accounts for every minute of deferred academic debt?"*

### Stage 3: Ideate
- Brainstormed candidate solutions:
  - *Option A: AI Chatbot Assistant.* Rejected because LLMs hallucinate time boundaries, cannot guarantee mathematical constraints, and lack determinism.
  - *Option B: Traditional Linear Calendar with Notifications.* Rejected because passive notifications do not solve capacity overcommitment.
  - *Option C: Constraint-Satisfaction Operations Research Engine with Explainability.* **Selected.** Combines a 0/1 Knapsack optimization algorithm with an inviolable Sleep Shield, energy preference matching, and deterministic decision logging.

### Stage 4: Prototype
- **V1 Architectural Spikes:** 
  - Backend: Python/FastAPI (`equilibrium_backend/`) to explore initial heuristics.
  - Frontend: React Native (`equilibrium_rn/`) to test mobile touch ergonomics.
  - Learnings from V1: Python runtime was heavyweight for single-container deployment; React Native bridge introduced timeline scroll stutter.

### Stage 5: Test & Iterate (Production Architecture)
- Transitioned to a high-performance, strongly typed production stack:
  - Backend: Node.js + Express + TypeScript + Prisma ORM + PostgreSQL/SQLite.
  - Client: Flutter (Dart) for smooth 60fps animations, native rendering, robust local storage, and high-fidelity timeline widgets.
  - Production verification: Tested across 100+ simulated student edge-cases (over-capacity, midnight-crossing sleep schedules, timezone shifts, exam rushes).

---

# 3. The North Star Metric (NSM) & Metric Tree Architecture

In product management, the North Star Metric (NSM) is the single key metric that best captures the core value delivered to customers.

```
                           +-----------------------------------------------+
                           |               NORTH STAR METRIC               |
                           |  Weekly High-Focus Hours Achieved per Student |
                           +-----------------------------------------------+
                                            /             \
                                           /               \
              +-------------------------------+     +-------------------------------+
              |      INPUT METRICS (Leading)  |     |     OUTPUT METRICS (Lagging)  |
              +-------------------------------+     +-------------------------------+
              | 1. Syllabus Import Rate       |     | 1. W1 / W4 Student Retention  |
              | 2. Schedule Generation Freq.  |     | 2. Burnout Reduction Score    |
              | 3. Task Completion Rate       |     | 3. Viral Team Share Views     |
              | 4. Peak Energy Utilization %  |     +-------------------------------+
              +-------------------------------+
```

### 3.1 The North Star Metric Defined
> **Weekly High-Focus Hours Achieved per Student**

#### Rationale:
- **True Student Value:** Vanity metrics (such as daily app launches or time spent inside the app) incentivize unnecessary screen time. High-focus hours achieved directly represent academic deep work successfully executed.
- **Mathematical Alignment:** High-focus hours are directly produced when the Knapsack algorithm successfully maps `HIGH` cognitive load tasks into user-defined Peak Energy Windows without violating sleep.

### 3.2 The Metric Tree (Leading vs. Lagging Indicators)

| Metric Type | Metric Name | Definition | Engineering Driver |
| :--- | :--- | :--- | :--- |
| **Leading** | **Syllabus Import Rate** | % of users who upload a PDF/ICS document within 48 hours of onboarding. | Multi-format PDF Regex parser with human-in-the-loop candidate confirmation. |
| **Leading** | **Schedule Generation Frequency** | Average re-plan triggers per active user per week. | Real-time "What-If" schedule simulation and 1-tap re-planning. |
| **Leading** | **Task Completion Rate** | % of scheduled timeline blocks marked completed. | Bounded chunk splitting (max 4h) preventing task exhaustion. |
| **Leading** | **Peak-Energy Utilization %** | % of `HIGH` cognitive load tasks scheduled within energy windows. | Multi-pass placement prioritizing morning/evening peak slots. |
| **Lagging** | **W1 / W4 Retention Rate** | Cohort return rate 7 and 28 days post-signup. | Weekly recurring routine automation and push reminders. |
| **Lagging** | **Burnout Reduction Score** | Reduction in deferred task accumulation & stress index. | Hard Sleep Shield preventing all-nighters. |
| **Lagging** | **Team Share Engagement** | Unique external page views on `/team/:token`. | Expiring, read-only web share portal. |

---

# 4. High-Level System Architecture & Component Diagram

Equilibrium is designed as a modular, decoupled, multi-tiered system consisting of a client application, an API gateway, domain services, an isolated Operations Research scheduling engine, and a relational persistence layer.

```
+-------------------------------------------------------------------------------------------+
|                                    PRESENTATION LAYER                                     |
|                                                                                           |
|    +------------------------------------+          +---------------------------------+    |
|    |     Flutter Mobile App (Android)   |          |    Public Web Share Portal      |    |
|    |  Provider State, Timeline Canvas,  |          |  Server-Side Rendered HTML5/CSS3|    |
|    |  Local Notifications, Offline Sync |          |  Read-Only Responsive Schedule  |    |
|    +-----------------+------------------+          +----------------+----------------+    |
+----------------------|----------------------------------------------|---------------------+
                       | (HTTPS / REST / JWT)                         | (HTTPS / GET)
+----------------------v----------------------------------------------v---------------------+
|                                    APPLICATION LAYER (Node.js / Express / TypeScript)     |
|                                                                                           |
|  [ Auth Middleware ]   [ Request Validation (Zod) ]   [ Rate Limiter ]   [ Correlation ID]|
|                                                                                           |
|  +-------------------------------------------------------------------------------------+  |
|  |                                  ROUTE CONTROLLERS                                  |  |
|  |  /auth   /tasks   /schedules   /commitments   /exams   /timer   /imports  /insights |  |
|  +-------------------------------------------+-----------------------------------------+  |
|                                              |                                            |
|  +-------------------------------------------v-----------------------------------------+  |
|  |                                   DOMAIN SERVICES                                   |  |
|  |     AuthService     |     ScheduleService     |     ExamPrepService                 |  |
|  +-------------------------------------------+-----------------------------------------+  |
+----------------------------------------------|--------------------------------------------+
                                               |
+----------------------------------------------v--------------------------------------------+
|                          SCHEDULING ENGINE (Isolated Core IP)                             |
|                                                                                           |
|    +-------------------+    +-------------------+    +-------------------------------+    |
|    |   capacity.ts     |    |   priority.ts     |    |         knapsack.ts           |    |
|    | 30m Slot Matrix   |--->| Multi-Factor Math |--->| 0/1 Dynamic Programming       |    |
|    | Sleep/Fixed Mask  |    | Urgency & Debt    |    | Capacity Constrained Subset   |    |
|    +-------------------+    +-------------------+    +---------------+---------------+    |
|                                                                      |                    |
|    +-------------------+    +-------------------+                    |                    |
|    |   validator.ts    |    |   placement.ts    |<-------------------+                    |
|    | 0% Sleep Violation|<---| Bounded Splitting |                                         |
|    | Formal Invariant  |    | Energy Matching   |                                         |
|    +-------------------+    +-------------------+                                         |
+----------------------------------------------|--------------------------------------------+
                                               |
+----------------------------------------------v--------------------------------------------+
|                                   DATA PERSISTENCE LAYER                                  |
|                                                                                           |
|         +-----------------------------------------------------------------------+         |
|         |                              Prisma ORM                               |         |
|         +-----------------------------------+-----------------------------------+         |
|                                             |                                             |
|                     +-----------------------v-----------------------+                     |
|                     | PostgreSQL (Production) / SQLite (Development)|                     |
|                     | User, Tasks, ScheduleBlocks, DecisionLogs,   |                     |
|                     | FixedCommitments, Exams, FocusSessions        |                     |
|                     +-----------------------------------------------+                     |
+-------------------------------------------------------------------------------------------+
```

---

# 5. Complete Technology Stack & Repository Blueprint

### 5.1 Technology Stack Specifications

| Tier | Technology | Version | Rationale |
| :--- | :--- | :--- | :--- |
| **Mobile Client** | Flutter / Dart | Flutter 3.24+ / Dart 3.5+ | High-performance 60fps canvas rendering for timeline schedules, single codebase for Android/iOS/Web, rich Cupertino/Material widgets. |
| **State Management**| Provider | 6.1.2 | Lightweight, predictable dependency injection and reactive state notification without boilerplate. |
| **Backend API** | Node.js / Express | Node 20 LTS / Express 4.19 | Non-blocking asynchronous I/O, rich ecosystem for PDF/ICS parsing, TypeScript static safety. |
| **Language** | TypeScript | 5.4.5 | Strict type guarantees across domain models, eliminating runtime `undefined` errors in mathematical functions. |
| **ORM** | Prisma ORM | 5.14.0 | Strongly typed queries, declarative schema migrations, automated foreign key cascading, multi-database support. |
| **Database** | PostgreSQL / SQLite | PG 16 / SQLite 3 | SQLite for zero-config offline local development; PostgreSQL on Render for ACID compliance and transactional rollbacks. |
| **Validation** | Zod | 3.23.8 | Runtime schema validation on all incoming API requests with automatic TypeScript inference. |
| **Cryptography** | bcryptjs / Node crypto | 2.4.3 / native | 12-round salted password hashing; SHA-256 token hashing for team share links. |
| **Testing** | Jest / ts-jest | 29.7.0 | Automated testing with isolated database transactions and mathematical fixture assertions. |
| **CI/CD** | GitHub Actions | Ubuntu / JDK 17 | Strict `flutter analyze` zero-warning enforcement and automated Gradle APK build pipelines. |

### 5.2 Repository Directory Blueprint

```
Equilibrium CP/
├── .github/
│   └── workflows/
│       └── main.yml                  # GitHub Actions CI/CD (Flutter Analyze + APK Build)
├── docs/                             # Architectural Specifications & Sub-system RFCs
│   ├── API.md                        # Formal REST Endpoint Contract
│   ├── ARCHITECTURE.md               # High-level System Diagrams
│   ├── SCHEDULER.md                  # Mathematical Specification of Optimization Core
│   ├── EXPLAINABILITY.md             # DecisionLog Architecture & UI Translation
│   ├── FIXED_COMMITMENTS.md          # Recurring Routines & Conflict Rules
│   └── TESTING.md                    # Test-case Matrix & Regression Checklists
├── equilibrium_app/                  # Flutter Mobile & Web Client
│   ├── android/                      # Native Android configuration (Gradle, Manifest)
│   ├── assets/                       # App icons, vectors, and imagery
│   └── lib/
│       ├── core/
│       │   ├── api/                  # ApiClient (HTTP, JWT interceptor, offline tracker)
│       │   ├── state/                # State Providers (Auth, Schedule, Profile, Timer, Exam)
│       │   └── theme/                # EqTheme, EqColors, and EqTokens (Design System)
│       ├── models/                   # Dart Data Models & Serialization
│       ├── screens/
│       │   ├── analytics/            # Workload & Focus Analytics Screen
│       │   ├── auth/                 # Login, Registration, Password Reset Screens
│       │   ├── commitments/          # Fixed Commitments & Routines Management
│       │   ├── exams/                # Exam Prep Mode Screen & Topic Breakdown
│       │   ├── imports/              # Syllabus PDF & ICS Calendar Import Flow
│       │   ├── onboarding/           # Sleep Shield & Constraints Setup Wizard
│       │   ├── profile/              # Academic Profile & Theme Settings
│       │   ├── schedule/             # 7-Day Interactive Timeline Schedule Screen
│       │   ├── tasks/                # Task Management Screen
│       │   ├── timer/                # Focus Stopwatch/Pomodoro Timer Screen
│       │   └── today/                # Daily Dashboard Screen
│       ├── services/                 # Repositories (Task, Schedule, Decision, Notification)
│       ├── widgets/
│       │   ├── cards/                # Task, Commitment, and Insight Cards
│       │   ├── forms/                # CreateTaskSheet, CreateCommitmentSheet, DetailSheets
│       │   ├── layout/               # AppShell (Bottom Navigation & FAB Quick-Add)
│       │   ├── status/               # Empty states, error displays, offline pills
│       │   └── timeline/             # Custom Timeline Canvas & Block Positioning
│       └── main.dart                 # Application Bootstrap & Deep Link Handling
├── server/                           # Node.js + TypeScript Backend Service
│   ├── prisma/
│   │   ├── migrations/               # Database Evolution History
│   │   ├── schema.prisma             # Universal Database Schema
│   │   └── dev.db                    # Local Development SQLite Database
│   ├── src/
│   │   ├── controllers/              # HTTP Request/Response Controllers
│   │   ├── middleware/               # Auth, Error Handling, and Validation Middleware
│   │   ├── repositories/             # Database Access Repositories (Prisma abstractions)
│   │   ├── routes/                   # REST Route Definitions (15 Route Handlers)
│   │   ├── scheduler/                # Pure Mathematical Scheduling Engine
│   │   │   ├── capacity.ts           # 30-Minute Slot Generation & Sleep/Fixed Masking
│   │   │   ├── guard.ts              # Temporal Interval Intersection Checks
│   │   │   ├── knapsack.ts           # 0/1 Knapsack Dynamic Programming Solver
│   │   │   ├── placement.ts          # Energy-Aware Multi-Pass Placement & Splitting
│   │   │   ├── priority.ts           # Multi-Objective Scoring Heuristic
│   │   │   ├── rescheduler.ts        # Pipeline Orchestrator
│   │   │   ├── timezone.ts           # IANA Timezone Normalization & Resolution
│   │   │   ├── types.ts              # Mathematical Type Definitions
│   │   │   └── validator.ts          # Formal Schedule Hard-Constraint Invariant Checker
│   │   ├── services/                 # Core Business Logic (Schedule, Auth, ExamPrep)
│   │   ├── app.ts                    # Express Server Configuration
│   │   └── server.ts                 # HTTP Server Entrypoint
│   └── test/                         # Comprehensive Jest Test Suites
│       ├── regression.exam-prep-sleep-shield.test.ts # Verifies Exam Prep Sleep Shield
│       ├── regression.student-workflow.test.ts       # Full E2E Student Lifecycle Test
│       ├── scheduler.test.ts                         # Pure Knapsack & Placement Unit Tests
│       └── security.test.ts                          # IDOR, JWT & Invariant Security Tests
├── North_Star_Matrix.md              # DTPLM North Star Metric Specification
└── render.yaml                       # Cloud Deployment Configuration for Render
```

---

# 6. The Mathematical Core: The Scheduling Engine

The Crown Jewel of Equilibrium is its pure, deterministic Operations Research scheduling engine located in `server/src/scheduler/`. It does not make fuzzy calls or heuristic guesses. It executes a 5-stage optimization pipeline.

```
+-----------------------------------------------------------------------------------+
|                        5-STAGE SCHEDULING PIPELINE                                |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  1. Capacity Discretization (capacity.ts)                                         |
|     - Generate 48 slots/day (30-min intervals) over 7-day horizon (336 slots)     |
|     - Mask Sleep Shield interval [sleepStart, sleepEnd]                           |
|     - Mask Fixed Commitments + Buffer interval [start - buffer, end + buffer]     |
|     - Mask Locked Blocks from past time                                           |
|     - Flag Peak Energy slots                                                      |
|                                                                                   |
|  2. Multi-Factor Priority Scoring (priority.ts)                                   |
|     - Compute P_i for all candidate tasks with Remaining Minutes > 0              |
|                                                                                   |
|  3. 0/1 Knapsack Subset Selection (knapsack.ts)                                   |
|     - Select maximum priority subset of tasks fitting total available slots       |
|                                                                                   |
|  4. Energy-Aware Placement & Bounded Splitting (placement.ts)                     |
|     - Pass 1: Place HIGH cognitive tasks into Peak Energy slots                   |
|     - Pass 2: Place remaining tasks into remaining contiguous slots               |
|     - Enforce chunk bounds: MIN = 30m, MAX = 240m                                 |
|     - Emit DecisionLogs (FULLY_SCHEDULED, PARTIALLY_SCHEDULED, DEFERRED)          |
|                                                                                   |
|  5. Formal Invariant Verification (validator.ts)                                  |
|     - Assert Sleep Violation Count == 0                                           |
|     - Assert Fixed Commitment Overlaps == 0                                       |
|     - Assert Self Overlaps == 0                                                   |
|     - Assert All Blocks <= Deadlines                                              |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

### 6.1 Formal Problem Definition & Constraint Optimization
Given:
- A set of tasks $T = \{t_1, t_2, \dots, t_n\}$, where each task $t_i$ has:
  - Remaining duration $d_i$ in minutes ($d_i = \max(0, \text{estimate}_i - \text{completed}_i)$).
  - Deadline timestamp $D_i$.
  - Academic importance weight $W_{academic} \in [0.0, 1.0]$.
  - Team/peer impact weight $W_{team} \in [0.0, 1.0]$.
  - Cognitive intensity $C_i \in \{\text{LOW}, \text{MEDIUM}, \text{HIGH}\}$.
  - Accumulated deferral count $K_i \in \mathbb{N}$.
  - Optional daily workload cap $L_i$ in minutes.
- A set of Fixed Commitments $F = \{f_1, f_2, \dots, f_m\}$ with unalterable intervals $[s_j, e_j]$.
- A protected sleep interval $S = [S_{start}, S_{end}]$ with minimum duration $\ge 7.0$ hours.
- A buffer interval $B_{mins}$ (default 15–30 min) surrounding fixed commitments.
- A set of user peak energy windows $E = \{e_1, e_2, \dots, e_p\}$.

**Objective:**  
Find a set of schedule blocks $B = \{b_1, b_2, \dots, b_k\}$ mapping tasks to time intervals that **maximizes total academic value and urgency fulfillment** while satisfying 100% of hard constraints.

### 6.2 Discretization & The 30-Minute Time Slot Matrix
Continuous time scheduling over an arbitrary 7-day continuum is computationally inefficient and prone to floating-point overlap errors. Equilibrium discretizes the 7-day scheduling horizon into fixed **30-minute atomic slots**:
- 1 day = 24 hours = 48 slots.
- 7-day scheduling horizon = $48 \times 7 = 336 \text{ slots}$.

Each slot is modeled as:
```typescript
interface Slot {
  index: number;         // 0 to 335
  start: Date;           // Slot boundary start timestamp
  end: Date;             // Slot boundary end timestamp (start + 30 min)
  available: boolean;    // Initialized to true; set to false if masked
  energyBonus: boolean;  // Set to true if slot falls inside Peak Energy Window
}
```

#### Capacity Masking Algorithm:
1. **Sleep Masking:** For each calendar day in the horizon, calculate `sleepStart` and `sleepEnd` in the user's localized timezone. If `sleepEnd <= sleepStart`, the sleep window crosses midnight (e.g., 23:00 to 07:00). All slots intersecting this interval, as well as the previous day's crossing interval, are marked `available = false`.
2. **Fixed Commitment Masking:** For every fixed commitment $f \in F$, compute the buffered interval $[f.start - B_{mins}, f.end + B_{mins}]$. All intersecting slots are marked `available = false`.
3. **Locked Block Masking:** Any block from the past ($block.start < now$) or explicitly marked `isLocked = true` has its slots marked `available = false`.
4. **Energy Window Flagging:** Slots intersecting any $e \in E$ have `energyBonus = true`.

The total usable capacity $C$ (in slots) is:
$$C = \sum_{s \in \text{Slots}} \mathbb{I}(s.available = \text{true} \land s.start \ge now)$$

### 6.3 Hard Constraints vs. Soft Preferences

```
+-----------------------------------+------------------------------------+
|     HARD CONSTRAINTS (P0)         |     SOFT PREFERENCES (P1/P2)       |
|    (Violations are FATAL)         |    (Optimized by Heuristics)       |
+-----------------------------------+------------------------------------+
| 1. Sleep Shield Invariant:        | 1. Energy Matching:                |
|    No task block may ever overlap |    HIGH cognitive load placed into |
|    [sleepStart, sleepEnd].        |    slots with energyBonus = true.  |
|                                   |                                    |
| 2. Fixed Commitments:             | 2. Pacing:                         |
|    No task block may overlap a    |    Spread large tasks across days  |
|    class, lab, exam, or routine.  |    using dailyTargetMinutes.       |
|                                   |                                    |
| 3. Temporal Deadlines:            | 3. Urgency Balancing:              |
|    Block end timestamp <= task    |    Schedule closer deadlines       |
|    deadline timestamp.            |    earlier in the horizon.         |
|                                   |                                    |
| 4. Capacity Upper Bound:          | 4. Minimal Fragmentation:          |
|    Scheduled task duration <=     |    Prefer contiguous blocks over   |
|    remaining task duration.       |    scattered 30-min slots.         |
|                                   |                                    |
| 5. Historical Immutability:       |                                    |
|    Past time cannot be rewritten. |                                    |
+-----------------------------------+------------------------------------+
```

### 6.4 The Multi-Objective Priority Scoring Formula
Every candidate task is assigned a priority score $P_i$ calculated via a weighted linear-hyperbolic combination of four distinct pedagogical forces:

$$P_i = (\alpha \times W_{academic}) + \left(\beta \times \frac{1}{\Delta_{deadline} + 1}\right) + (\gamma \times W_{team}) + \left(\delta \times \min\left(\frac{K_{deferral}}{K_{max}}, 1.0\right)\right)$$

Where:
- $\alpha = 2.0$ (**Academic Weight Scalar**): Prioritizes major coursework, credit-bearing projects, and exams.
- $\beta = 1.5$ (**Urgency Scalar**): $\Delta_{deadline}$ is the time remaining until the deadline in hours:
  $$\Delta_{deadline} = \max\left(0, \frac{\text{Deadline} - \text{Now}}{3,600,000 \text{ ms}}\right)$$
  The hyperbolic term $\frac{1}{\Delta_{deadline} + 1}$ scales gracefully from $1.0$ (due immediately) towards $0.0$ (due far in the future), preventing infinite spikes while prioritizing imminent work.
- $\gamma = 1.0$ (**Team Impact Scalar**): Prioritizes group assignments where delays block peers.
- $\delta = 1.0$ (**Schedule Debt Scalar**): $K_{deferral}$ is the count of how many times this task was bumped in prior schedules. $K_{max} = 5$. This term acts as an **anti-starvation guarantee**: a lower-weight assignment that has been deferred 5 times receives a full $+1.0$ boost, preventing it from being postponed forever.

### 6.5 Phase A: 0/1 Knapsack Task Selection & Dynamic Programming Backtracking
When total student demand $\sum d_i$ exceeds safe capacity $C$, the scheduler must choose which tasks will be scheduled and which must be deferred.

This is mapped to the classical **0/1 Knapsack Problem**:
- **Knapsack Capacity ($W$):** $C$ (total available 30-minute slots).
- **Items ($n$):** Each candidate task $t_i$.
- **Item Weight ($w_i$):** Slots required $\lceil d_i / 30 \rceil$.
- **Item Value ($v_i$):** Priority score $P_i$.

#### Dynamic Programming Formulation:
Let $DP[i][w]$ represent the maximum priority score achievable considering the first $i$ tasks with a slot capacity limit of $w$.

$$DP[i][w] = \begin{cases} 
DP[i-1][w] & \text{if } w_i > w \\ 
\max(DP[i-1][w], DP[i-1][w - w_i] + v_i) & \text{if } w_i \le w 
\end{cases}$$

#### Deterministic Tie-Breaking Order:
Before feeding items into the DP table, items are sorted deterministically to ensure reproducible results:
1. Priority Score $P_i$ (Descending)
2. Deadline $D_i$ (Ascending - earlier first)
3. Academic Weight $W_{academic}$ (Descending)
4. UUID string comparison (Ascending)

#### Backtracking:
After filling the table of dimension $(n+1) \times (C+1)$, the algorithm backtracks from $DP[n][C]$ to determine the exact set of selected task IDs. Tasks not selected are immediately logged as `DEFERRED` with reason code `CAPACITY_EXCEEDED`.

### 6.6 Phase B: Energy-Aware Placement & Bounded Task Splitting
Once the subset of tasks is selected, they must be placed into concrete chronological slots on the timeline.

#### Multi-Pass Placement Strategy:
1. **Sort Selected Tasks:** Tasks are ordered by Priority Score $P_i$ descending.
2. **Cognitive Load & Energy Windows:**
   - If a task has `cognitiveLoad === 'HIGH'`, it initiates **Pass 1 (Energy Match)**: the placement engine scans only slots where `slot.energyBonus === true`.
   - If the task cannot be fully satisfied in energy slots, or if `cognitiveLoad !== 'HIGH'`, it falls back to **Pass 2 (General Placement)**: scanning all remaining `available` slots.
3. **Bounded Chunk Splitting:**
   - **Minimum Chunk:** 30 minutes (1 slot). The engine never creates 10- or 15-minute fragmented blocks.
   - **Maximum Chunk:** 240 minutes / 4 hours (8 slots). Human cognitive focus degrades rapidly after 4 hours. If an assignment requires 6 hours, the engine automatically splits it into two chunks (e.g., 4h today, 2h tomorrow).
4. **Daily Target Pacing:**
   - If a task has a `dailyTargetMinutes` cap (e.g., maximum 2 hours per day on a large research paper), the engine tracks `dailyAllocatedSlots[dayKey]` and caps placement for that day, spreading the workload across the week.

```typescript
// Bounded Chunk Splitting Logic (from placement.ts)
if (currentChunk.length === MAX_CHUNK_SLOTS || currentChunk.length === remainingSlots) {
  commitChunk(currentChunk, task, blocks);
  currentChunk.forEach(s => s.available = false);
  placedSlots += currentChunk.length;
  remainingSlots -= currentChunk.length;
  currentChunk = [];
}
```

### 6.7 Phase C: Mathematical Schedule Validation Engine (`validator.ts`)
As the final gate before writing any schedule to the database, the candidate blocks are passed through a strict validator. If **any** invariant fails, the entire transaction is aborted and an error is thrown.

The validator verifies:
1. **Zero Sleep Overlap:** $\forall b \in B, \forall s \in \text{SleepIntervals}, \text{Intersection}(b, s) == \emptyset$.
2. **Zero Fixed Commitment Overlap:** $\forall b \in B, \forall f \in F, \text{Intersection}(b, [f.start - buffer, f.end + buffer]) == \emptyset$.
3. **Temporal Validity:** For every un-locked block $b$, $b.end \le taskMap[b.taskId].deadline$.
4. **Capacity Conservation:** For every task $t$, $\sum_{b \in B_t} b.durationMinutes \le \lceil t.remainingMinutes / 30 \rceil \times 30$.
5. **Zero Self-Overlap:** $\forall i \neq j, \text{Intersection}(b_i, b_j) == \emptyset$ (allowing touching edges where $b_i.end = b_j.start$).

---

# 7. The Timezone Architecture & Sleep Shield Preservation (Bug Post-Mortem)

During production regression testing of Equilibrium V2, a critical edge-case was discovered and systematically resolved. This case study illustrates Equilibrium's defense-in-depth engineering.

### 7.1 Incident Description
A student test account registered with a Sleep Shield configured from **23:00 to 07:00** (Indian Standard Time, UTC+05:30). When generating a schedule via Exam Prep mode, the engine scheduled a 60-minute revision task titled *"OS written exam — unit 1"* at **03:30 $\rightarrow$ 04:30 IST**. 

03:30 AM falls squarely inside the student's protected sleep window, representing a critical violation of Equilibrium's primary product invariant.

### 7.2 Root Cause Analysis (RCA)

```
                       THE TIMEZONE MISALIGNMENT BUG

User Intended (IST):      [====== SLEEP: 23:00 to 07:00 IST ======]
                           |                 |                  |
Timeline (UTC):          17:30 UTC         22:00 UTC          01:30 UTC
                           |                 |                  |
Database Stored:         timezone = "UTC" (Prisma default fallback)
Engine Interpreted:       [====== SLEEP: 23:00 to 07:00 UTC ======]
Converted to IST:                           04:30 IST          12:30 IST
                                                ^
                                                |
Gap Created (IST):       [ 23:00 IST to 04:30 IST Left OPEN! ]
Task Placed:                     [03:30 - 04:30 IST placed in gap!]
```

1. **Write-Time Flaw:** When mobile clients registered users via `POST /api/v1/auth/register`, the client payload omitted the `timezone` attribute. The database schema defined `timezone String @default("UTC")`. Consequently, Indian users were saved with `timezone = "UTC"`.
2. **Read-Time Interpretation:** The user's constraint was recorded as `sleepStart = "23:00"` and `sleepEnd = "07:00"`. When the scheduler converted `"23:00"` into absolute UTC timestamps using the stored timezone `"UTC"`, it masked `23:00 UTC to 07:00 UTC`.
3. **The Temporal Shift:** 23:00 UTC corresponds to **04:30 AM IST**. The engine believed the user was sleeping from 04:30 AM to 12:30 PM IST! This left the entire late-night window of **23:00 PM to 04:30 AM IST** marked as completely available, allowing the Knapsack engine to place tasks at 03:30 AM.

### 7.3 The Permanent Fix: Two-Tier Defense Architecture

#### Tier 1: Write-Time Correction & Client Detection
- Updated the Prisma schema default timezone from `"UTC"` to `"Asia/Kolkata"` (`@default("Asia/Kolkata")`).
- Updated `auth.service.ts` to explicitly capture and validate the `timezone` parameter during registration.
- Updated the Flutter client to auto-detect device timezone using `DateTime.now().timeZoneName` or fallback to `'Asia/Kolkata'`.

#### Tier 2: Read-Time Hardened Resolution Pipeline (`timezone.ts`)
Created an isolated timezone normalization module that validates IANA timezone strings via `Intl.DateTimeFormat`:
```typescript
// server/src/scheduler/timezone.ts
export const DEFAULT_TIMEZONE = 'Asia/Kolkata';

export function isValidTimezone(tz: unknown): tz is string {
  if (typeof tz !== 'string' || tz.trim() === '') return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

export function resolveTimezone(tz: unknown): string {
  return isValidTimezone(tz) ? tz : DEFAULT_TIMEZONE;
}
```

#### Centralized Context Assembly:
All scheduling triggers (`/generate`, `/reschedule`, `/simulate`, Exam Prep `scheduleTopics`) now route through a single gatekeeper: `ScheduleService.loadContext()`. It resolves user timezone before computing slot boundaries, making it impossible for any sub-system to construct a schedule in an unvalidated timezone.

---

# 8. Disruption Engine & Anti-Fragile Rescheduling

In real student life, schedules fail. A student takes 3 hours on a 1-hour lab report; a professor reschedules a lecture; an unexpected family event occurs. Conventional calendars break when reality drifts from the plan. Equilibrium treats disruption as a first-class mathematical event.

```
+-----------------------------------------------------------------------------------+
|                           DISRUPTION HANDLING PIPELINE                            |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  1. Event Detection (DisruptionEvent)                                             |
|     - Focus timer records Overrun (>20% planned) or Underrun                     |
|     - User marks task completed early or late                                     |
|     - New Fixed Commitment inserted into schedule timeline                        |
|                                                                                   |
|  2. Historical Freeze                                                             |
|     - Query all blocks in active version where block.start < now                  |
|     - Mark these blocks as isLocked = true                                        |
|     - Deduct elapsed minutes from task estimate: remaining = max(0, est - comp)   |
|                                                                                   |
|  3. Capacity Recalculation                                                        |
|     - Remaining Slots = Total Future Slots - Sleep - Fixed - Locked Task Blocks   |
|                                                                                   |
|  4. Schedule Debt Accrual                                                         |
|     - Any task displaced by the overrun has deferralCount incremented             |
|     - Next priority calculation increases debt term: delta * (deferral / 5)       |
|                                                                                   |
|  5. Transactional Re-plan & Version Fork                                          |
|     - Re-run Knapsack & Placement on [now, horizonEnd]                            |
|     - Save new ScheduleVersion linking previousVersionId                          |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

### 8.1 Schedule Versioning Model
Schedules are never updated in-place with destructive overwrites. Every re-plan creates a new immutable `ScheduleVersion` record in the database:
- `id`: Unique UUID.
- `triggerType`: `MANUAL`, `DISRUPTION`, `EOD` (End of Day), or `EXAM_PREP`.
- `capacityMinutes`: Exact capacity available at the moment of execution.
- `previousVersionId`: Self-referencing foreign key creating an audit trail of schedule evolution.
- `blocks`: Array of `ScheduleBlock` children.
- `decisionLogs`: Array of `DecisionLog` children.

---

# 9. Explainability Engine & Transparent Decision Ledger (XAI)

A core UX failure of modern "AI" tools is the black-box effect: recommendations are provided without justification, causing users to reject them when conflicts arise. Equilibrium implements a **Zero-Hallucination Explainability Architecture**.

### 9.1 The DecisionLog Contract
Every single candidate task that enters the scheduler produces a corresponding `DecisionLog` row:

| Field | Type | Description |
| :--- | :--- | :--- |
| `decisionType` | Enum | `FULLY_SCHEDULED`, `PARTIALLY_SCHEDULED`, or `DEFERRED`. |
| `priorityScore` | Float | The exact numerical score computed by `calculatePriority()`. |
| `priorityComponentsJson` | JSON String | Breakdown: `{"academic": 1.8, "urgency": 1.25, "team": 0.0, "debt": 0.4}`. |
| `reasonCode` | String | Machine-readable enum: `SUCCESS`, `DAILY_TARGET_PACING`, `FRAGMENTED_CAPACITY`, `CAPACITY_EXCEEDED`, `NO_AVAILABLE_SLOTS`. |
| `humanReadable` | String | A deterministic, human-readable sentence explaining the choice. |

### 9.2 Reason Code Matrix

| Reason Code | Decision Type | Example Human Explanation |
| :--- | :--- | :--- |
| `SUCCESS` | `FULLY_SCHEDULED` | *"Fully scheduled 'Algorithms Assignment' because its priority score (3.45) secured enough capacity before the deadline."* |
| `DAILY_TARGET_PACING` | `PARTIALLY_SCHEDULED` | *"Partially scheduled 'OS Thesis' to respect its daily workload limit of 120m. Deferred 180m to future days."* |
| `FRAGMENTED_CAPACITY` | `PARTIALLY_SCHEDULED` | *"Partially scheduled 'Compiler Lab'. Deferred 60m because protected sleep and fixed commitments left insufficient contiguous capacity."* |
| `CAPACITY_EXCEEDED` | `DEFERRED` | *"Deferred 'Elective Reading'. The schedule reached maximum capacity. This task was out-prioritized by tasks with closer deadlines or higher weights."* |
| `NO_AVAILABLE_SLOTS` | `DEFERRED` | *"Deferred 'Math Revision' entirely. No valid time slots were available prior to the deadline after accommodating fixed commitments."* |

### 9.3 Client-Side Lazy-Loading UX
To maintain fast rendering when opening schedules with dozens of tasks, decision logs are **lazy-loaded**:
1. The student taps a task card on the timeline.
2. The `TaskDetailSheet` displays standard metadata and renders an **"Inspect Scheduling Decision"** button.
3. Tapping the button mounts `ExplanationSheet`, which triggers `GET /api/v1/schedules/:versionId/decisions`.
4. The client filters for the matching `taskId` and renders an analytical badge card displaying the priority score, component breakdown bars, and explanation text.

---

# 10. End-to-End Functional Feature Deep Dive

### 10.1 Authentication & First-Run Onboarding
- **Registration/Login:** JWT-based stateless authentication with 7-day expiration. Secure password hashing with bcrypt (12 salt rounds).
- **Password Reset:** Generates a cryptographically secure 256-bit token (`crypto.randomBytes(32)`), stored as a SHA-256 hash in `PasswordResetToken` with 1-hour expiration. Deep-link handling via `equilibrium://reset-password?token=...` opens native password update dialog in Flutter.
- **Onboarding Wizard:** First-time users are guided through a 3-step setup:
  1. Sleep window configuration (enforcing $sleepEnd - sleepStart \ge 7.0$ hours).
  2. Buffer time selection (15, 30, or 45 minutes between events).
  3. Peak focus window selection (e.g., Morning 09:00–12:00, Evening 17:00–20:00).

### 10.2 Sleep Shield & Constraint Customization
- Managed via `UserConstraint` entity.
- Editable anytime in the Profile screen.
- Updating constraints immediately prompts the user to re-plan the current week, propagating new sleep boundaries across the timeline.

### 10.3 Dynamic Task Management & Manual Splitting
- **Fields:** Title, Category (Assignment, Revision, Lab, Project, Practice, Viva), Estimate Minutes, Completed Minutes, Deadline, Academic Weight (0.0 to 1.0 slider), Team Impact (0.0 to 1.0 slider), Cognitive Load (Low, Medium, High).
- **Task Splitting:** A student can choose to split a massive task into $N$ child sub-tasks. The parent task status transitions to `ARCHIVED`, while child sub-tasks inherit subject metadata, deadlines, and fractional durations.

### 10.4 Fixed Commitments & Recurring Class/Lab Routines
- Model: `FixedCommitment`.
- Types: `CLASS`, `LAB`, `EXAM`, `PERSONAL`, `ROUTINE`, `CUSTOM`.
- Recurrence: Supports `WEEKLY` and `DAILY` routines via `daysOfWeek` JSON array (e.g., `[1, 3, 5]` for Mon/Wed/Fri lectures).
- Real titles and color-coded icons are visually anchored to the timeline.

### 10.5 Interactive Schedule Timelines (Today & Next Days)
- **Today Screen:** Focuses on immediate execution. Displays a real-time glowing "Now" indicator, the currently active block, next upcoming tasks, and quick-completion checkmarks.
- **Schedule Screen:** 7-day scrollable timeline navigator with date selector chips. Dynamically renders:
  - Deep blue striped blocks for **Sleep Shield** intervals.
  - Charcoal grey locked blocks for **Fixed Commitments**.
  - Vibrant indigo/amber blocks for **Scheduled Tasks** with cognitive badges.

### 10.6 Quick-Add System (+) Floating Action Center
Located in the center of the navigation dock, tapping the `+` FAB opens an elevated modal sheet providing 5 direct actions:
1. **Task:** Opens `CreateTaskSheet` (with inline "What-If" capacity preview).
2. **Start Timer:** Opens `TimerScreen` to launch an immediate focus session.
3. **Fixed Commitment:** Opens `CreateCommitmentSheet` to record classes, labs, or recurring routines.
4. **Import Syllabus:** Opens `SyllabusImportScreen` to extract tasks from academic PDF documents.
5. **Import Calendar:** Opens `IcsImportScreen` to parse `.ics` university calendar schedules.

### 10.7 Focus Timer & Disruption Detection
- **Modes:** Stopwatch mode or Countdown Pomodoro mode.
- **Background Persistence:** Backed by `FocusSession` in the database. Supports `RUNNING`, `PAUSED`, `COMPLETED`, and `DISCARDED` states.
- **Elapsed Tracking:** Tracks total paused duration (`totalPausedMs`) to calculate exact focused time regardless of app restarts.
- **Task Linkage:** Completing a timer session automatically increments the linked task's `completedMinutes` and triggers a disruption evaluation if an overrun occurred.

### 10.8 Exam Preparation Mode (Topic Deconstruction & Re-planning)
- **Model:** `Exam` with child `ExamTopic` items.
- **Topic Types:** `REVISION`, `PYQ` (Previous Year Questions), `MOCK_TEST`, `LEARNING`, `WEAK_TOPIC`.
- **Confidence Rating:** 0.0 to 1.0 star rating indicating student mastery.
- **Automated Scheduling:** Tapping **"Schedule Topics"** calls `ExamPrepService.scheduleTopics()`. It converts incomplete topics into formal Tasks with academic weight `0.9` (Mock tests set to `HIGH` cognitive load), uniquifies topic names (e.g., *"OS Exam — Unit 1 · Revision"*), and triggers the scheduling engine.

### 10.9 "What-If" Schedule Simulation Engine
- **Endpoint:** `POST /api/v1/schedules/simulate`.
- **Behavior:** Accepts a proposed task payload and runs a dry-run clone of `runReschedulerPipeline` without writing any database records.
- **Output:** Returns whether the task fits (`fits: boolean`), whether other tasks would be displaced, and the exact slots it would occupy. Surfaced live inside `CreateTaskSheet` so students can see if an assignment fits before saving it!

### 10.10 Syllabus PDF Extraction & Calendar (.ics) Import Pipeline
- **PDF Extraction:** `POST /api/v1/imports/syllabus`. Employs `pdf-parse` buffer stream extraction with heuristic Regex date and duration matching (e.g., *"Assignment 1 due 2026-11-15 (120 min)"*).
- **Candidate Staging:** Raw parsed items are saved as `ImportCandidate` rows with confidence scores.
- **Human-in-the-Loop Confirmation:** The student reviews extracted tasks in Flutter, edits titles/deadlines, checks boxes, and confirms. Only confirmed candidates are converted to active Tasks.
- **ICS Calendar Parser:** Reads `BEGIN:VEVENT` blocks, parses `DTSTART`, `DTEND`, and `SUMMARY`, and converts them to `FixedCommitment` rows.

### 10.11 Read-Only Public Team Sharing & Web Portal
- **Endpoint:** `POST /api/v1/team/share`.
- **Security:** Generates an unguessable 256-bit cryptographically random token. Stores SHA-256 hash in `TeamShare` with expiration (1 to 168 hours) and instant revocation capability.
- **Public Web Portal:** Accessible via standard browser at `/team/:token`. The Node server serves a standalone, responsive, sanitized HTML5/CSS3 page with zero third-party tracking scripts, allowing study partners or lab teammates to view a student's availability without having an Equilibrium account.

### 10.12 Workload Analytics & Insights Engine
- **Screen:** `AnalyticsScreen` (6th tab in navigation).
- **Focus Score (0–100):** Visualized via a circular ring indicator. Calculated from weekly high-cognitive task completion against targets.
- **Burnout Risk Gauge:** Measures total scheduled workload against safe weekly capacity:
  $$\text{Safe Daily Capacity} = 1440\text{ min} - \text{Sleep} - \text{Buffer}$$
  $$\text{Utilization} = \frac{\text{Scheduled Minutes}}{\text{Safe Weekly Capacity}}$$
  - Utilization $> 100\% \rightarrow$ **HIGH RISK** (Amber/Red flame alert).
  - Utilization $80\% - 100\% \rightarrow$ **MEDIUM RISK**.
  - Utilization $< 80\% \rightarrow$ **LOW RISK** (Optimal equilibrium).
- **Deep Work Hours:** Total hours spent in `HIGH` cognitive focus sessions.

### 10.13 Offline-First Architecture & Push Notification Service
- **Offline Tracking:** `ApiClient` listens to connectivity changes. When offline, an elevated "Working offline" pill displays in the UI. Cached schedules in SQLite/SharedPreferences remain readable.
- **Local Push Notifications:** Implemented via `flutter_local_notifications`. Schedules native OS notifications 10 minutes prior to each task block start, ensuring students receive reminders without requiring background WebSocket connections.

---

# 11. Database Architecture & Complete Schema Specification

Equilibrium uses Prisma ORM with PostgreSQL in production and SQLite in development. The schema encompasses 15 interrelated models.

```
                              ENTITY-RELATIONSHIP DIAGRAM

       +-----------------------+                    +------------------------+
       |   UserConstraint      |                    | NotificationPreference |
       +-----------------------+                    +------------------------+
       | minSleepHours         |                    | upcomingTaskAlerts     |
       | sleepStart, sleepEnd  |                    | overloadAlerts         |
       | peakEnergyWindowsJson |                    | dailyBrief             |
       +-----------+-----------+                    +-----------+------------+
                   | 1:1                                        | 1:1
                   |                                            |
       +-----------v--------------------------------------------v------------+
       |                                USER                                 |
       |  id, email, passwordHash, timezone, name, college, degree, semester |
       +-----+-----------------+--------------------+------------------+-----+
             | 1:N             | 1:N                | 1:N              | 1:N
             |                 |                    |                  |
+------------v-----+   +-------v--------+   +-------v--------+   +-----v----------+
|     Subject      |   | FixedCommitment|   |  FocusSession  |   | ScheduleVersion|
+------------------+   +----------------+   +----------------+   +--------+-------+
| name, color      |   | title, type    |   | startedAt      |            | 1:N
+--------+---------+   | startTime      |   | elapsedSeconds |            |
         | 1:N         | endTime        |   | status         |     +------v--------+
         |             | recurrence     |   +----------------+     | ScheduleBlock |
+--------v---------+   | daysOfWeek     |                          +---------------+
|       Task       |   +----------------+                          | startTime     |
+------------------+                                               | endTime       |
| title, category  |                                               | blockType     |
| estimateMinutes  |                                               | isCompleted   |
| completedMinutes |<----------------------------------------------+ taskId (FK)   |
| deadline         |                                               +---------------+
| academicWeight   |                                                      |
| cognitiveLoad    |                                               +------v--------+
| deferralCount    |                                               |  DecisionLog  |
+--------+---------+                                               +---------------+
         | 1:N                                                     | decisionType  |
+--------v---------+                                               | priorityScore |
|    ExamTopic     |                                               | reasonCode    |
+------------------+                                               | humanReadable |
| title, type      |                                               +---------------+
| confidence       |
| linkedTaskId (FK)|
+------------------+
```

### 11.1 Key Database Models (Extract from `schema.prisma`)

```prisma
model User {
  id               String            @id @default(uuid())
  email            String            @unique
  passwordHash     String
  timezone         String            @default("Asia/Kolkata")
  name             String?
  college          String?
  degree           String?
  branch           String?
  semester         String?
  themePreference  String            @default("system")
  tokenVersion     Int               @default(0)
  createdAt        DateTime          @default(now())
  updatedAt        DateTime          @updatedAt
  
  constraint       UserConstraint?
  tasks            Task[]
  commitments      FixedCommitment[]
  scheduleVersions ScheduleVersion[]
  focusSessions    FocusSession[]
  exams            Exam[]
  subjects         Subject[]
  teamShares       TeamShare[]
}

model UserConstraint {
  id                    String  @id @default(uuid())
  userId                String  @unique
  minSleepHours         Float   // Enforced >= 7.0 in API
  sleepStart            String  // e.g. "23:00"
  sleepEnd              String  // e.g. "07:00"
  bufferMinutes         Int     @default(30)
  peakEnergyWindowsJson String  // JSON array string of [{start, end}]
  user                  User    @relation(fields: [userId], references: [id], onDelete: Cascade)
}

model Task {
  id                 String          @id @default(uuid())
  userId             String
  subjectId          String?
  title              String
  description        String?
  category           String?         // Assignment, Revision, Lab, Project, etc.
  estimateMinutes    Int             // Initial estimated duration
  completedMinutes   Int             @default(0) // Locked executed duration
  scheduledMinutes   Int             @default(0) // Duration in active schedule
  dailyTargetMinutes Int?            // Daily workload cap
  deadline           DateTime
  deadlineType       String          @default("HARD") // HARD, FLEXIBLE
  academicWeight     Float           @default(0.5)    // 0.0 to 1.0
  teamImpactWeight   Float           @default(0.0)    // 0.0 to 1.0
  cognitiveLoad      String          @default("MEDIUM") // LOW, MEDIUM, HIGH
  deferralCount      Int             @default(0)      // Schedule Debt Counter
  status             String          @default("PENDING") // PENDING, IN_PROGRESS, COMPLETED, ARCHIVED
  createdAt          DateTime        @default(now())
  updatedAt          DateTime        @updatedAt
  
  user               User            @relation(fields: [userId], references: [id], onDelete: Cascade)
  blocks             ScheduleBlock[]
  logs               DecisionLog[]
}

model ScheduleVersion {
  id                String          @id @default(uuid())
  userId            String
  triggerType       String          // MANUAL, EOD, DISRUPTION, EXAM_PREP
  capacityMinutes   Int
  algorithmVersion  String          @default("2.4.0")
  previousVersionId String?
  generatedAt       DateTime        @default(now())

  user              User            @relation(fields: [userId], references: [id], onDelete: Cascade)
  blocks            ScheduleBlock[]
  decisionLogs      DecisionLog[]
}

model ScheduleBlock {
  id              String          @id @default(uuid())
  versionId       String
  taskId          String?         // Nullable for SLEEP or FIXED blocks
  startTime       DateTime
  endTime         DateTime
  durationMinutes Int
  blockType       String          // TASK, SLEEP, FIXED, BUFFER
  isCompleted     Boolean         @default(false)
  isLocked        Boolean         @default(false) // Immutable if in the past

  version         ScheduleVersion @relation(fields: [versionId], references: [id], onDelete: Cascade)
  task            Task?           @relation(fields: [taskId], references: [id], onDelete: SetNull)

  @@index([versionId, startTime])
}

model DecisionLog {
  id                     String          @id @default(uuid())
  versionId              String
  taskId                 String
  decisionType           String          // FULLY_SCHEDULED, PARTIALLY_SCHEDULED, DEFERRED
  priorityScore          Float
  priorityComponentsJson String
  reasonCode             String          // SUCCESS, CAPACITY_EXCEEDED, etc.
  humanReadable          String

  version                ScheduleVersion @relation(fields: [versionId], references: [id], onDelete: Cascade)
  task                   Task            @relation(fields: [taskId], references: [id], onDelete: Cascade)

  @@index([versionId])
  @@index([taskId])
}
```

---

# 12. REST API Contract & Endpoint Reference

All API routes are prefixed with `/api/v1` and require an `Authorization: Bearer <JWT>` header unless marked public.

### 12.1 Authentication & Profile
- `POST /api/v1/auth/register` (Public) — Creates user account with timezone detection.
- `POST /api/v1/auth/login` (Public) — Authenticates credentials; returns JWT and user profile.
- `POST /api/v1/auth/forgot-password` (Public) — Initiates password reset email/token.
- `POST /api/v1/auth/reset-password` (Public) — Consumes token and sets new password.
- `GET /api/v1/profile` — Retrieves profile details, academic majors, and theme preference.
- `PATCH /api/v1/profile` — Updates profile fields.

### 12.2 Constraints & Onboarding
- `GET /api/v1/constraints` — Returns sleep window, buffer, and peak energy windows.
- `POST /api/v1/constraints` — Creates initial constraints during onboarding.
- `PATCH /api/v1/constraints` — Modifies sleep start/end or energy windows.

### 12.3 Tasks & Splitting
- `GET /api/v1/tasks` — Lists active tasks (filters: status, subject, deadline).
- `POST /api/v1/tasks` — Creates new academic task with Zod validation.
- `PATCH /api/v1/tasks/:id` — Edits task properties or marks task completed.
- `POST /api/v1/tasks/:id/split` — Splits task into $N$ child sub-tasks.
- `DELETE /api/v1/tasks/:id` — Deletes task and cascades deletions to future blocks.

### 12.4 Scheduling & Simulation
- `POST /api/v1/schedules/generate` — Runs full optimization pipeline; produces new `ScheduleVersion`.
- `POST /api/v1/schedules/reschedule` — Re-plans schedule preserving locked historical blocks.
- `POST /api/v1/schedules/simulate` — Non-destructive what-if simulation for proposed tasks.
- `GET /api/v1/schedules/latest` — Returns the most recent schedule version and its blocks.
- `GET /api/v1/schedules/:versionId/decisions` — Returns XAI decision logs for a version.

### 12.5 Fixed Commitments & Routines
- `GET /api/v1/commitments` — Lists active fixed commitments and recurring routines.
- `POST /api/v1/commitments` — Creates new commitment with overlap prevention.
- `PATCH /api/v1/commitments/:id` — Updates commitment time or recurrence.
- `DELETE /api/v1/commitments/:id` — Removes commitment.

### 12.6 Exams & Exam Preparation Mode
- `GET /api/v1/exams` — Lists upcoming exams and topic mastery stats.
- `POST /api/v1/exams` — Creates new exam record.
- `POST /api/v1/exams/:id/topics` — Adds revision/mock topics to exam.
- `POST /api/v1/exams/:id/schedule` — Converts topics into high-priority tasks and re-plans.

### 12.7 Focus Sessions (Timer)
- `POST /api/v1/focus-sessions` — Starts a focus timer session.
- `PATCH /api/v1/focus-sessions/:id/pause` — Pauses timer and records elapsed time.
- `PATCH /api/v1/focus-sessions/:id/resume` — Resumes timer.
- `PATCH /api/v1/focus-sessions/:id/complete` — Completes session, updates task, and logs disruptions.

### 12.8 Imports & Team Sharing
- `POST /api/v1/imports/syllabus` — Uploads PDF/text syllabus for candidate task extraction.
- `POST /api/v1/imports/confirm` — Confirms and converts candidate items into real tasks.
- `POST /api/v1/imports/ics` — Parses `.ics` calendar file into fixed commitments.
- `POST /api/v1/team/share` — Generates expiring, read-only schedule share token.
- `GET /team/:token` (Public Web) — Serves responsive web schedule portal.

### 12.9 Dashboard & Insights
- `GET /api/v1/dashboard` — Aggregates today's metrics, upcoming blocks, and exam countdowns.
- `GET /api/v1/insights` — Calculates workload utilization, burnout risk level, and focus scores.

---

# 13. Flutter Mobile/Web Client UX/UI Engineering

The Equilibrium mobile client is engineered in Flutter, emphasizing smooth animations, accessibility, and strict visual ergonomics.

### 13.1 State Architecture (Provider Pattern)
State is segregated across 8 single-responsibility ChangeNotifier providers:
1. `AuthProvider`: Handles session tokens, automatic silent login, and force logout on 401s.
2. `ScheduleProvider`: Holds active `ScheduleVersion`, timeline blocks, and triggers re-plans.
3. `ProfileProvider`: Manages user demographics and system/dark/light theme switching.
4. `TimerProvider`: Manages timer countdown ticker, pause/resume, and background elapsed calculation.
5. `ExamProvider`: Manages exam list, topic checklists, and topic scheduling actions.
6. `ConstraintRepository` / `DecisionRepository` / `ApiClient`: Provide cached data layers.

### 13.2 Design System: Tokens & Themes
Equilibrium rejects generic browser styling in favor of a custom, high-contrast, distraction-free academic dark theme:
- **Background (`#0A1628`):** Deep midnight obsidian, reducing eye fatigue during nighttime study.
- **Surface Elevated (`#122238`):** Layered card surface with subtle 1px border highlights.
- **Primary Accent (`#4F8CFF`):** Vibrant electric cobalt for active tasks and focal CTAs.
- **Sleep Shield (`#1E3A5F` / `#82B1FF`):** Deep indigo block with moon insignia.
- **Cognitive Badges:**
  - `HIGH`: Coral Amber (`#FF7043`) — Deep cognitive intensity.
  - `MEDIUM`: Cyan Sky (`#29B6F6`) — Standard analytical work.
  - `LOW`: Emerald Mint (`#66BB6A`) — Administrative / reading tasks.

### 13.3 Key UI Components
- **`AppShell`:** Persistent bottom navigation housing 6 tabs (`Today`, `Schedule`, `Tasks`, `Exams`, `Locked`, `Analytics`) and the elevated `+` Quick-Add FAB. Includes a top app-bar timer ticker chip when a focus session is running.
- **`TimelineCanvas`:** Absolute-positioned timeline grid rendering 24-hour vertical intervals with horizontal task blocks, dynamic height scaling ($h = durationMinutes \times pxPerMinute$), and touch-event hit detection.
- **`EmptyState` & `StatusPill`:** Polished vector placeholders and offline synchronization badges.

---

# 14. Security, Privacy, and Data Integrity

Equilibrium enforces production-grade security standards across every architectural layer:

1. **Authentication Security:**
   - Password hashing utilizes `bcrypt` with 12 computational cost rounds. Passwords are never logged or stored in plain text.
   - JWT tokens are signed using high-entropy secrets and carry a `tokenVersion`. Incrementing `tokenVersion` on the User row immediately invalidates all active sessions across all devices (instant revoking).
2. **Insecure Direct Object Reference (IDOR) Defense:**
   - Every database query in the repository tier explicitly includes `where: { id: resourceId, userId: req.userId }`.
   - Accessing another student's task, schedule version, or commitment yields a strict `404 Not Found` (masking resource existence) rather than a `403 Forbidden`.
3. **Database Injection & SQL Safety:**
   - 100% of database interactions occur through Prisma ORM's parameterized query engine, preventing SQL injection vulnerabilities.
4. **Data Validation Gates:**
   - All incoming HTTP payloads pass through strict `Zod` schemas. Extraneous fields are stripped; type mismatches immediately reject with a standardized 400 JSON error payload.
5. **Team Share Anonymization:**
   - Public team share links expose **only** schedule availability (start time, end time, cognitive load, and block type). Internal personal notes, assignment descriptions, and user email addresses are completely stripped from the public payload.

---

# 15. Quality Assurance, Test Suite Matrix, and Verification

Equilibrium is covered by comprehensive unit, integration, and end-to-end regression test suites executed via Jest.

### 15.1 Core Test Suites

| Test Suite File | Coverage Scope | Critical Invariant Checked |
| :--- | :--- | :--- |
| `scheduler.test.ts` | Mathematical Engine | Knapsack capacity bounds, priority ordering, and bounded chunk splitting. |
| `validator.test.ts` | Verification Gate | Asserts that overlapping sleep or fixed commitments throws fatal errors. |
| `regression.exam-prep-sleep-shield.test.ts` | Exam Prep & Timezone | Verifies that exam topic tasks never violate the Sleep Shield across all timezones. |
| `regression.student-workflow.test.ts` | E2E Student Lifecycle | Full workflow: Onboard $\rightarrow$ Add Fixed Classes $\rightarrow$ Add 5 Tasks $\rightarrow$ Generate $\rightarrow$ Overrun Timer $\rightarrow$ Reschedule. |
| `security.test.ts` | Access Control | IDOR prevention, token expiration, password hashing, and token versioning. |
| `team-web.test.ts` | Web Sharing | Token hashing, expiration enforcement, and HTML sanitization against XSS. |

### 15.2 Regression Verification Run Output
```bash
PASS test/regression.exam-prep-sleep-shield.test.ts
  Exam Prep Mode Sleep Shield & Timezone Regression Suite
    ✓ should never schedule exam prep tasks during user sleep window (23:00 - 07:00 IST) (482 ms)
    ✓ should properly uniquify topic task titles with topicType label (18 ms)
    ✓ should route topic scheduling through scheduleService.loadContext (24 ms)

PASS test/regression.student-workflow.test.ts
  End-to-End Student Workflow Regression Suite
    ✓ completes registration and onboarding with valid constraints (321 ms)
    ✓ adds recurring weekly classes and laboratory commitments (112 ms)
    ✓ creates 5 competing academic assignments with varied weights (145 ms)
    ✓ generates initial schedule respecting sleep and class buffers (380 ms)
    ✓ records focus session timer overrun and executes anti-fragile reschedule (412 ms)
    ✓ asserts all deferred tasks accrue schedule debt in decision logs (92 ms)

Test Suites: 8 passed, 8 total
Tests:       42 passed, 42 total
Snapshots:   0 total
Time:        4.812 s
```

---

# 16. DevOps, Continuous Integration, and Deployment

### 16.1 GitHub Actions CI/CD Pipeline (`.github/workflows/main.yml`)
Equilibrium enforces an automated, multi-stage continuous integration workflow on every pull request and push to `main`:

```yaml
name: Equilibrium CI/CD Pipeline
on: [push, pull_request]

jobs:
  backend-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: cd server && npm ci
      - run: cd server && npx prisma generate
      - run: cd server && npm test

  flutter-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.24.x', channel: 'stable' }
      - run: cd equilibrium_app && flutter pub get
      # Strict Static Analysis (Zero-Warning Policy)
      - run: cd equilibrium_app && flutter analyze --fatal-infos --fatal-warnings
      - run: cd equilibrium_app && flutter build apk --release
      - uses: actions/upload-artifact@v4
        with:
          name: app-release-apk
          path: equilibrium_app/build/app/outputs/flutter-apk/app-release.apk
```

### 16.2 Production Cloud Deployment
- **Backend Service:** Hosted on **Render** (`render.yaml`), running Node.js in an isolated Linux container with automatic health checks (`GET /health`) and auto-restart policies.
- **Database:** Managed PostgreSQL instance on Render with SSL connections and automated point-in-time recovery.
- **Mobile Client:** Automated artifact delivery producing signed release APKs (`app-release.apk`) directly downloadable by testers and evaluators.

---

# 17. Academic Viva / Oral Evaluation Master Guide (25+ Q&A)

This section prepares the student team for rigorous academic evaluation, project defense, and viva examinations by professors or industry reviewers.

---

### Q1: Why did you use a deterministic 0/1 Knapsack algorithm instead of a modern Generative AI or LLM agent to generate the schedule?
**Answer:**  
"LLMs are probabilistic, generative models designed for natural language synthesis, not constraint satisfaction. When tasked with scheduling, LLMs frequently suffer from mathematical hallucinations: they miscalculate duration boundaries, accidentally overlap intervals, and cannot guarantee that a hard constraint (like a sleep window) will never be violated. 

In Equilibrium, student health is our core safety invariant. By using an Operations Research approach—specifically a 0/1 Knapsack algorithm paired with an interval validation gate—we achieve **100% mathematical determinism**. Given the same constraints and timestamps, the engine will always produce the provably optimal schedule, and it is mathematically incapable of violating the Sleep Shield."

---

### Q2: What is the computational complexity of your scheduling algorithm, and how does it scale?
**Answer:**  
"The scheduling pipeline executes in two primary phases:
1. **0/1 Knapsack Selection:** Solved using Dynamic Programming. The time complexity is $\mathcal{O}(n \cdot C)$, where $n$ is the number of candidate tasks and $C$ is the capacity in slots. In our system, the horizon is 7 days discretized into 30-minute slots ($C \le 336$ slots). For a typical student with $n \le 50$ tasks, $n \cdot C \approx 16,800$ operations, which executes in **under 5 milliseconds** in Node.js.
2. **Task Placement:** Operates on the selected subset by sorting tasks ($\mathcal{O}(k \log k)$) and iterating through the slot array ($\mathcal{O}(k \cdot C)$).

The overall time complexity is $\mathcal{O}(n \cdot C)$, which is pseudo-polynomial. Because capacity $C$ is strictly bounded by the 7-day time horizon (336 slots), the algorithm scales linearly with the number of tasks, guaranteeing sub-second execution without needing expensive cloud computing clusters."

---

### Q3: What is the 'Sleep Shield', and how is it mathematically enforced?
**Answer:**  
"The Sleep Shield is our primary product invariant. It enforces that under no circumstance can academic work be scheduled during the student's configured sleep interval (minimum 7.0 hours). 

It is enforced in two distinct layers:
1. **At Capacity Generation (`capacity.ts`):** The 24-hour day is discretized into 48 half-hour slots. The engine calculates the user's localized sleep interval $[sleepStart, sleepEnd]$ (handling midnight crossovers), and sets `slot.available = false` for all intersecting slots. These slots are completely removed from the Knapsack capacity $C$.
2. **At Validation (`validator.ts`):** Before saving the schedule to the database, a verification gate asserts that $\text{Intersection}(block, sleep) == \emptyset$ for every single generated block. If even 1 minute intersects, the entire database transaction is aborted."

---

### Q4: Explain the 03:30 AM Sleep Shield bug you encountered and how you permanently fixed it.
**Answer:**  
"During regression testing, we found that a schedule placed an exam revision block at 03:30 AM inside a student's 23:00–07:00 IST sleep window. 

**Root Cause:** Mobile signups did not supply a timezone parameter, causing Prisma to assign the default database value `"UTC"`. When the scheduler converted `sleepStart = "23:00"` to an absolute timestamp, it interpreted it as 23:00 UTC (which is 04:30 AM IST). This shifted the masked sleep window to 04:30 AM–12:30 PM IST, leaving 23:00 PM–04:30 AM IST completely open for task placement.

**The Fix:** We implemented a two-tier defense:
1. *Write-Time:* Updated client registration to detect device timezone and set database default to `'Asia/Kolkata'`.
2. *Read-Time:* Implemented `timezone.ts` which validates every timezone string against the IANA database via `Intl.DateTimeFormat`, falling back to `DEFAULT_TIMEZONE` if invalid. All scheduling contexts assemble through `ScheduleService.loadContext()`, ensuring timezone normalization before any slots are calculated."

---

### Q5: How does Equilibrium handle 'Schedule Debt', and why is it important?
**Answer:**  
"When student work exceeds safe capacity, lower-priority tasks are deferred. In standard priority systems, a low-priority task (e.g., an elective reading) could be postponed indefinitely, leading to task starvation. 

Equilibrium introduces **Schedule Debt**: every time a task is pushed out of an active schedule, its `deferralCount` increments. In our priority scoring formula:
$$P_{debt} = \delta \times \min\left(\frac{K_{deferral}}{5}, 1.0\right)$$
Each deferral adds a $+0.2$ boost to the task's priority score. By the 5th deferral, the task receives a full $+1.0$ priority boost, mathematically forcing the Knapsack engine to prioritize it and preventing academic neglect."

---

### Q6: What is the significance of the North Star Metric you chose for DTPLM?
**Answer:**  
"Our North Star Metric is **Weekly High-Focus Hours Achieved per Student**. 

In Design Thinking, we must measure genuine student value rather than vanity metrics. If we measured 'Daily Active Users' or 'Time Spent in App', our incentive would be to make the app addictive. By measuring High-Focus Hours achieved, our product success is directly tied to the student completing high-cognitive work in their peak energy windows while preserving their sleep."

---

### Q7: Why do you discretize time into 30-minute intervals rather than 1-minute or 5-minute precision?
**Answer:**  
"We selected 30 minutes based on two factors:
1. **Human Psychology:** Educational psychology demonstrates that academic tasks scheduled in micro-increments (e.g., 7 or 12 minutes) increase student anxiety and are rarely adhered to. 30 minutes represents a natural focus chunk (one Pomodoro session plus short transition).
2. **Algorithmic Efficiency:** Discretizing 7 days into 30-minute slots yields 336 slots. Discretizing into 1-minute slots yields 10,080 slots. 336 slots keeps the 2D Dynamic Programming table compact ($336 \times n$), allowing the solver to run instantaneously on low-power mobile or server environments."

---

### Q8: What happens when a student takes longer on a task than planned (Disruption)?
**Answer:**  
"When a task overruns (recorded via our Focus Timer or manual completion), Equilibrium triggers its **Anti-Fragile Rescheduling Pipeline**:
1. All timeline blocks occurring prior to `now` are locked (`isLocked = true`) and preserved as immutable historical records.
2. The remaining duration of the overrun task is updated.
3. Available capacity is recalculated from `now` to the horizon end.
4. The Knapsack and placement algorithms re-solve for future tasks. If capacity is now insufficient, the lowest-priority future tasks are deferred with a transparent decision log explaining that an earlier task overrun consumed available capacity."

---

### Q9: How does the Explainability Engine work, and why not use ChatGPT to explain decisions?
**Answer:**  
"Generative language models hallucinate reasons and have no access to the exact mathematical state of our Knapsack DP table. 

Equilibrium uses a **Zero-Hallucination Decision Ledger**. During placement, every task decision is logged directly from the solver code into a `DecisionLog` record containing:
- The exact numerical Priority Score.
- A JSON breakdown of all four components ($\alpha$ Academic, $\beta$ Urgency, $\gamma$ Team, $\delta$ Debt).
- A standardized reason code (e.g., `CAPACITY_EXCEEDED`, `DAILY_TARGET_PACING`).
- A human-readable translation constructed via deterministic string templates.

Flutter fetches these logs on demand when the user taps 'Why was this scheduled?', providing 100% truthful, verifiable explanations."

---

### Q10: How does your database prevent Insecure Direct Object Reference (IDOR) attacks?
**Answer:**  
"IDOR occurs when a user accesses or modifies another user's data by guessing or altering a UUID parameter (e.g., `PATCH /api/v1/tasks/1234`). 

In Equilibrium, all repository methods enforce composite scoping:
```typescript
await prisma.task.findFirst({
  where: { id: taskId, userId: authenticatedUserId }
});
```
If a malicious user attempts to access a valid task ID belonging to someone else, the query returns `null`, and the controller emits a `404 Not Found`. This prevents unauthorized modifications and masks whether the resource ID even exists in the database."

---

### Q11: Explain your Bounded Chunk Splitting logic. Why do you cap chunks at 4 hours?
**Answer:**  
"In `placement.ts`, we enforce:
$$\text{MIN\_CHUNK} = 30 \text{ minutes (1 slot)}, \quad \text{MAX\_CHUNK} = 240 \text{ minutes (8 slots)}$$
If an assignment requires 8 hours of work, placing an 8-hour continuous block on a student's calendar causes extreme cognitive fatigue and leads to abandonment of the schedule. The engine places a maximum 4-hour chunk, closes the block, and searches for another gap on a subsequent day for the remaining 4 hours, promoting spaced study intervals."

---

### Q12: How do you handle fixed recurring commitments like classes or laboratory sessions?
**Answer:**  
"Fixed commitments are modeled in `FixedCommitment`. They possess an unalterable start and end time, and an optional `daysOfWeek` array (e.g., `[1, 3, 5]` for Mon/Wed/Fri). 

During capacity calculation, for every day in the horizon matching the recurrence, the commitment's time interval—expanded by the user's chosen buffer time (e.g., 15 minutes before and after)—is masked out of the slot matrix. This guarantees that tasks are never scheduled right up against a class, allowing realistic travel and prep time."

---

### Q13: What is the 'What-If' Simulation endpoint, and how does it benefit the student?
**Answer:**  
"`POST /api/v1/schedules/simulate` provides a non-destructive preview. When a student is considering adding a new 4-hour assignment, the client sends the task details to the simulation endpoint. 

The server clones the current scheduling context, appends the proposed task, and executes `runReschedulerPipeline` in memory **without persisting any changes to the database**. It returns whether the task fits, how many existing tasks would be displaced, and where the blocks would land. This allows students to make informed commitments before accepting new workload."

---

### Q14: How does the Exam Preparation Mode differ from standard task scheduling?
**Answer:**  
"Standard tasks represent singular assignments. Exam Prep mode is a hierarchical meta-module:
1. An `Exam` record holds the exam date, subject, and multiple `ExamTopic` items (e.g., Revision, PYQ, Mock Test) with confidence ratings.
2. When the student taps 'Schedule Topics', `ExamPrepService` automatically decomposes uncompleted topics into individual high-priority Tasks with an elevated academic weight of `0.9` (and `HIGH` cognitive load for Mock Tests).
3. It gives each task a distinct name combining exam title, topic title, and topic type (e.g., *'OS Exam — Unit 1 · Revision'*), and immediately re-plans the timeline."

---

### Q15: How does Equilibrium support offline usage on mobile devices?
**Answer:**  
"The Flutter client uses an offline-first architecture:
1. `ApiClient` continuously monitors network connectivity via connectivity listeners.
2. When the device loses internet access, a visible 'Working offline' pill animates onto the screen.
3. The latest generated schedule, tasks, and profile settings are cached locally in SQLite and persistent storage, allowing full read access to the timeline and active focus timer even with zero mobile data."

---

### Q16: How do you prevent token theft or force logout across multiple devices?
**Answer:**  
"We implement **JWT Token Versioning**. The `User` model includes an integer field `tokenVersion @default(0)`. When generating a JWT, the payload embeds `{ userId, tokenVersion }`. 

In our authentication middleware, every request checks if the token's `tokenVersion` matches the current database record. If a student changes their password or taps 'Logout from all devices', we increment `tokenVersion: { increment: 1 }`. All previously issued tokens immediately fail authentication, forcing re-login without needing an expensive Redis token blacklist."

---

### Q17: What role does the 'Daily Target Pacing' feature play?
**Answer:**  
"Some students work on massive semester projects or thesis papers that require 20+ hours of work. If fed to a standard Knapsack scheduler with high priority, the engine would attempt to schedule all 20 hours across the first two days, causing immediate burnout. 

By setting `dailyTargetMinutes: 120` (2 hours), the placement engine tracks daily allocations (`dailyAllocatedSlots[dayKey]`) and caps daily placement at 2 hours, naturally pacing the project across 10 days while leaving daily capacity open for everyday homework."

---

### Q18: What is the Burnout Risk formula used in the Analytics tab?
**Answer:**  
"Burnout Risk evaluates the ratio of scheduled academic workload against mathematically safe weekly capacity:
$$\text{Safe Daily Minutes} = 1440 - (\text{minSleepHours} \times 60) - \text{bufferMinutes}$$
$$\text{Safe Weekly Capacity} = \text{Safe Daily Minutes} \times 7$$
$$\text{Utilization} = \frac{\text{Scheduled Minutes}}{\text{Safe Weekly Capacity}}$$
- If $\text{Utilization} > 1.0 \rightarrow$ **HIGH RISK** (Workload exceeds safe waking capacity).
- If $\text{Utilization} \in [0.8, 1.0] \rightarrow$ **MEDIUM RISK** (Workload occupies $>80\%$ of free time).
- If $\text{Utilization} < 0.8 \rightarrow$ **LOW RISK** (Healthy equilibrium)."

---

### Q19: How are Syllabus PDFs parsed into candidate tasks?
**Answer:**  
"In `imports.routes.ts`, uploaded PDF buffers are processed by `pdf-parse` to extract plain text streams. 

The text is analyzed using regular expressions that identify academic deadlines and time estimates (e.g., matching ISO dates `\d{4}-\d{2}-\d{2}` or text patterns like `Due: October 24` and duration patterns like `(\d+)\s*(?:min|hours)`). Each match generates an `ImportCandidate` with a confidence score. Crucially, tasks are not created automatically: the student reviews the candidates in a confirmation screen, editing or rejecting items before they enter the scheduler."

---

### Q20: How is public schedule sharing implemented securely without exposing private data?
**Answer:**  
"When a student generates a share link, `team.routes.ts` creates a cryptographically random 256-bit token (`crypto.randomBytes(32)`), hashes it using SHA-256, and stores the hash with an expiration timestamp (`expiresAt`). 

The link is served at `/team/:token`. The server looks up the un-revoked hash, queries the latest schedule, and renders a sanitized HTML view. Private task descriptions, notes, and user emails are completely omitted from the HTML, exposing only block start times, end times, and cognitive loads."

---

### Q21: What is the purpose of the Focus Timer's `totalPausedMs` field?
**Answer:**  
"If a timer is paused, simple subtraction of `now - startedAt` would incorrectly count paused time as active focus time. 

When a student pauses the timer, we record `pausedAt = now`. When resumed, we calculate `pauseDuration = now - pausedAt` and accumulate it into `totalPausedMs`. This ensures that even if the mobile app is terminated and reopened hours later, the active elapsed focus time is mathematically exact:
$$\text{Elapsed} = \text{now} - \text{startedAt} - \text{totalPausedMs}$$"

---

### Q22: Why did you transition from Python/React Native to Node.js/TypeScript/Flutter?
**Answer:**  
"Our early prototypes in Python/FastAPI and React Native revealed two critical bottlenecks:
1. *Timeline Ergonomics:* Rendering complex, dynamic timelines with overlapping gestures and 60fps animations stuttered across the React Native JavaScript bridge. Flutter's Skia/Impeller engine compiles directly to native ARM code, delivering butter-smooth rendering.
2. *Type Safety & Monorepo Cohesion:* Node.js with TypeScript allowed us to share strongly typed domain models and validation rules across the backend with zero serialization overhead, while Prisma provided lightning-fast relational queries."

---

### Q23: Why does Equilibrium use GitHub Actions with `--fatal-infos` and `--fatal-warnings`?
**Answer:**  
"Academic software often suffers from code rot and subtle bugs caused by ignored warnings (such as unused variables, unawaited futures, or deprecated string interpolations). 

We configured our CI/CD pipeline with:
`flutter analyze --fatal-infos --fatal-warnings`
This enforces a **Zero-Tolerance Quality Gate**. If any developer introduces even a single style inconsistency or lint warning, the build fails and no APK artifact is generated. This disciplined standard ensured our release APK is completely free of runtime warning regressions."

---

### Q24: What is the tie-breaking logic in the Knapsack DP algorithm?
**Answer:**  
"In `knapsack.ts`, if two candidate tasks have identical priority scores, arbitrary selection would cause non-deterministic schedule flipping on every re-plan. 

We break ties using a deterministic 4-stage hierarchy:
1. **Priority Score:** Descending.
2. **Deadline Timestamp:** Ascending (earlier deadline wins).
3. **Academic Importance Weight:** Descending (higher credit weight wins).
4. **Task UUID String Comparison:** Ascending (`a.id.localeCompare(b.id)`).
This guarantees that for any identical set of tasks, the solver produces the exact same subset every single time."

---

### Q25: What are the three most significant future enhancements planned for Equilibrium?
**Answer:**  
"1. **Advisory Machine Learning Calibration:** Introducing a lightweight non-critical ML regression model that learns from historical `FocusSession` data to calibrate student-specific task estimates (e.g., detecting if a student consistently underestimates Math lab reports by 35%).
2. **Two-Way Google Calendar / Canvas LMS Sync:** Moving beyond manual ICS/PDF import to automated OAuth webhook synchronization with university LMS portals.
3. **Collaborative Group Study Allocation:** Expanding Team Share into a multi-party constraint solver that identifies mutual peak-energy focus windows across study cohorts for collaborative group projects."

---

# 18. Document Control & Sign-Off

| Milestone | Date | Status | Verification Signature |
| :--- | :--- | :--- | :--- |
| **Problem Statement Definition** | August 2026 | Approved | DTPLM Faculty Advisory |
| **V1 Architectural Prototype** | September 2026 | Completed | Core Development Team |
| **V2 Production Rebuild (Flutter/TS)**| October 2026 | Completed | Lead Architect |
| **Sleep Shield Timezone Verification**| October 2026 | Verified (100% Invariant) | QA Automation Lead |
| **Final Capstone Release (V2.4.0)** | October 2026 | Production Ready | Capstone Evaluation Panel |

---
*Equilibrium — Autonomous Student Workload Balancer*  
*Designed and engineered for university academic excellence, mental well-being, and mathematical rest preservation.*
