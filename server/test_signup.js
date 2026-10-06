const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function run() {
  const email = 'newuser-' + Date.now() + '@example.com';
  console.log('Registering user via API...');
  const req = await fetch('http://localhost:3000/api/v1/auth/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'password123', name: 'New User' })
  });
  const res = await req.json();
  console.log('API Response:', res);
  
  const user = await prisma.user.findUnique({ where: { email } });
  console.log('\nDatabase Row for ' + email + ':');
  console.log('timezone:', user.timezone);
}
run().catch(console.error).finally(() => prisma.$disconnect());
