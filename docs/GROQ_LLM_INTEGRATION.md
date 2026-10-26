# Equilibrium — Groq LLM Safe Integration Architecture & Runbook

## 1. Executive Summary

Equilibrium integrates Groq Cloud's OpenAI-compatible Chat Completions API into the existing Node.js/Express/TypeScript backend to enhance:
1. **Natural-Language Task Creation** (`POST /api/v1/nlp/parse-task`): Extracting academic task titles, subjects, estimated duration, deadlines, academic weights, and cognitive load from conversational input.
2. **Conversational Rescheduling & Disruption Handling** (`POST /api/v1/nlp/reschedule-intent` & `POST /api/v1/nlp/apply-reschedule`): Interpreting student statements of illness, fatigue, schedule conflicts, or capacity changes into formal rescheduling proposals.

Crucially, the integration is governed by **strict safety boundaries**:
- **Zero Direct Writes**: The LLM *never* writes to the database and *never* invents schedule slots.
- **Deterministic Scheduling Authority**: All placement, conflict detection, sleep shield protection, and constraint satisfaction remain 100% controlled by Equilibrium's proven deterministic scheduling engine (`capacity.ts`, `placement.ts`, `validator.ts`).
- **Structured JSON Validation**: All LLM outputs are validated at runtime against strict Zod schemas (`groqTaskJsonSchema`, `groqIntentSchema`).
- **Double Rate Limiting & Timeouts**: Endpoint-level rate limiting (25 requests/min) combined with an in-memory sliding window per-user limiter (10 requests/min/user) and strict abort timeouts (7,000–8,000 ms).
- **Graceful Deterministic Fallback**: If `GROQ_API_KEY` is missing, unconfigured, rate-limited, times out, or returns malformed data, the backend falls back to the deterministic rule-based parser without breaking student workflows or throwing 500 errors.
- **Explicit User Confirmation**: Any proposal classified as materially disruptive (e.g. clearing study blocks or deferring overdue work) sets `requiresConfirmation: true` and requires explicit student confirmation before applying.
- **Privacy Protection**: Zero personally identifiable information (PII), student emails, or account identifiers are transmitted to Groq. Input prompts are truncated to 1,500 characters.

---

## 2. Groq LLM Model Evaluation & Free-Tier Quotas

### Target Model: `openai/gpt-oss-20b`
- **Architecture**: Open-weight Mixture-of-Experts (MoE) reasoning model (21B total parameters, ~3.6B active parameters per token).
- **Context Window**: 131,072 tokens.
- **Groq LPU Support**: Native OpenAI-compatible JSON mode (`response_format: { type: 'json_object' }`).
- **Free-Tier Limits**:
  - **30 Requests/Minute (RPM)**
  - **1,000 Requests/Day (RPD)**
  - **8,000 Tokens/Minute (TPM)**
  - **200,000 Tokens/Day (TPD)**
- **Cost**: **$0.00** (Free Developer Tier). Paid upgrades are never automatically triggered.

### Backup / Fallback Model: `llama-3.3-70b-versatile`
- If `openai/gpt-oss-20b` is unavailable or undergoes scheduled maintenance, `config.groqFallbackModel` defaults to `llama-3.3-70b-versatile` (30 RPM, 1,000 RPD, 12,000 TPM, 100,000 TPD).
- `groqClient.verifyModelAvailable()` checks the available model catalog via `GET https://api.groq.com/openai/v1/models`.

---

## 3. Architecture & Data Flow

```
Student Input (Natural Language)
            │
            ▼
┌───────────────────────────────┐
│ Express NLP Router            │ ◄── Rate Limiter (25 RPM)
│ /api/v1/nlp/parse-task        │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│ Groq Client Service           │ ◄── User Sliding Window (10 RPM)
│ - Check isConfigured()        │ ◄── 7,000ms Abort Controller
│ - Bounded prompt (≤ 1500 ch)  │ ◄── JSON Mode Enforcement
└───────────────┬───────────────┘
                │
       ┌────────┴────────┐
       │                 │
[Key Present & OK]  [No Key / Error / Timeout]
       │                 │
       ▼                 ▼
┌──────────────┐   ┌───────────────────────────┐
│ Groq Cloud   │   │ Deterministic Fallback    │
│ LPU Engine   │   │ Regex & Heuristic Parser  │
└──────┬───────┘   └─────────────┬─────────────┘
       │                         │
       ▼                         │
┌──────────────┐                 │
│ Zod Schema   │                 │
│ Validation   │                 │
└──────┬───────┘                 │
       │                         │
       ▼                         │
Parsed Task / Proposal Object ◄──┘
       │
       ▼
┌───────────────────────────────────────────────┐
│ Safety Barrier                                │
│ - Ambiguity Check (missing date/estimate)     │
│ - Disruption Flag (requiresConfirmation)      │
│ - Date Bounds & Ownership Validation          │
└──────────────────────┬────────────────────────┘
                       │
                       ▼
┌───────────────────────────────────────────────┐
│ Deterministic Scheduling Engine               │
│ - Capacity Calculation                        │
│ - Fixed Commitment & Sleep Shield Isolation   │
│ - Replanning & Schedule Block Generation      │
└───────────────────────────────────────────────┘
```

