const https = require('https');

function check() {
  return new Promise((resolve) => {
    https.get('https://equilibrium-42g8.onrender.com/api/v1/auth/status', (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({ status: res.statusCode, data });
      });
    }).on('error', (err) => {
      resolve({ status: 500, error: err.message });
    });
  });
}

async function loop() {
  console.log('Polling Render deployment for commit dc8001e (/api/v1/auth/status)...');
  const start = Date.now();
  while (Date.now() - start < 180000) { // up to 3 mins
    const res = await check();
    const elapsed = Math.round((Date.now() - start) / 1000);
    console.log(`[${elapsed}s] Status: ${res.status} Response: ${res.data || res.error}`);
    if (res.status === 200) {
      console.log('🚀 DEPLOYMENT IS LIVE!');
      process.exit(0);
    }
    await new Promise(r => setTimeout(r, 10000));
  }
  console.error('Timed out waiting for deployment.');
  process.exit(1);
}

loop();
