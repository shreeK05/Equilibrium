const { PrismaClient } = require('@prisma/client');

module.exports = async function globalSetup() {
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