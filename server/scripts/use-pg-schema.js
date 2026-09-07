#!/usr/bin/env node
// scripts/use-pg-schema.js
// Run before `npm run build` on Render to swap provider to postgresql.
const fs = require('fs');
const path = require('path');

const schemaPath = path.join(__dirname, '..', 'prisma', 'schema.prisma');
let content = fs.readFileSync(schemaPath, 'utf8');

// Replace sqlite provider with postgresql for production
content = content.replace(
  /provider\s*=\s*"sqlite"/,
  'provider = "postgresql"'
);

fs.writeFileSync(schemaPath, content, 'utf8');
console.log('[use-pg-schema] Switched Prisma provider to postgresql for production build.');
