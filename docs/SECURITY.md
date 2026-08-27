# Equilibrium Security Strategy

This document outlines the production security implementations protecting Equilibrium users. The core philosophy is **Server-Side Enforcement**: the frontend UI is assumed compromised, and the mathematical backend acts as the ultimate authority.

## Authentication
- **Mechanism**: Stateless JSON Web Tokens (JWT).
- **Password Hashing**: Passwords are mathematically hashed using `bcrypt` with a 10-round salt prior to storage. Plaintext passwords are never logged, stored, or transmitted out of the API.
- **Login Scrambling**: Failed logins return a generic `Invalid credentials` message to prevent email enumeration.

## JWT Strategy
- **Validation**: Every authenticated route verifies the JWT via `jsonwebtoken`.
- **Expiration**: Tokens are strictly bounded (`expiresIn: 7d`). `TokenExpiredError` generates a distinct HTTP 401 code (`TOKEN_EXPIRED`) to explicitly cue the client for re-authentication.
- **Malformed Tokens**: Injections, missing `Bearer` prefixes, and tampered signatures return safe HTTP 401 generic messages.

## Authorization & Ownership (IDOR Protection)
No database query accepts arbitrary resource IDs without cross-referencing ownership.
- All Prisma repository lookups inject the JWT-extracted `userId` into the `where` clause.
- Example: `prisma.task.update({ where: { id: taskId, userId: req.userId } })`.
- Maliciously injecting another user's Schedule Version ID into the Reschedule pipeline is rejected at the repository level (`getVersion(id, userId)`), returning a generic `404 Not Found` rather than a `403 Forbidden` to mask resource existence.

## Rate Limiting
- To prevent brute-force credential stuffing, `/api/v1/auth/*` endpoints are protected by `express-rate-limit`.
- Defaults to 20 requests per 15-minute window per IP.

## Cross-Origin Resource Sharing (CORS)
- Unrestricted `*` origins are banned.
- Origins are strictly evaluated against the `ALLOWED_ORIGINS` environment variable array.

## Security Headers
- Protected via `helmet()`. Defends against XSS, clickjacking, MIME-type sniffing, and removes `X-Powered-By`.

## Error Handling & Data Masking
- The global error handler (`src/middleware/error.ts`) intercepts crashes, validation failures, and database errors.
- **Production Mode**: Emits a sanitized `{ code: 'INTERNAL_ERROR', requestId: '...' }` to the client, logging the raw stack trace only on the server console.

## Environment Secrets
- `.env` controls `JWT_SECRET`, `DATABASE_URL`, and `ALLOWED_ORIGINS`.
- Real credentials are mathematically omitted from git history via `.gitignore`.
