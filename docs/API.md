# Equilibrium API Documentation

## Authentication
All endpoints under `/api/v1` except `/auth` and `/health` require a JWT token in the `Authorization` header.

`Authorization: Bearer <token>`

## Error Handling
Standardized error responses:
```json
{
  "error": {
    "code": "VALIDATION_ERROR | UNAUTHORIZED | INTERNAL_ERROR",
    "message": "Human readable message",
    "details": []
  }
}
```

## Endpoints

### 1. Health
`GET /api/v1/health`
Returns basic service health.

### 2. Auth
`POST /api/v1/auth/register`
Body: `{ email, password }`

`POST /api/v1/auth/login`
Body: `{ email, password }`
Response: `{ token, user: { id, email } }`

### 3. Constraints
`GET /api/v1/constraints`
Returns user's sleep, buffer, and energy preferences.

`PATCH /api/v1/constraints`
Updates preferences.

### 4. Tasks
`GET /api/v1/tasks` (List tasks)
`POST /api/v1/tasks` (Create task)
`GET /api/v1/tasks/:id` (Get task)
`PATCH /api/v1/tasks/:id` (Update task state / completion)
`DELETE /api/v1/tasks/:id` (Delete task)

### 5. Schedules & Explainability
`POST /api/v1/schedules/generate`
Generates a new schedule mathematically based on remaining constraints. Creates a new version.

`POST /api/v1/schedules/:versionId/reschedule`
Freezes locked/past blocks of the given version, recalculates capacity and durations, and generates a new `DISRUPTION` schedule version.

`GET /api/v1/schedules/current`
Returns the latest active version.

`GET /api/v1/schedules/history`
Returns past 10 versions.

`GET /api/v1/schedules/:versionId`
Returns a specific version and its blocks.

`GET /api/v1/schedules/:versionId/decisions`
Returns parsed structured explanation data (DecisionLogs) from the mathematical engine outlining exactly why tasks were fully scheduled, partially scheduled, or deferred.
