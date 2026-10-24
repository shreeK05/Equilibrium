#!/usr/bin/env node
/**
 * Equilibrium — Staging Pre-Start & Migration Safety Gate (Phase 4B.5)
 *
 * Runs strictly before `npx prisma migrate deploy` and `node dist/server.js` on staging boot.
 * Protects production data via an explicit allowlist + blocklist model:
 * - Validates service identity (RENDER_SERVICE_NAME === 'equilibrium-api-staging').
 * - Requires explicit non-secret STAGING_SUPABASE_PROJECT_REF for hosted staging.
 * - Enforces Supabase shared Session Pooler (*.pooler.supabase.com:5432).
 * - Enforces exact match between STAGING_SUPABASE_PROJECT_REF and DATABASE_URL username (postgres.<ref>).
 * - Unconditionally blocks all known production references (cazlrtmmsikikexmepoc, rlqphunokjkxzqetondw, equilibrium-db).
 * - Rejects Render-managed database hosts, direct Supabase hosts, transaction poolers (port 6543), and wildcards.
 * - Never logs credentials, full connection URLs, query parameters, or unmasked secrets.
 */

const { URL } = require('url');

const KNOWN_PRODUCTION_DB_REFS = [
  'cazlrtmmsikikexmepoc',
  'rlqphunokjkxzqetondw',
  'equilibrium-db'
];

function maskString(str) {
  if (!str) return '[EMPTY]';
  if (str.length <= 8) return '********';
  return str.substring(0, 4) + '...' + str.substring(str.length - 4);
}

