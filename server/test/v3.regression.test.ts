import { PrismaClient } from '@prisma/client';
import { TaskRepository } from '../src/repositories/task.repo';
import { ScheduleRepository } from '../src/repositories/schedule.repo';

const prisma = new PrismaClient();
const taskRepo = new TaskRepository();
const scheduleRepo = new ScheduleRepository();

describe('V3 Regression Tests', () => {
  beforeAll(async () => {
    await prisma.scheduleBlock.deleteMany();
    await prisma.scheduleVersion.deleteMany();
    await prisma.task.deleteMany();
    await prisma.user.deleteMany();
    
    await prisma.user.create({
      data: {
        id: 'test-user',
        email: 'test@example.com',
        name: 'Test',
        passwordHash: 'pwd'
      }
    });
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('Regression test: task status reverts from COMPLETED when completedMinutes drops below threshold', async () => {
    const task = await prisma.task.create({
      data: {
        title: 'Status Revert Test',
        userId: 'test-user',
        estimateMinutes: 60,
        completedMinutes: 60,
        status: 'COMPLETED',
        deadline: new Date(),
        deadlineType: 'HARD'
      },
    });

    expect(task.status).toBe('COMPLETED');

    const updated = await taskRepo.safeUpdate(task.id, 'test-user', {
      completedMinutes: 30,
    });

    expect(updated.status).toBe('IN_PROGRESS');
  });

  it('Regression test: scheduledMinutes freezes correctly for a task completed in version A when version B is generated without it', async () => {
    const task = await prisma.task.create({
      data: {
        title: 'Freeze Test Task',
        userId: 'test-user',
        estimateMinutes: 60,
        status: 'PENDING',
        deadline: new Date(),
        deadlineType: 'HARD'
      },
    });

    await scheduleRepo.createSchedule(
      'test-user', 
      'MANUAL', 
      60, 
      [
        {
          type: 'TASK',
          start: new Date(),
          end: new Date(Date.now() + 60 * 60000),
          durationMinutes: 60,
          taskId: task.id,
        }
      ], 
      []
    );

    let currentTask = await prisma.task.findUnique({ where: { id: task.id } });
    expect(currentTask?.scheduledMinutes).toBe(60);

    await prisma.task.update({
      where: { id: task.id },
      data: { status: 'COMPLETED' }
    });

    await scheduleRepo.createSchedule(
      'test-user', 
      'MANUAL', 
      60, 
      [
        {
          type: 'FREE',
          start: new Date(),
          end: new Date(Date.now() + 60 * 60000),
          durationMinutes: 60,
        }
      ], 
      []
    );

    currentTask = await prisma.task.findUnique({ where: { id: task.id } });
    expect(currentTask?.scheduledMinutes).toBe(60);
  });
});
