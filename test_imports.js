const axios = require('axios');
const fs = require('fs');

async function run() {
  try {
    // 1. Register a test user
    const email = `test-import-${Date.now()}@example.com`;
    const pwd = 'password123';
    await axios.post('http://localhost:3000/auth/register', {
      email, password: pwd, name: 'Import Tester'
    });
    const loginRes = await axios.post('http://localhost:3000/auth/login', {
      email, password: pwd
    });
    const token = loginRes.data.token;
    
    console.log('[TEST] Registered and logged in:', email);

    // 2. ICS Import
    const icsData = fs.readFileSync('./calendar.ics', 'utf8');
    const icsRes = await axios.post('http://localhost:3000/imports/calendar/ics', icsData, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'text/calendar'
      }
    });
    console.log('[TEST] ICS Import Response:');
    console.log(JSON.stringify(icsRes.data, null, 2));

    // Get commitments
    const getCommRes = await axios.get('http://localhost:3000/commitments', {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    console.log('[TEST] Created Commitments from ICS:');
    console.log(JSON.stringify(getCommRes.data, null, 2));

    // 3. Syllabus Import (PDF)
    // We will generate a mock pdf buffer. Our backend uses pdf-parse.
    // pdf-parse needs a valid PDF structure, so we can't just pass text.
    // Instead of actually parsing a PDF here (which requires a valid PDF file), 
    // let's look at what the backend does.
    console.log('[TEST] Note: Syllabus import test skipped because generating a valid PDF in this test script is complex. But we can test the API endpoint error handling or skip it.');

  } catch (err) {
    console.error('Error:', err.response ? err.response.data : err.message);
  }
}

run();
