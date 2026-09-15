const { PrismaClient } = require('@prisma/client');

module.exports = async function globalSetup() {
  const dbUrl = process.env.DATABASE_URL || '';
  if (!dbUrl.includes('localhost') && !dbUrl.includes('127.0.0.1')) {
    throw new Error("REFUSING TO RUN TESTS: DATABASE_URL is not a local test database.");
  }

  const prisma = new PrismaClient();
  try {
    await prisma.$transaction([
      prisma.decisionLog.deleteMany(),
      prisma.scheduleBlock.deleteMany(),
      prisma.scheduleVersion.deleteMany(),
      prisma.disruptionEvent.deleteMany(),
      prisma.fixedCommitment.deleteMany(),
      prisma.task.deleteMany(),
      prisma.userConstraint.deleteMany(),
      prisma.user.deleteMany(),
    ]);
  } finally {
    await prisma.$disconnect();
  }
};