function runPrestartCheck(env = process.env, exitFn = (code) => process.exit(code)) {
  console.log('[prestart-check] Running staging preflight safety gate...');

  const isLocalRehearsal = env.ALLOW_LOCAL_START === 'true';

  // 1. Service Identity Check (Fail-Closed)
  const serviceName = (env.RENDER_SERVICE_NAME || '').trim();
  if (isLocalRehearsal) {
    console.log('[prestart-check] Notice: Local rehearsal mode enabled via ALLOW_LOCAL_START=true.');
  } else {
    // Hosted staging identity enforcement
    if (!serviceName) {
      console.error('[prestart-check] FATAL: Missing RENDER_SERVICE_NAME in hosted environment.');
      console.error('[prestart-check] Hosted staging must fail closed when service identity cannot be verified.');
      console.error('[prestart-check] If running locally for testing, set ALLOW_LOCAL_START=true.');
      return exitFn(1);
    }
    if (serviceName !== 'equilibrium-api-staging') {
      console.error(`[prestart-check] FATAL: Service identity mismatch. Expected "equilibrium-api-staging", received "${serviceName}".`);
      console.error('[prestart-check] Refusing execution to prevent running staging migration flow on incorrect service.');
      return exitFn(1);
    }
    console.log(`[prestart-check] Verified hosted staging service identity: ${serviceName}`);
  }

  // 2. Database URL Basic Validation
  const rawDbUrl = (env.DATABASE_URL || '').trim();
  if (!rawDbUrl) {
    console.error('[prestart-check] FATAL: DATABASE_URL environment variable is not defined.');
    console.error('[prestart-check] Please configure DATABASE_URL in Render Dashboard settings (sync: false).');
    return exitFn(1);
  }

  let dbUrl;
  try {
    dbUrl = new URL(rawDbUrl);
  } catch (err) {
    console.error(`[prestart-check] FATAL: Malformed DATABASE_URL: ${err.message}`);
    return exitFn(1);
  }

  if (dbUrl.protocol !== 'postgres:' && dbUrl.protocol !== 'postgresql:') {
    console.error(`[prestart-check] FATAL: Invalid database protocol "${dbUrl.protocol}". Must be postgres: or postgresql:`);
    return exitFn(1);
  }

  const host = (dbUrl.hostname || '').toLowerCase();
  const port = dbUrl.port || (dbUrl.protocol === 'https:' ? '443' : '5432');
  const dbName = dbUrl.pathname || '/';
  const username = (dbUrl.username || '').toLowerCase();

  if (!host) {
    console.error('[prestart-check] FATAL: DATABASE_URL hostname is missing.');
    return exitFn(1);
  }

  // 3. Production Database Collision Guard (Unconditional: runs in BOTH hosted and local rehearsal modes)
  for (const prodRef of KNOWN_PRODUCTION_DB_REFS) {
    const lowerRef = prodRef.toLowerCase();
    if (host.includes(lowerRef) || username.includes(lowerRef)) {
      console.error('[prestart-check] CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference.');
      console.error('[prestart-check] Refusing to apply migrations or start staging service to protect production data.');
      return exitFn(1);
    }
  }

  // Also verify that STAGING_SUPABASE_PROJECT_REF does not reference a known production identity
  const stagingProjectRef = (env.STAGING_SUPABASE_PROJECT_REF || '').trim();
  if (stagingProjectRef) {
    for (const prodRef of KNOWN_PRODUCTION_DB_REFS) {
      if (stagingProjectRef.toLowerCase() === prodRef.toLowerCase()) {
        console.error(`[prestart-check] CRITICAL SAFETY BLOCK: STAGING_SUPABASE_PROJECT_REF ("${stagingProjectRef}") matches a known production database reference.`);
        console.error('[prestart-check] Refusing execution to protect production database.');
        return exitFn(1);
      }
    }
  }

  // 4. Hosted Staging Database Allowlist & Pooler Guard
  if (!isLocalRehearsal) {
    // 4.1 Require explicit non-secret STAGING_SUPABASE_PROJECT_REF
    if (!stagingProjectRef) {
      console.error('[prestart-check] FATAL: Missing STAGING_SUPABASE_PROJECT_REF in hosted staging environment.');
      console.error('[prestart-check] Staging requires an explicit Supabase project reference configured in Render Dashboard (sync: false).');
      return exitFn(1);
    }

    // 4.2 Reject Render-managed database hostnames
    if (host === 'equilibrium-db' || host.includes('render.com') || host.includes('onrender.com') || host.startsWith('dpg-')) {
      console.error(`[prestart-check] FATAL: Render-managed database target "${host}" is rejected for staging.`);
      console.error('[prestart-check] Staging must use an isolated Supabase project Session Pooler, not a Render PostgreSQL database.');
      return exitFn(1);
    }

    // 4.3 Reject direct Supabase connection URLs
    if (host.endsWith('.supabase.co') || host === 'supabase.co') {
      console.error(`[prestart-check] FATAL: Direct Supabase database URL ("${host}") is rejected.`);
      console.error('[prestart-check] Staging requires the Supabase shared Session Pooler (*.pooler.supabase.com:5432).');
      return exitFn(1);
    }

    // 4.4 Enforce Supabase shared Session Pooler host format
    const isSupabasePoolerHost = /^([a-z0-9-]+\.)*pooler\.supabase\.com$/i.test(host);
    if (!isSupabasePoolerHost) {
      console.error(`[prestart-check] FATAL: Host "${host}" is not an approved Supabase shared Session Pooler.`);
      console.error('[prestart-check] Hosted staging DATABASE_URL hostname must match *.pooler.supabase.com (e.g. aws-0-<region>.pooler.supabase.com).');
      return exitFn(1);
    }

    // 4.5 Enforce Session Pooler Port (5432) & reject Transaction Pooler (6543)
    if (port !== '5432') {
      if (port === '6543') {
        console.error('[prestart-check] FATAL: DATABASE_URL uses port 6543 (Transaction Pooler).');
        console.error('[prestart-check] Prisma migrations require Supabase Session Pooler (port 5432) for PostgreSQL advisory lock support.');
      } else {
        console.error(`[prestart-check] FATAL: Invalid database port "${port}". Supabase Session Pooler requires port 5432.`);
      }
      return exitFn(1);
    }

    // 4.6 Validate Database Username and Project Reference match
    if (!username) {
      console.error('[prestart-check] FATAL: Missing database username in DATABASE_URL.');
      return exitFn(1);
    }

    const expectedUsername = `postgres.${stagingProjectRef.toLowerCase()}`;
    if (username !== expectedUsername) {
      console.error(`[prestart-check] FATAL: Database username mismatch. Expected "${expectedUsername}", received "${username}".`);
      console.error(`[prestart-check] In Supabase shared pooler mode, the username must be "postgres.<project-ref>", matching STAGING_SUPABASE_PROJECT_REF ("${stagingProjectRef}").`);
      return exitFn(1);
    }

    console.log(`[prestart-check] Staging database target validated: projectRef=${stagingProjectRef}, poolerHost=${host}`);
  } else {
    // Local rehearsal logging & safety check on pooler port
    if (port === '6543' && host.includes('pooler.supabase.com')) {
      console.error('[prestart-check] FATAL: DATABASE_URL uses port 6543 (Transaction Pooler).');
      console.error('[prestart-check] Prisma migrations require Supabase Session Pooler (port 5432) for PostgreSQL advisory lock support.');
      return exitFn(1);
    }
  }

  // Sanitized logging (No credentials, passwords, or query parameters)
  console.log(`[prestart-check] Database Target: host=${host}, port=${port}, database=${dbName}`);

  // 5. CORS Allowed Origins Validation
  const allowedOrigins = (env.ALLOWED_ORIGINS || '').trim();
  if (!allowedOrigins) {
    console.error('[prestart-check] FATAL: ALLOWED_ORIGINS is missing or empty.');
    console.error('[prestart-check] Staging requires an explicitly configured list of permitted browser origins in Render Dashboard (sync: false).');
    return exitFn(1);
  }

  const originList = allowedOrigins.split(',').map(s => s.trim()).filter(Boolean);
  if (allowedOrigins === '*' || originList.includes('*')) {
    console.error('[prestart-check] FATAL: Wildcard CORS origin ("*") is rejected for staging.');
    console.error('[prestart-check] Staging must configure an explicit comma-separated list of permitted browser origins in Render Dashboard.');
    return exitFn(1);
  }
  console.log(`[prestart-check] CORS Allowed Origins: ${originList.join(', ')}`);

  // 6. Verify JWT_SECRET
  const jwtSecret = (env.JWT_SECRET || '').trim();
  if (jwtSecret.length < 32) {
    console.error('[prestart-check] FATAL: JWT_SECRET must be set to at least 32 characters.');
    console.error(`[prestart-check] Current length: ${jwtSecret.length} characters.`);
    return exitFn(1);
  }
  console.log(`[prestart-check] JWT_SECRET: CONFIGURED (${maskString(jwtSecret)})`);

  console.log('[prestart-check] Staging preflight safety checks PASSED.');
  return 0;
}

if (require.main === module) {
  runPrestartCheck();
}

module.exports = {
  runPrestartCheck,
  maskString,
  KNOWN_PRODUCTION_DB_REFS
};
