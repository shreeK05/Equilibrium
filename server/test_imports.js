const fs = require('fs');
const PDFDocument = require('pdfkit');

async function createPDF() {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument();
    const stream = fs.createWriteStream('syllabus.pdf');
    doc.pipe(stream);
    
    doc.fontSize(20).text('Computer Science 101 Syllabus', { align: 'center' });
    doc.moveDown();
    doc.fontSize(14).text('Course Requirements:');
    doc.fontSize(12).text('- Programming Assignment 1: 120 minutes. Due: October 20, 2026.');
    doc.text('- Midterm Project: 240 minutes. Due: November 15, 2026.');
    doc.text('- Read Chapter 4: 60 minutes.');
    
    doc.end();
    stream.on('finish', () => resolve('syllabus.pdf'));
    stream.on('error', reject);
  });
}

async function run() {
  try {
    console.log('[TEST] Generating sample PDF...');
    await createPDF();
    
    // 1. Register a test user
    const email = `test-import-${Date.now()}@example.com`;
    const pwd = 'password123';
    
    const regReq = await fetch('http://localhost:3000/api/v1/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: pwd, name: 'Import Tester' })
    });
    
    const loginReq = await fetch('http://localhost:3000/api/v1/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password: pwd })
    });
    
    const loginRes = await loginReq.json();
    const token = loginRes.token;
    
    console.log('[TEST] Registered and logged in:', email);

    // 2. ICS Import
    const icsData = fs.readFileSync('../calendar.ics', 'utf8');
    const icsReq = await fetch('http://localhost:3000/api/v1/imports/calendar/ics', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'text/calendar'
      },
      body: icsData
    });
    const icsRes = await icsReq.json();
    console.log('\n[TEST] ICS Import Response:');
    console.log(JSON.stringify(icsRes, null, 2));

    const getCommReq = await fetch('http://localhost:3000/api/v1/commitments', {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const getCommRes = await getCommReq.json();
    console.log('\n[TEST] Created Commitments from ICS:');
    console.log(JSON.stringify(getCommRes, null, 2));

    // 3. Syllabus Import (PDF)
    console.log('\n[TEST] Testing Syllabus Import (PDF)...');
    const pdfData = fs.readFileSync('syllabus.pdf');
    const pdfReq = await fetch('http://localhost:3000/api/v1/imports/syllabus', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/pdf'
      },
      body: pdfData
    });
    const pdfRes = await pdfReq.json();
    console.log('\n[TEST] Syllabus Import Response (Candidates):');
    console.log(JSON.stringify(pdfRes, null, 2));

  } catch (err) {
    console.error('Error:', err);
  }
}

run();
