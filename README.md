# Equilibrium

**Equilibrium** is an autonomous, constrained academic workload optimizer built to solve the systemic problem of student burnout. Unlike traditional reminder apps or to-do lists, Equilibrium actively manages your schedule by mathematically preventing sleep deprivation and intelligently placing high-cognitive tasks in your peak energy windows.

Built as a capstone project for **DTPLM (Design Thinking & Product Lifecycle Management)**.

---

## 🌟 Key Features

- **Sleep Shield Engine**: A hard-constraint mathematical guardrail that ensures tasks are never scheduled during your designated sleep hours. If a task doesn't fit, it is deferred rather than letting you burn out.
- **Cognitive-Aware Placement**: Uses a 0/1 Knapsack algorithm to optimize your schedule, placing tasks labeled `HIGH` cognitive load during your predefined "Peak Energy Windows."
- **Explainability Logs**: Equilibrium doesn't just give you a schedule; it explains *why* it made those decisions, showing priority weights (academic weight, urgency, team impact, deferral debt) for total transparency.
- **Resilience to Disruption**: Life happens. When a task takes longer than expected, Equilibrium reschedules the remaining work around your fixed commitments without destroying past records.
- **Syllabus & Calendar Imports**: Automatically parse PDF syllabuses and `.ics` calendar files to populate deadlines and fixed constraints.
- **Burnout Analytics**: A dynamic ledger that tracks "deferred debt" and calculates safe capacity versus scheduled workload to prevent burnout before it happens.

---

## 🏗️ Architecture

The project is structured as a full-stack monorepo:

### 1. Backend (`/server`)
- **Node.js & TypeScript**: Strongly typed core logic.
- **Express.js**: REST API layer.
- **Prisma ORM**: Database interactions.
  - *Local Development*: SQLite for fast iteration.
  - *Production*: PostgreSQL (Render) using a dynamic schema-swap script.
- **Jest**: Comprehensive automated testing (Unit, Integration, Security, and Autonomy E2E).

### 2. Frontend (`/equilibrium_app`)
- **Flutter**: Cross-platform UI framework compiling to:
  - **Android APK**
  - **Web** (Hosted on Netlify)
- **State Management**: Provider/Riverpod.

---

## 🚀 Live Demo & Deployment

- **Backend API (Render):** `https://equilibrium-42g8.onrender.com/api/v1`
- **Frontend Web App (Netlify):** *[Insert your Netlify URL here]*
- **Android App:** Download the compiled APK from `equilibrium_app/build/app/outputs/flutter-apk/app-release.apk`

---

## 🛠️ Local Development Setup

### Prerequisites
- Node.js (v20+)
- Flutter SDK (v3.22+)
- SQLite (for local database)

### Backend Setup
```bash
cd server

# Install dependencies
npm install

# Setup local SQLite database
npx prisma db push

# Start the development server (runs on http://localhost:3000)
npm run dev
```

### Running Tests
The backend features an extensive 56-test suite verifying the core scheduling algorithms and security boundaries.
```bash
cd server
npm test           # Runs only the core scheduler unit tests
npm run test:api   # Runs the full suite (Unit + API + Security + Autonomy)
```

### Frontend Setup
```bash
cd equilibrium_app

# Install dependencies
flutter pub get

# Run on Chrome (Web)
flutter run -d chrome

# Build Android APK
flutter build apk
```

---

## 🔒 Security & Validation

- **Authentication**: JWT-based secure sessions.
- **IDOR Protection**: Strict ownership validation on all routes (Task, Schedule, Decision Logs).
- **Rate Limiting**: Prevents brute-force attacks on auth endpoints.
- **CI/CD Pipeline**: GitHub Actions automatically verifies the Flutter build and runs the full backend test suite against an ephemeral PostgreSQL database on every push.

---

## 🎓 DTPLM Submission Details
This project demonstrates the complete product lifecycle from ideation (addressing student burnout) to architecture design, implementation of complex algorithms, automated CI/CD testing, and multi-platform production deployment.

**Status: Fully Complete & Deployed ✅**