---

## 4. Key Components Implemented

### 4.1. `GroqClientService` (`server/src/services/nlp/groq-client.service.ts`)
- Manages authenticated communication with `https://api.groq.com/openai/v1`.
- Binds prompts to 1,500 characters to prevent prompt injection or excessive token usage.
- Implements an internal sliding window rate-limiter per user (`10 requests / 60 seconds`).
- Sets request abort timeouts (default `8,000 ms`, configurable via `GROQ_TIMEOUT_MS`).
- Never exposes or logs the `GROQ_API_KEY`.

### 4.2. `LocalNlpTaskParser` (`server/src/services/nlp/nlp-task-parser.service.ts`)
- Implements `parseTaskAsync` supporting Groq LLM with `groqTaskJsonSchema` validation.
- Extracts `title`, `subjectName`, `category`, `estimateMinutes`, `deadlineIso`, `academicWeight`, and `cognitiveLoad`.
- Identifies missing or vague fields and populates `ambiguities` and `isAmbiguous: true`.
- Automatically reverts to `parseTaskDeterministic` when Groq is not configured or fails.

### 4.3. `ConversationalReschedulerService` (`server/src/services/nlp/conversational-rescheduler.service.ts`)
- Maps student messages to canonical reschedule intents (`CANNOT_STUDY_TONIGHT`, `MISSED_TASK`, `MOVE_TO_NEXT_SLOT`, `REDUCED_CAPACITY_TODAY`, `EXTRA_CLASS`, `GENERAL_RESCHEDULE`).
- Enforces `isMateriallyDisruptive: true` and `requiresConfirmation: true` for disruptive requests.
- Returns `clarificationQuestion` when the request is vague (e.g. "reschedule something").
- `applyReschedule` delegates 100% of block computation to `scheduleService.replan`.

### 4.4. NLP Routes & Status API (`server/src/routes/nlp.routes.ts`)
- Added `GET /api/v1/nlp/status`:
  ```json
  {
    "llmConfigured": false,
    "model": "openai/gpt-oss-20b",
    "fallbackModel": "llama-3.3-70b-versatile",
    "fallbackAvailable": true
  }
  ```
- Protects all NLP endpoints with `express-rate-limit` (25 req/min).

---

## 5. Verification & Test Suite

The regression test suite `server/test/regression.nlp-groq.test.ts` validates 10 key test scenarios:

| # | Test Scenario | Verified Behavior |
|---|---------------|-------------------|
| 1 | Missing API Key | `isConfigured()` returns `false`, gracefully falls back to deterministic parsing |
| 2 | Intent Classifier Fallback | Uses keyword regex intent classification when key is absent |
| 3 | Structured Groq Task Parsing | Parses structured JSON and validates title, subject, deadline, duration |
| 4 | Missing Deadline Ambiguity | Identifies unstated deadline, adds clarification question, sets `isAmbiguous: true` |
| 5 | Missing Duration Ambiguity | Identifies unstated duration, adds clarification question, sets `isAmbiguous: true` |
| 6 | Malformed JSON Fallback | Invalid JSON from LLM triggers immediate fallback without crashing |
| 7 | Request Timeout Handling | Timed out fetch calls trigger fallback within bounded duration |
| 8 | Per-User Rate Limiting | Exceeding 10 RPM throttles gracefully to deterministic parser |
| 9 | Disruptive Schedule Confirmation | `CANNOT_STUDY_TONIGHT` forces `requiresConfirmation: true` |
| 10 | Ambiguous Reschedule Clarification | Vague statements return friendly clarification questions |

**Test Execution Results:**
- `server/`: 13 test suites passed, 143 tests passed.
- `equilibrium_app/`: 95 widget & integration tests passed.
- `flutter analyze`: 0 issues found.

---

## 6. Render Environment Configuration Guide

To enable live Groq LLM processing on the production backend (`equilibrium-42g8.onrender.com`), configure these environment variables in the Render Dashboard:

1. Navigate to **Render Dashboard** -> **equilibrium-42g8** (Web Service).
2. Go to the **Environment** tab.
3. Add the following variables:
   - `GROQ_API_KEY`: `gsk_************************************` (Private Groq API key)
   - `GROQ_MODEL`: `openai/gpt-oss-20b` *(Optional, defaults to `openai/gpt-oss-20b`)*
   - `GROQ_FALLBACK_MODEL`: `llama-3.3-70b-versatile` *(Optional)*
   - `GROQ_TIMEOUT_MS`: `8000` *(Optional, defaults to 8000)*
4. Click **Save Changes**. Render will automatically trigger a zero-downtime deployment.
5. Verify live status by visiting `https://equilibrium-42g8.onrender.com/api/v1/nlp/status`:
   ```json
   {
     "llmConfigured": true,
     "model": "openai/gpt-oss-20b",
     "fallbackModel": "llama-3.3-70b-versatile",
     "fallbackAvailable": true
   }
   ```
6. If `GROQ_API_KEY` is omitted or temporarily removed, the service automatically and immediately operates using the deterministic fallback engine with 0% downtime.
