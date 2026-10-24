import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import yaml from 'js-yaml';

describe('Regression: Staging Startup Isolation & Safety Gate (Phase 4B.5)', () => {
  const serverDir = path.resolve(__dirname, '..');
  const rootDir = path.resolve(__dirname, '../..');
  const prestartScriptPath = path.join(serverDir, 'scripts', 'prestart-check.js');

  const validStagingConfig = {
    RENDER_SERVICE_NAME: 'equilibrium-api-staging',
    STAGING_SUPABASE_PROJECT_REF: 'stagingref',
    DATABASE_URL: 'postgresql://postgres.stagingref:secretpass123@aws-0-ap-south-1.pooler.supabase.com:5432/postgres',
    JWT_SECRET: 'abcdefghijklmnopqrstuvwxyz0123456789_staging_secret',
    ALLOWED_ORIGINS: 'https://staging.equilibrium.app,http://localhost:8080',
    ALLOW_LOCAL_START: 'false'
  };

  function runScriptWithEnv(envOverrides: Record<string, string | undefined>) {
    const cleanEnv: Record<string, string> = {
      PATH: process.env.PATH || '',
      SYSTEMROOT: process.env.SYSTEMROOT || '',
      NODE_ENV: 'production'
    };

    // Merge base valid config with overrides
    for (const [k, v] of Object.entries(validStagingConfig)) {
      if (v !== undefined) cleanEnv[k] = v;
    }
    for (const [k, v] of Object.entries(envOverrides)) {
      if (v === undefined) {
        delete cleanEnv[k];
      } else {
        cleanEnv[k] = v;
      }
    }

    const res = spawnSync('node', [prestartScriptPath], {
      cwd: serverDir,
      env: cleanEnv,
      encoding: 'utf8'
    });

    return {
      status: res.status,
      stdout: res.stdout || '',
      stderr: res.stderr || '',
      output: (res.stdout || '') + (res.stderr || '')
    };
  }

  // ---------------------------------------------------------------------------
  // 1. Production npm start does not begin executing staging migration flow
  // ---------------------------------------------------------------------------
  it('1. Production npm start does not unexpectedly begin executing the staging migration flow', () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(serverDir, 'package.json'), 'utf8'));
    const prodRenderYaml = fs.readFileSync(path.join(rootDir, 'render.yaml'), 'utf8');

    // Production render.yaml must point to npm start
    expect(prodRenderYaml).toContain('startCommand: npm start');

    // Production npm start must NOT invoke prestart-check.js (which enforces staging identity & rules)
    expect(pkg.scripts.start).toBeDefined();
    expect(pkg.scripts.start).not.toContain('scripts/prestart-check.js');
    expect(pkg.scripts.start).toBe('npx prisma migrate deploy && node dist/server.js');
  });

  // ---------------------------------------------------------------------------
  // 2. Staging startup invokes staging safety check before migrations
  // ---------------------------------------------------------------------------
  it('2. Staging startup invokes the staging safety check before migrations', () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(serverDir, 'package.json'), 'utf8'));
    const stagingRenderYaml = fs.readFileSync(path.join(rootDir, 'render.staging.yaml'), 'utf8');

    // Staging render.staging.yaml must use start:staging
    expect(stagingRenderYaml).toContain('startCommand: npm run start:staging');

    // start:staging must invoke prestart-check.js before prisma migrate deploy
    expect(pkg.scripts['start:staging']).toBeDefined();
    const parts = pkg.scripts['start:staging'].split('&&').map((s: string) => s.trim());
    expect(parts[0]).toBe('node scripts/prestart-check.js');
    expect(parts[1]).toBe('npx prisma migrate deploy');
    expect(parts[2]).toBe('node dist/server.js');
  });

  // ---------------------------------------------------------------------------
  // 3. Production database references are rejected unconditionally
  // ---------------------------------------------------------------------------
  it('3. All candidate and confirmed production database references are rejected for staging', () => {
    // Reference 1: cazlrtmmsikikexmepoc (hostname - pooler)
    const resHost1 = runScriptWithEnv({
      DATABASE_URL: 'postgresql://postgres.custom:pass123@aws-0-cazlrtmmsikikexmepoc.pooler.supabase.com:5432/postgres'
    });
    expect(resHost1.status).toBe(1);
    expect(resHost1.stderr).toContain('CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference');

    // Reference 1: cazlrtmmsikikexmepoc (hostname - direct)
    const resDirect1 = runScriptWithEnv({
      DATABASE_URL: 'postgresql://postgres:pass123@db.cazlrtmmsikikexmepoc.supabase.co:5432/postgres'
    });
    expect(resDirect1.status).toBe(1);
    expect(resDirect1.stderr).toContain('CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference');

    // Reference 1: cazlrtmmsikikexmepoc (username)
    const resUser1 = runScriptWithEnv({
      DATABASE_URL: 'postgresql://postgres.cazlrtmmsikikexmepoc:pass123@aws-0-ap-south-1.pooler.supabase.com:5432/postgres'
    });
    expect(resUser1.status).toBe(1);
    expect(resUser1.stderr).toContain('CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference');

    // Reference 2: rlqphunokjkxzqetondw (hostname - pooler)
    const resHost2 = runScriptWithEnv({
      DATABASE_URL: 'postgresql://postgres.custom:pass123@aws-0-rlqphunokjkxzqetondw.pooler.supabase.com:5432/postgres'
    });
    expect(resHost2.status).toBe(1);
    expect(resHost2.stderr).toContain('CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference');

    // Reference 2: rlqphunokjkxzqetondw (hostname - direct)
    const resDirect2 = runScriptWithEnv({
      DATABASE_URL: 'postgresql://postgres:pass123@db.rlqphunokjkxzqetondw.supabase.co:5432/postgres'
    });
    expect(resDirect2.status).toBe(1);
    expect(resDirect2.stderr).toContain('CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference');

    // Reference 2: rlqphunokjkxzqetondw (username)
    const resUser2 = runScriptWithEnv({
      DATABASE_URL: 'postgresql://postgres.rlqphunokjkxzqetondw:pass123@aws-0-ap-south-1.pooler.supabase.com:5432/postgres'
    });
    expect(resUser2.status).toBe(1);
    expect(resUser2.stderr).toContain('CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference');

    // Reference 3: equilibrium-db (Render-managed production database hostname)
    const resRenderDb = runScriptWithEnv({
      DATABASE_URL: 'postgresql://equilibrium:pass123@equilibrium-db:5432/equilibrium'
    });
    expect(resRenderDb.status).toBe(1);
    expect(resRenderDb.stderr).toContain('CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference');
  });

  // ---------------------------------------------------------------------------
  // 4. Missing or incorrect hosted staging identity stops execution before migrations
  // ---------------------------------------------------------------------------
  it('4. Missing or incorrect hosted staging identity stops execution before migrations', () => {
    // Missing identity
    const resMissing = runScriptWithEnv({
      RENDER_SERVICE_NAME: undefined
    });
    expect(resMissing.status).toBe(1);
    expect(resMissing.stderr).toContain('FATAL: Missing RENDER_SERVICE_NAME in hosted environment');

    // Incorrect identity (e.g. attempting to run staging script on production service)
    const resMismatch = runScriptWithEnv({
      RENDER_SERVICE_NAME: 'equilibrium-api'
    });
    expect(resMismatch.status).toBe(1);
    expect(resMismatch.stderr).toContain('FATAL: Service identity mismatch. Expected "equilibrium-api-staging", received "equilibrium-api"');
  });

  // ---------------------------------------------------------------------------
  // 5. Missing database configuration stops execution before migrations
  // ---------------------------------------------------------------------------
  it('5. Missing database configuration stops execution before migrations', () => {
    // Missing DATABASE_URL
    const resMissing = runScriptWithEnv({
      DATABASE_URL: undefined
    });
    expect(resMissing.status).toBe(1);
    expect(resMissing.stderr).toContain('FATAL: DATABASE_URL environment variable is not defined');

    // Malformed DATABASE_URL
    const resMalformed = runScriptWithEnv({
      DATABASE_URL: 'not-a-valid-url'
    });
    expect(resMalformed.status).toBe(1);
    expect(resMalformed.stderr).toContain('FATAL: Malformed DATABASE_URL');

    // Non-postgres protocol
    const resProtocol = runScriptWithEnv({
      DATABASE_URL: 'mysql://user:pass@localhost:3306/db'
    });
    expect(resProtocol.status).toBe(1);
    expect(resProtocol.stderr).toContain('FATAL: Invalid database protocol "mysql:"');
  });

  // ---------------------------------------------------------------------------
  // 6. Missing or wildcard staging origin fails the staging preflight
  // ---------------------------------------------------------------------------
  it('6. A missing or wildcard staging origin fails the staging preflight', () => {
    // Missing ALLOWED_ORIGINS
    const resMissing = runScriptWithEnv({
      ALLOWED_ORIGINS: undefined
    });
    expect(resMissing.status).toBe(1);
    expect(resMissing.stderr).toContain('FATAL: ALLOWED_ORIGINS is missing or empty');

    // Wildcard origin
    const resWildcard = runScriptWithEnv({
      ALLOWED_ORIGINS: '*'
    });
    expect(resWildcard.status).toBe(1);
    expect(resWildcard.stderr).toContain('FATAL: Wildcard CORS origin ("*") is rejected for staging');

    // Wildcard origin inside comma list
    const resWildcardList = runScriptWithEnv({
      ALLOWED_ORIGINS: 'https://staging.equilibrium.app, *'
    });
    expect(resWildcardList.status).toBe(1);
    expect(resWildcardList.stderr).toContain('FATAL: Wildcard CORS origin ("*") is rejected for staging');

    // Verify render.staging.yaml requires explicit dashboard origin config (sync: false)
    const stagingDoc = yaml.load(fs.readFileSync(path.join(rootDir, 'render.staging.yaml'), 'utf8')) as any;
    const originEnv = stagingDoc.services[0].envVars.find((e: any) => e.key === 'ALLOWED_ORIGINS');
    expect(originEnv).toBeDefined();
    expect(originEnv.sync).toBe(false);
    expect(originEnv.value).toBeUndefined();
  });

  // ---------------------------------------------------------------------------
  // 7. Safe local-test mode works only when explicitly enabled
  // ---------------------------------------------------------------------------
  it('7. Safe local-test mode works only when explicitly enabled', () => {
    // Without ALLOW_LOCAL_START=true, running locally (no RENDER_SERVICE_NAME) fails
    const resNoLocalFlag = runScriptWithEnv({
      RENDER_SERVICE_NAME: undefined,
      ALLOW_LOCAL_START: undefined
    });
    expect(resNoLocalFlag.status).toBe(1);
    expect(resNoLocalFlag.stderr).toContain('Hosted staging must fail closed when service identity cannot be verified');

    // With ALLOW_LOCAL_START=true, local execution succeeds without RENDER_SERVICE_NAME
    const resWithLocalFlag = runScriptWithEnv({
      RENDER_SERVICE_NAME: undefined,
      ALLOW_LOCAL_START: 'true'
    });
    expect(resWithLocalFlag.status).toBe(0);
    expect(resWithLocalFlag.stdout).toContain('Local rehearsal mode enabled via ALLOW_LOCAL_START=true');
    expect(resWithLocalFlag.stdout).toContain('Staging preflight safety checks PASSED');
  });

  // ---------------------------------------------------------------------------
  // 8. Failures preserve a nonzero exit code and expose no secret values
  // ---------------------------------------------------------------------------
  it('8. Failures preserve a nonzero exit code and expose no secret values', () => {
    const sensitiveDbPass = 'P@ssw0rd_SUPER_SECRET_12345_XYZ!';
    const sensitiveJwt = 'super_secret_jwt_key_that_should_never_leak_in_logs_1234567890';

    // Failure: Transaction Pooler Port 6543
    const resPooler = runScriptWithEnv({
      DATABASE_URL: `postgresql://postgres.stagingref:${sensitiveDbPass}@aws-0-ap-south-1.pooler.supabase.com:6543/postgres?search_path=public`,
      JWT_SECRET: sensitiveJwt
    });
    expect(resPooler.status).toBe(1);
    expect(resPooler.stderr).toContain('DATABASE_URL uses port 6543 (Transaction Pooler)');
    expect(resPooler.stderr).toContain('Prisma migrations require Supabase Session Pooler (port 5432)');

    // Ensure secrets are never printed in stdout or stderr
    expect(resPooler.output).not.toContain(sensitiveDbPass);
    expect(resPooler.output).not.toContain(sensitiveJwt);
    expect(resPooler.output).not.toContain('search_path=public');

    // Failure: Short JWT secret
    const resShortJwt = runScriptWithEnv({
      JWT_SECRET: 'too-short'
    });
    expect(resShortJwt.status).toBe(1);
    expect(resShortJwt.stderr).toContain('JWT_SECRET must be set to at least 32 characters');
    expect(resShortJwt.output).not.toContain(validStagingConfig.DATABASE_URL);
  });

  // ---------------------------------------------------------------------------
  // 9. Approved staging Session Pooler URL passes preflight
  // ---------------------------------------------------------------------------
  it('9. The exact approved staging Session Pooler URL passes preflight', () => {
    const res = runScriptWithEnv({});
    expect(res.status).toBe(0);
    expect(res.stdout).toContain('Verified hosted staging service identity: equilibrium-api-staging');
    expect(res.stdout).toContain('Staging database target validated: projectRef=stagingref');
    expect(res.stdout).toContain('Staging preflight safety checks PASSED');
  });

  // ---------------------------------------------------------------------------
  // 10. Render-managed database URLs are rejected for hosted staging
  // ---------------------------------------------------------------------------
  it('10. A Render-managed database URL is rejected for hosted staging', () => {
    // Render internal host
    const resInternal = runScriptWithEnv({
      DATABASE_URL: 'postgresql://postgres.stagingref:secretpass123@dpg-c1234567-a.oregon-postgres.render.com:5432/postgres'
    });
    expect(resInternal.status).toBe(1);
    expect(resInternal.stderr).toContain('Render-managed database target');

    // Render local service name
    const resServiceName = runScriptWithEnv({
      DATABASE_URL: 'postgresql://postgres.stagingref:secretpass123@equilibrium-db:5432/postgres'
    });
    expect(resServiceName.status).toBe(1);
    // Blocked by either production block or Render-managed check
    expect(resServiceName.stderr).toContain('CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference');
  });

  // ---------------------------------------------------------------------------
  // 11. Direct Supabase database URLs are rejected for hosted staging
  // ---------------------------------------------------------------------------
  it('11. Direct Supabase database URLs (*.supabase.co) are rejected for hosted staging', () => {
    const resDirect = runScriptWithEnv({
      DATABASE_URL: 'postgresql://postgres:secretpass123@db.stagingref.supabase.co:5432/postgres'
    });
    expect(resDirect.status).toBe(1);
    expect(resDirect.stderr).toContain('Direct Supabase database URL');
    expect(resDirect.stderr).toContain('Staging requires the Supabase shared Session Pooler');
  });

  // ---------------------------------------------------------------------------
  // 12. Missing, mismatched, or production STAGING_SUPABASE_PROJECT_REF is rejected
  // ---------------------------------------------------------------------------
  it('12. Missing, mismatched, or production STAGING_SUPABASE_PROJECT_REF is rejected', () => {
    // Missing STAGING_SUPABASE_PROJECT_REF
    const resMissing = runScriptWithEnv({
      STAGING_SUPABASE_PROJECT_REF: undefined
    });
    expect(resMissing.status).toBe(1);
    expect(resMissing.stderr).toContain('FATAL: Missing STAGING_SUPABASE_PROJECT_REF in hosted staging environment');

    // Mismatched STAGING_SUPABASE_PROJECT_REF (env has 'otherref' but URL has 'postgres.stagingref')
    const resMismatch = runScriptWithEnv({
      STAGING_SUPABASE_PROJECT_REF: 'otherref'
    });
    expect(resMismatch.status).toBe(1);
    expect(resMismatch.stderr).toContain('FATAL: Database username mismatch. Expected "postgres.otherref", received "postgres.stagingref"');

    // STAGING_SUPABASE_PROJECT_REF set to production ref rlqphunokjkxzqetondw
    const resProdRef1 = runScriptWithEnv({
      STAGING_SUPABASE_PROJECT_REF: 'rlqphunokjkxzqetondw'
    });
    expect(resProdRef1.status).toBe(1);
    expect(resProdRef1.stderr).toContain('CRITICAL SAFETY BLOCK: STAGING_SUPABASE_PROJECT_REF ("rlqphunokjkxzqetondw") matches a known production database reference');

    // STAGING_SUPABASE_PROJECT_REF set to candidate production ref cazlrtmmsikikexmepoc
    const resProdRef2 = runScriptWithEnv({
      STAGING_SUPABASE_PROJECT_REF: 'cazlrtmmsikikexmepoc'
    });
    expect(resProdRef2.status).toBe(1);
    expect(resProdRef2.stderr).toContain('CRITICAL SAFETY BLOCK: STAGING_SUPABASE_PROJECT_REF ("cazlrtmmsikikexmepoc") matches a known production database reference');
  });

  // ---------------------------------------------------------------------------
  // 13. Invalid port fails before migrations run
  // ---------------------------------------------------------------------------
  it('13. An invalid port (non-5432) fails before migrations run', () => {
    // Port 5433
    const resPort = runScriptWithEnv({
      DATABASE_URL: 'postgresql://postgres.stagingref:secretpass123@aws-0-ap-south-1.pooler.supabase.com:5433/postgres'
    });
    expect(resPort.status).toBe(1);
    expect(resPort.stderr).toContain('Invalid database port "5433". Supabase Session Pooler requires port 5432');
  });

  // ---------------------------------------------------------------------------
  // 14. Missing database username fails before migrations run
  // ---------------------------------------------------------------------------
  it('14. Missing database username fails before migrations run', () => {
    const resNoUser = runScriptWithEnv({
      DATABASE_URL: 'postgresql://aws-0-ap-south-1.pooler.supabase.com:5432/postgres'
    });
    expect(resNoUser.status).toBe(1);
    expect(resNoUser.stderr).toContain('FATAL: Missing database username in DATABASE_URL');
  });

  // ---------------------------------------------------------------------------
  // 15. Local-test mode cannot bypass known production database blocks
  // ---------------------------------------------------------------------------
  it('15. Local-test mode cannot bypass known production database blocks', () => {
    // With ALLOW_LOCAL_START=true and production ref in URL, it must still FAIL
    const resLocalWithProd = runScriptWithEnv({
      ALLOW_LOCAL_START: 'true',
      RENDER_SERVICE_NAME: undefined,
      DATABASE_URL: 'postgresql://postgres.rlqphunokjkxzqetondw:secretpass@aws-0-ap-south-1.pooler.supabase.com:5432/postgres'
    });
    expect(resLocalWithProd.status).toBe(1);
    expect(resLocalWithProd.stderr).toContain('CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference');

    // With ALLOW_LOCAL_START=true and candidate production ref cazlrtmmsikikexmepoc
    const resLocalWithCaz = runScriptWithEnv({
      ALLOW_LOCAL_START: 'true',
      RENDER_SERVICE_NAME: undefined,
      DATABASE_URL: 'postgresql://postgres.cazlrtmmsikikexmepoc:secretpass@aws-0-ap-south-1.pooler.supabase.com:5432/postgres'
    });
    expect(resLocalWithCaz.status).toBe(1);
    expect(resLocalWithCaz.stderr).toContain('CRITICAL SAFETY BLOCK: DATABASE_URL points to the known production database project reference');
  });
});
