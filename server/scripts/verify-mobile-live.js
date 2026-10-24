// Comprehensive Verification of Mobile App Journeys against Live Production Backend
// Target: https://equilibrium-42g8.onrender.com/api/v1

const API_BASE = process.env.API_BASE_URL || 'https://equilibrium-42g8.onrender.com/api/v1';

async function request(endpoint, options = {}) {
  const url = `${API_BASE}${endpoint}`;
  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  const res = await fetch(url, { ...options, headers });
  let data = null;
  const text = await res.text();
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }
  return { status: res.status, ok: res.ok, data };
}

async function run() {
  console.log('================================================================');
  console.log('       EQUILIBRIUM LIVE MOBILE APP BACKEND VERIFICATION         ');
  console.log('================================================================');
  console.log('Target API:', API_BASE);
  const stamp = Date.now();
  const testEmail = `prod_mobile_${stamp}@equilibrium.test`;
  const testPassword = `Pass#${stamp}!99`;

  // 1. Health check
  console.log('\n[1/8] Checking Health Endpoint...');
  const health = await request('/health');
  if (!health.ok || health.data.status !== 'ok') {
    throw new Error(`Health check failed: ${JSON.stringify(health)}`);
  }
  console.log(' ✓ Health check passed: status=ok');

  // 2. User Registration & Login
  console.log('\n[2/8] Testing User Registration & Token Issuance...');
  const reg = await request('/auth/register', {
    method: 'POST',
    body: JSON.stringify({ email: testEmail, password: testPassword, name: 'Mobile Prod Tester' })
  });
  if (!reg.ok || !reg.data.token) {
    throw new Error(`Registration failed: ${JSON.stringify(reg)}`);
  }
  const token = reg.data.token;
  const authHeaders = { Authorization: `Bearer ${token}` };
  console.log(' ✓ Registration succeeded: userId=' + (reg.data.user?.id || 'ok'));

  const login = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email: testEmail, password: testPassword })
  });
  if (!login.ok || !login.data.token) {
    throw new Error(`Login failed: ${JSON.stringify(login)}`);
  }
  console.log(' ✓ Login succeeded with same credentials');

  // 3. Task Creation
  console.log('\n[3/8] Testing Task Creation with Decoupled Work Semantics...');
  const deadline = new Date(Date.now() + 86400000 * 2).toISOString();
  const taskRes = await request('/tasks', {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      title: 'Prepare Mobile Release Artifact',
      estimateMinutes: 60,
      priority: 'HIGH',
      deadline: deadline,
      academicWeight: 1.0,
      category: 'PRODUCTION'
    })
  });
  if (!taskRes.ok || !taskRes.data.id) {
    throw new Error(`Task creation failed: ${JSON.stringify(taskRes)}`);
  }
  const task = taskRes.data;
  const taskId = task.id;
  console.log(` ✓ Task created: id=${taskId}, estimate=${task.durationMinutes}m, remaining=${task.remainingMinutes ?? task.durationMinutes}m`);

  // 4. Task Persistence (read back)
  console.log('\n[4/8] Testing Task Persistence in Database...');
  const listRes = await request('/tasks', { headers: authHeaders });
  if (!listRes.ok || !Array.isArray(listRes.data)) {
    throw new Error(`Task listing failed: ${JSON.stringify(listRes)}`);
  }
  const persisted = listRes.data.find(t => t.id === taskId);
  if (!persisted) {
    throw new Error(`Task ${taskId} was not persisted in database!`);
  }
  console.log(` ✓ Task persisted and retrieved from live database (found ${listRes.data.length} task(s))`);

  // 5. Schedule Generation
  console.log('\n[5/8] Testing Adaptive Schedule Generation...');
  const schedRes = await request('/schedules/generate', {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({})
  });
  if (!schedRes.ok || !schedRes.data.id) {
    throw new Error(`Schedule generation failed: ${JSON.stringify(schedRes)}`);
  }
  const versionId = schedRes.data.id;
  const blocksCount = schedRes.data.blocks?.length || 0;
  console.log(` ✓ Schedule generated: versionId=${versionId}, blocksPlaced=${blocksCount}`);

  // 6. Progress Updates (Idempotent operationId)
  console.log('\n[6/8] Testing Task Progress Update (Operation Semantics)...');
  const operationId = require('crypto').randomUUID();
  const progRes = await request(`/tasks/${taskId}/progress`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      actualMinutes: 30,
      remainingMinutes: 30,
      operationId: operationId
    })
  });
  if (!progRes.ok) {
    throw new Error(`Progress update failed: ${JSON.stringify(progRes)}`);
  }
  const taskActual = progRes.data.task?.actualMinutes ?? progRes.data.actualMinutes;
  const taskRemaining = progRes.data.task?.remainingMinutes ?? progRes.data.remainingMinutes;
  console.log(` ✓ Progress update applied: actual=${taskActual}m, remaining=${taskRemaining}m`);

  // 7. Session Recovery & Idempotent Replay
  console.log('\n[7/8] Testing Idempotent Replay & Operation Recovery Endpoint...');
  const replayRes = await request(`/tasks/${taskId}/progress`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      actualMinutes: 30,
      remainingMinutes: 30,
      operationId: operationId
    })
  });
  const replayActual = replayRes.data.task?.actualMinutes ?? replayRes.data.actualMinutes;
  if (!replayRes.ok || replayActual !== 30) {
    throw new Error(`Idempotent replay failed: ${JSON.stringify(replayRes)}`);
  }
  console.log(' ✓ Idempotent replay succeeded: zero double-counting');

  const opCheck = await request(`/tasks/${taskId}/operations/${operationId}`, {
    headers: authHeaders
  });
  if (!opCheck.ok || opCheck.data.operationId !== operationId) {
    throw new Error(`Operation recovery failed: ${JSON.stringify(opCheck)}`);
  }
  console.log(' ✓ Operation recovery endpoint verified: status=' + opCheck.data.status);

  // 8. Cleanup test data
  console.log('\n[8/8] Cleaning up Scoped Test Data...');
  const delRes = await request(`/tasks/${taskId}`, {
    method: 'DELETE',
    headers: authHeaders
  });
  if (delRes.status !== 204 && delRes.status !== 200) {
    console.warn(' Cleanup warning: delete returned status', delRes.status);
  } else {
    console.log(` ✓ Scoped test task ${taskId} deleted cleanly`);
  }

  console.log('\n================================================================');
  console.log('   ALL 8 LIVE MOBILE APP BACKEND USER JOURNEYS PASSED! (OK)     ');
  console.log('================================================================');
}

run().catch(err => {
  console.error('\n❌ Verification Failed:', err);
  process.exit(1);
});
