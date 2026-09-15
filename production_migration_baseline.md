# Production Migration Baseline Protocol

The production database is currently in a "drifted" state because it was initialized using `npx prisma db push`, which does not create the `_prisma_migrations` history table. To transition safely to `npx prisma migrate deploy` and apply the missing `scheduledMinutes` column without data loss, you must follow this exact sequence on your local machine.

## Prerequisites
- A local PostgreSQL instance running (e.g., `postgresql://postgres:postgres@localhost:5432/equilibrium_local`)
- Your production Render database URL

---

## Step 1: Temporarily Revert the Schema

We must first generate a baseline migration that exactly matches the *current* state of the production database.

1. Open `server/prisma/schema.prisma` and temporarily **comment out or delete** the `scheduledMinutes` line from the `Task` model:
   ```prisma
   model Task {
     // ...
     // scheduledMinutes Int @default(0)  <-- TEMPORARILY REMOVE THIS
     // ...
   }
   ```
2. Save the file.

## Step 2: Generate the Baseline Migration Locally

Do NOT run this against production. We will use a clean local database to generate the migration file.

1. Set your terminal's `DATABASE_URL` to your local PostgreSQL instance:
   ```bash
   export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/equilibrium_local"
   # On Windows PowerShell: $env:DATABASE_URL="postgresql://..."
   ```
2. Generate the baseline migration:
   ```bash
   cd server
   npx prisma migrate dev --name initial_baseline
   ```
   *This creates a new folder in `prisma/migrations` with the entire schema (without `scheduledMinutes`).*

## Step 3: Mark Baseline as Applied in Production

Now we tell the production database to treat this new baseline migration as "already applied", skipping its execution since the tables already exist.

1. Set your terminal's `DATABASE_URL` to your **Render Production** connection string:
   ```bash
   export DATABASE_URL="postgresql://<user>:<password>@<host>/<database>"
   ```
2. Look at the `prisma/migrations` folder and copy the exact name of the newly generated folder (e.g., `20231024120000_initial_baseline`).
3. Resolve it on production:
   ```bash
   npx prisma migrate resolve --applied <exact_folder_name>
   ```

## Step 4: Generate the New Migration

We will now add `scheduledMinutes` back to the schema and generate the real migration.

1. Open `server/prisma/schema.prisma` and **restore** the `scheduledMinutes` line in the `Task` model:
   ```prisma
   model Task {
     // ...
     scheduledMinutes Int @default(0)
     // ...
   }
   ```
2. Set your terminal's `DATABASE_URL` back to your **local** PostgreSQL instance.
3. Generate the new migration:
   ```bash
   npx prisma migrate dev --name add_scheduled_minutes
   ```

## Step 5: Deploy the New Migration to Production

Finally, we deploy this new delta to production.

1. Set your terminal's `DATABASE_URL` back to your **Render Production** connection string.
2. Deploy the migration:
   ```bash
   npx prisma migrate deploy
   ```

## Step 6: Verify and Commit

1. Verify production state:
   ```bash
   npx prisma migrate status
   ```
   *It should report that all migrations are applied and the schema is up to date.*
2. Commit the `prisma/migrations` folder to Git so future deployments via Render (which now use `npx prisma migrate deploy`) will have the complete history.
