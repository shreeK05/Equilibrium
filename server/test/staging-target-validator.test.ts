import http from 'http';
import { spawn } from 'child_process';
import path from 'path';
import {
  validateStagingTarget,
  createSecureRequester,
  FORBIDDEN_PRODUCTION_HOSTS,
} from '../scripts/staging-target-validator';

describe('Phase 4A.1: Staging Target Validation & Security Gate', () => {
  // ---------------------------------------------------------------------------
  // 1. Approved staging hostname
  // ---------------------------------------------------------------------------
  it('1. accepts explicitly approved staging hostname over HTTPS', () => {
    const res = validateStagingTarget({
      targetUrl: 'https://staging-api.equilibrium.app/api/v1',
      allowedHost: 'staging-api.equilibrium.app',
      allowLocalhost: false,
    });
    expect(res.valid).toBe(true);
    expect(res.hostname).toBe('staging-api.equilibrium.app');
    expect(res.approvedOrigin).toBe('https://staging-api.equilibrium.app');
    expect(res.normalizedUrl).toBe('https://staging-api.equilibrium.app/api/v1');
  });

  // ---------------------------------------------------------------------------
  // 2. Missing approved hostname
  // ---------------------------------------------------------------------------
  it('2. fails closed when approved hostname (STAGING_ALLOWED_HOST) is missing', () => {
    const res = validateStagingTarget({
      targetUrl: 'https://staging-api.equilibrium.app/api/v1',
      allowedHost: '',
      allowLocalhost: false,
    });
    expect(res.valid).toBe(false);
    expect(res.error).toContain('Missing STAGING_ALLOWED_HOST');
  });

  // ---------------------------------------------------------------------------
  // 3. Known production hostname
  // ---------------------------------------------------------------------------
  it('3. strictly rejects known production hostnames even if configured as allowed host', () => {
    for (const prodHost of FORBIDDEN_PRODUCTION_HOSTS) {
      const res = validateStagingTarget({
        targetUrl: `https://${prodHost}/api/v1`,
        allowedHost: prodHost,
        allowLocalhost: false,
      });
      expect(res.valid).toBe(false);
      expect(res.error).toContain('forbidden production host');
    }
  });

  // ---------------------------------------------------------------------------
  // 4. Lookalike hostnames (domain suffix spoofing)
  // ---------------------------------------------------------------------------
  it('4. rejects lookalike hostnames with added suffixes or attacker subdomains', () => {
    const lookalikes = [
      'staging-api.equilibrium.app.attacker.com',
      'equilibrium-42g8.onrender.com.evil.org',
      'equilibrium.app.phishing.net',
      'not-staging-api.equilibrium.app',
    ];

    for (const lookalike of lookalikes) {
      const res = validateStagingTarget({
        targetUrl: `https://${lookalike}/api/v1`,
        allowedHost: 'staging-api.equilibrium.app',
        allowLocalhost: false,
      });
      expect(res.valid).toBe(false);
      expect(res.error).toMatch(/does not match approved staging host|forbidden production host|forbidden production lookalike domain/);
    }
  });

  // ---------------------------------------------------------------------------
  // 5. Unexpected external hostname
  // ---------------------------------------------------------------------------
  it('5. rejects unexpected external hostnames', () => {
    const res = validateStagingTarget({
      targetUrl: 'https://random-service.io/api/v1',
      allowedHost: 'staging-api.equilibrium.app',
      allowLocalhost: false,
    });
    expect(res.valid).toBe(false);
    expect(res.error).toContain('does not match approved staging host');
  });

  // ---------------------------------------------------------------------------
  // 6. Malformed URL
  // ---------------------------------------------------------------------------
  it('6. rejects malformed or invalid URLs', () => {
    const malformed = [
      'not-a-url',
      'http://',
      'https://:8080/invalid',
      'ftp://staging-api.equilibrium.app',
      '',
    ];

    for (const targetUrl of malformed) {
      const res = validateStagingTarget({
        targetUrl,
        allowedHost: 'staging-api.equilibrium.app',
        allowLocalhost: false,
      });
      expect(res.valid).toBe(false);
      expect(res.error).toBeDefined();
    }
  });

  // ---------------------------------------------------------------------------
  // 7. Redirect to an unapproved origin
  // ---------------------------------------------------------------------------
  describe('7. Redirect Security Verification', () => {
    let mockServer: http.Server;
    let serverPort: number;
    let serverOrigin: string;

    beforeAll(async () => {
      mockServer = http.createServer((req, res) => {
        if (req.url === '/redirect-external') {
          res.writeHead(302, { Location: 'https://evil-attacker.example.com/steal-creds' });
          res.end();
        } else if (req.url === '/redirect-internal') {
          res.writeHead(302, { Location: '/safe-destination' });
          res.end();
        } else if (req.url === '/safe-destination') {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ status: 'reached-destination' }));
        } else {
          res.writeHead(404);
          res.end();
        }
      });

      await new Promise<void>((resolve) => {
        mockServer.listen(0, '127.0.0.1', () => {
          const address = mockServer.address() as any;
          serverPort = address.port;
          serverOrigin = `http://127.0.0.1:${serverPort}`;
          resolve();
        });
      });
    });

    afterAll(async () => {
      await new Promise<void>((resolve) => mockServer.close(() => resolve()));
    });

    it('rejects redirect when target origin differs from approved origin', async () => {
      const secureRequest = createSecureRequester(serverOrigin);
      await expect(
        secureRequest(`${serverOrigin}/redirect-external`, {
          method: 'POST',
          headers: { Authorization: 'Bearer test-token' },
        })
      ).rejects.toThrow(/Security Violation: Redirect to unapproved origin rejected/);
    });

    it('permits redirect when target location stays within approved origin', async () => {
      const secureRequest = createSecureRequester(serverOrigin);
      const res = await secureRequest(`${serverOrigin}/redirect-internal`);
      expect(res.status).toBe(200);
      expect(res.body?.status).toBe('reached-destination');
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Failed smoke-test step producing nonzero exit code
  // ---------------------------------------------------------------------------
  it('8. ensures smoke test process fails with nonzero exit code on invalid target or config', async () => {
    const runProcess = (env: Record<string, string>) => {
      return new Promise<number>((resolve) => {
        const proc = spawn('npx', ['tsx', 'scripts/staging-smoke-test.ts'], {
          cwd: path.resolve(__dirname, '..'),
          env: {
            ...process.env,
            ...env,
          },
          stdio: 'pipe',
          shell: true,
        });
        proc.on('exit', (code) => {
          resolve(code ?? 0);
        });
      });
    };

    // Subtest A: Missing STAGING_API_URL -> Exit code 2 (BLOCKED)
    const codeMissing = await runProcess({
      STAGING_API_URL: '',
      STAGING_ALLOWED_HOST: '',
    });
    expect(codeMissing).toBe(2);

    // Subtest B: Production URL -> Exit code 2 (BLOCKED)
    const codeProd = await runProcess({
      STAGING_API_URL: 'https://equilibrium-42g8.onrender.com/api/v1',
      STAGING_ALLOWED_HOST: 'equilibrium-42g8.onrender.com',
    });
    expect(codeProd).toBe(2);

    // Subtest C: Unreachable host -> Exit code 2 (BLOCKED on health check)
    const codeUnreachable = await runProcess({
      STAGING_API_URL: 'https://staging-api.equilibrium.app/api/v1',
      STAGING_ALLOWED_HOST: 'staging-api.equilibrium.app',
      STAGING_TEST_EMAIL: 'valid@equilibrium.test',
      STAGING_TEST_PASSWORD: 'ValidPassword123!',
    });
    expect(codeUnreachable).toBe(2);
  }, 20000);

  // ---------------------------------------------------------------------------
  // 9. Explicitly enabled local-test mode
  // ---------------------------------------------------------------------------
  it('9. enforces local-test mode distinction: rejects localhost unless ALLOW_LOCALHOST=true', () => {
    // Rejected when allowLocalhost is false
    const resBlocked = validateStagingTarget({
      targetUrl: 'http://localhost:3000/api/v1',
      allowLocalhost: false,
    });
    expect(resBlocked.valid).toBe(false);
    expect(resBlocked.error).toContain('Localhost target "localhost" rejected');

    const resIpBlocked = validateStagingTarget({
      targetUrl: 'http://127.0.0.1:3000/api/v1',
      allowLocalhost: false,
    });
    expect(resIpBlocked.valid).toBe(false);
    expect(resIpBlocked.error).toContain('Localhost target "127.0.0.1" rejected');

    // Permitted when allowLocalhost is true
    const resAllowed = validateStagingTarget({
      targetUrl: 'http://localhost:3999/api/v1',
      allowLocalhost: true,
    });
    expect(resAllowed.valid).toBe(true);
    expect(resAllowed.approvedOrigin).toBe('http://localhost:3999');
    expect(resAllowed.normalizedUrl).toBe('http://localhost:3999/api/v1');
  });
});
