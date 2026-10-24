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

  describe('TaskRepository.safeUpdate workload & status consistency', () => {
    it('synchronizes actualMinutes when completedMinutes is updated, and revives remainingMinutes on completed task', async () => {
      const task = await prisma.task.create({
        data: {
          title: 'Sync and Revive Task',
          userId: 'test-user',
          estimateMinutes: 90,
          completedMinutes: 90,
          actualMinutes: 90,
          remainingMinutes: 0,
          status: 'COMPLETED',
          deadline: new Date(),
          deadlineType: 'HARD'
        }
      });

      const updated = await taskRepo.safeUpdate(task.id, 'test-user', {
        completedMinutes: 45
      });

      expect(updated.status).toBe('IN_PROGRESS');
      expect(updated.completedMinutes).toBe(45);
      expect(updated.actualMinutes).toBe(45);
      expect(updated.remainingMinutes).toBe(45); // 90 - 45 = 45
    });

    it('synchronizes completedMinutes when actualMinutes is updated', async () => {
      const task = await prisma.task.create({
        data: {
          title: 'Actual Sync Task',
          userId: 'test-user',
          estimateMinutes: 60,
          completedMinutes: 10,
          actualMinutes: 10,
          remainingMinutes: 50,
          status: 'IN_PROGRESS',
          deadline: new Date(),
          deadlineType: 'HARD'
        }
      });

      const updated = await taskRepo.safeUpdate(task.id, 'test-user', {
        actualMinutes: 30
      });

      expect(updated.actualMinutes).toBe(30);
      expect(updated.completedMinutes).toBe(30);
    });

    it('does not auto-flip to COMPLETED on overrun when completedMinutes >= estimateMinutes unless status or remainingMinutes=0 is explicit', async () => {
      const task = await prisma.task.create({
        data: {
          title: 'Overrun Ongoing Task',
          userId: 'test-user',
          estimateMinutes: 45,
          completedMinutes: 20,
          actualMinutes: 20,
          remainingMinutes: 25,
          status: 'IN_PROGRESS',
          deadline: new Date(),
          deadlineType: 'HARD'
        }
      });

      // Student logs 60m on a 45m estimate, but has 15m left to do
      const updated = await taskRepo.safeUpdate(task.id, 'test-user', {
        completedMinutes: 60,
        remainingMinutes: 15
      });

      expect(updated.status).toBe('IN_PROGRESS');
      expect(updated.actualMinutes).toBe(60);
      expect(updated.remainingMinutes).toBe(15);
    });

    it('sets remainingMinutes to 0 when status is explicitly set to COMPLETED', async () => {
      const task = await prisma.task.create({
        data: {
          title: 'Explicit Completion Task',
          userId: 'test-user',
          estimateMinutes: 60,
          completedMinutes: 30,
          actualMinutes: 30,
          remainingMinutes: 30,
          status: 'IN_PROGRESS',
          deadline: new Date(),
          deadlineType: 'HARD'
        }
      });

      const updated = await taskRepo.safeUpdate(task.id, 'test-user', {
        status: 'COMPLETED'
      });

      expect(updated.status).toBe('COMPLETED');
      expect(updated.remainingMinutes).toBe(0);
    });

    it('strictly enforces user ownership in safeUpdate (prevents IDOR)', async () => {
      const otherUser = await prisma.user.create({
        data: {
          id: 'other-user',
          email: 'other@example.com',
          name: 'Other',
          passwordHash: 'pwd'
        }
      });

      const task = await prisma.task.create({
        data: {
          title: 'Owner Protected Task',
          userId: 'test-user',
          estimateMinutes: 60,
          completedMinutes: 0,
          status: 'PENDING',
          deadline: new Date(),
          deadlineType: 'HARD'
        }
      });

      await expect(
        taskRepo.safeUpdate(task.id, otherUser.id, { title: 'Hacked Title' })
      ).rejects.toThrow('Task not found or unauthorized');

      const untouched = await prisma.task.findUnique({ where: { id: task.id } });
      expect(untouched?.title).toBe('Owner Protected Task');
    });
  });
});
