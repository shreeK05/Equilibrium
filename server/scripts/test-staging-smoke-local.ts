/**
 * Local staging smoke runner.
 * Spawns server in a dedicated child process, executes the staging smoke test,
 * and terminates the server cleanly.
 */
import { spawn } from 'child_process';
import path from 'path';

const PORT = 3999;
const serverEnv = {
  ...process.env,
  PORT: String(PORT),
  DATABASE_URL: 'postgresql://postgres:postgres@localhost:5432/equilibrium_test?schema=public',
  JWT_SECRET: 'local-staging-test-jwt-secret-at-least-32-chars',
  NODE_ENV: 'test',
};

async function wait(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  console.log(`Starting local server on port ${PORT}...`);
  const serverProc = spawn('node', ['dist/server.js'], {
    cwd: path.resolve(__dirname, '..'),
    env: serverEnv,
    stdio: 'pipe',
  });

  serverProc.stdout.on('data', (d) => {
    const s = d.toString();
    if (s.includes('running on port')) {
      console.log(`[Server] ${s.trim()}`);
    }
  });

  serverProc.stderr.on('data', (d) => {
    console.error(`[Server Error] ${d.toString().trim()}`);
  });

  // Wait for server to bind
  let serverReady = false;
  for (let i = 0; i < 20; i++) {
    await wait(300);
    try {
      const res = await fetch(`http://localhost:${PORT}/api/v1/health`);
      if (res.ok) {
        serverReady = true;
        break;
      }
    } catch {}
  }

  if (!serverReady) {
    console.error('Failed to start local test server.');
    serverProc.kill();
    process.exit(1);
  }

  console.log('Server ready. Launching staging smoke test...\n');

  const smokeProc = spawn('npx', ['tsx', 'scripts/staging-smoke-test.ts'], {
    cwd: path.resolve(__dirname, '..'),
    env: {
      ...process.env,
      STAGING_API_URL: `http://localhost:${PORT}/api/v1`,
      ALLOW_LOCALHOST: 'true',
      STAGING_TEST_EMAIL: 'smoke_test_student@equilibrium.test',
      STAGING_TEST_PASSWORD: 'SmokeStudentPass123!',
    },
    stdio: 'inherit',
    shell: true,
  });

  smokeProc.on('exit', (code) => {
    console.log(`\nSmoke test process exited with code ${code}. Stopping local server...`);
    serverProc.kill();
    process.exit(code ?? 0);
  });
}

main().catch(err => {
  console.error('Error running local smoke test runner:', err);
  process.exit(1);
});
