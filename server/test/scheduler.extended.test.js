"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const rescheduler_1 = require("../src/scheduler/rescheduler");
const validator_1 = require("../src/scheduler/validator");
const types_1 = require("../src/scheduler/types");
const priority_1 = require("../src/scheduler/priority");
// Linear Congruential Generator for deterministic random
class LCG {
    seed;
    constructor(seed) { this.seed = seed; }
    next() {
        this.seed = (this.seed * 1664525 + 1013904223) % 4294967296;
        return this.seed / 4294967296;
    }
    nextInt(min, max) {
        return Math.floor(this.next() * (max - min + 1)) + min;
    }
}
describe('Equilibrium Extended Core Scheduler Test Suite', () => {
    const now = new Date('2026-10-14T08:00:00.000Z');
    const horizonStart = new Date('2026-10-14T00:00:00.000Z');
    const horizonEnd = new Date('2026-10-21T00:00:00.000Z'); // 7 days
    const constraints = {
        sleepStart: '23:00',
        sleepEnd: '06:00',
        minSleepHours: 7.0,
        peakEnergyWindows: [{ start: '09:00', end: '12:00' }]
    };
    const createTask = (id, estimateMinutes, deadline) => ({
        id, estimateMinutes, completedMinutes: 0, remainingMinutes: estimateMinutes,
        deadline, academicWeight: 0.5, teamImpact: 0, cognitiveLoad: 'LOW', deferralCount: 0
    });
    describe('1. SLEEP SHIELD & 13. HARD-CONSTRAINT WALL', () => {
        it('Never intersects normal or overnight sleep', () => {
            // Available 20:00-21:00, task 3h (180m). Should only place 60m.
            const localNow = new Date('2026-10-14T20:00:00.000Z');
            const customEnd = new Date('2026-10-14T23:59:59.000Z'); // Just before midnight
            // Sleep starts at 21:00 for this test
            const customConstraints = {
                ...constraints, sleepStart: '21:00', sleepEnd: '06:00'
            };
            const t = createTask('t1', 180, customEnd);
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], customConstraints, [], [], horizonStart, customEnd, localNow);
            const blocks = res.blocks.filter(b => b.taskId === 't1');
            expect(blocks.length).toBe(1);
            expect(blocks[0].durationMinutes).toBe(60); // 20:00 to 21:00
            expect(blocks[0].start.toISOString()).toBe('2026-10-14T20:00:00.000Z');
            expect(blocks[0].end.toISOString()).toBe('2026-10-14T21:00:00.000Z');
        });
        it('Task starts exactly at sleep end', () => {
            const localNow = new Date('2026-10-14T06:00:00.000Z');
            const t = createTask('t1', 60, new Date('2026-10-14T10:00:00.000Z'));
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], constraints, [], [], horizonStart, horizonEnd, localNow);
            expect(res.blocks[0].start.toISOString()).toBe('2026-10-14T06:00:00.000Z');
        });
        it('Task spanning across sleep', () => {
            const localNow = new Date('2026-10-14T22:00:00.000Z');
            const t = createTask('t1', 120, new Date('2026-10-15T10:00:00.000Z'));
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], constraints, [], [], horizonStart, horizonEnd, localNow);
            // Expected to split: 1 hr at 22:00-23:00, 1 hr at 06:00-07:00
            expect(res.blocks.length).toBe(2);
            expect(res.blocks[0].durationMinutes).toBe(60);
            expect(res.blocks[0].end.toISOString()).toBe('2026-10-14T23:00:00.000Z');
            expect(res.blocks[1].durationMinutes).toBe(60);
            expect(res.blocks[1].start.toISOString()).toBe('2026-10-15T06:00:00.000Z');
        });
    });
    describe('2. FIXED COMMITMENTS', () => {
        it('Handles adjacent and overlapping fixed commitments', () => {
            const fixed = [
                { id: 'f1', start: new Date('2026-10-14T09:00:00.000Z'), end: new Date('2026-10-14T10:00:00.000Z') },
                { id: 'f2', start: new Date('2026-10-14T09:30:00.000Z'), end: new Date('2026-10-14T11:00:00.000Z') } // overlapping
            ];
            const t = createTask('t1', 120, new Date('2026-10-14T13:00:00.000Z'));
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], constraints, fixed, [], horizonStart, horizonEnd, now);
            // available: 08:00-09:00 (1h), 11:00-13:00 (2h)
            // task is 2h, so it will place at 08:00 (1h) and 11:00 (1h)
            expect(res.blocks.length).toBe(2);
            expect(res.blocks[0].start.toISOString()).toBe('2026-10-14T08:00:00.000Z');
            expect(res.blocks[0].end.toISOString()).toBe('2026-10-14T09:00:00.000Z');
            expect(res.blocks[1].start.toISOString()).toBe('2026-10-14T11:00:00.000Z');
        });
    });
    describe('3. DEADLINES', () => {
        it('Never schedules a task after its deadline', () => {
            const tightDeadline = new Date('2026-10-14T09:00:00.000Z'); // 1h available
            const t = createTask('t1', 120, tightDeadline); // needs 2h
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], constraints, [], [], horizonStart, horizonEnd, now);
            expect(res.blocks.length).toBe(1);
            expect(res.blocks[0].durationMinutes).toBe(60);
            expect(res.blocks[0].end.getTime()).toBeLessThanOrEqual(tightDeadline.getTime());
        });
    });
    describe('4. CAPACITY', () => {
        it('Zero available capacity', () => {
            const fixed = [{ id: 'f1', start: now, end: horizonEnd }];
            const t = createTask('t1', 60, horizonEnd);
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], constraints, fixed, [], horizonStart, horizonEnd, now);
            expect(res.blocks.length).toBe(0);
            expect(res.logs[0].decisionType).toBe('DEFERRED');
        });
    });
    describe('5. KNAPSACK', () => {
        it('Optimizes value correctly', () => {
            // 3 hours capacity (08:00 - 11:00).
            const d = new Date('2026-10-14T11:00:00.000Z');
            const t1 = { ...createTask('t1', 150, d), academicWeight: 0.5 }; // w=5, v ~1.375
            const t2 = { ...createTask('t2', 90, d), academicWeight: 0.4 }; // w=3, v ~1.175
            const t3 = { ...createTask('t3', 90, d), academicWeight: 0.4 }; // w=3, v ~1.175
            const res = (0, rescheduler_1.runReschedulerPipeline)([t1, t2, t3], constraints, [], [], horizonStart, d, now);
            const ids = res.blocks.map(b => b.taskId);
            expect(ids).toContain('t2');
            expect(ids).toContain('t3');
            expect(ids).not.toContain('t1');
        });
        it('Tie-breaking fallback to ID', () => {
            const d = new Date('2026-10-14T09:00:00.000Z'); // 1h capacity
            // Two identical tasks. ID 'A' should be picked before 'B'.
            const t1 = createTask('B', 60, d);
            const t2 = createTask('A', 60, d);
            const res = (0, rescheduler_1.runReschedulerPipeline)([t1, t2], constraints, [], [], horizonStart, d, now);
            expect(res.blocks[0].taskId).toBe('A');
        });
    });
    describe('6. SPLITTING', () => {
        it('Max chunk 4h, Min chunk 30m', () => {
            const t = createTask('t1', 360, horizonEnd); // 6 hours
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], constraints, [], [], horizonStart, horizonEnd, now);
            expect(res.blocks.length).toBe(2);
            expect(res.blocks[0].durationMinutes).toBe(240); // 4h
            expect(res.blocks[1].durationMinutes).toBe(120); // 2h
        });
    });
    describe('7. PARTIAL SCHEDULING & 9. INFEASIBLE SCHEDULE', () => {
        it('Partially schedules and explicitly reports deferred workload', () => {
            const d = new Date('2026-10-14T10:00:00.000Z'); // 2h available
            const t = createTask('t1', 180, d); // 3h needed
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], constraints, [], [], horizonStart, d, now);
            expect(res.blocks.length).toBe(1);
            expect(res.blocks[0].durationMinutes).toBe(120);
            const log = res.logs[0];
            expect(log.decisionType).toBe('PARTIALLY_SCHEDULED');
            expect(log.scheduledMinutes).toBe(120);
            expect(log.deferredMinutes).toBe(60);
        });
    });
    describe('8. RESCHEDULING', () => {
        it('Preserves completed/locked blocks', () => {
            const lockedBlock = {
                taskId: 't1', type: 'TASK', start: now, end: new Date('2026-10-14T09:00:00.000Z'), durationMinutes: 60, isLocked: true
            };
            const t = createTask('t1', 120, horizonEnd);
            t.completedMinutes = 60;
            t.remainingMinutes = 60;
            const newNow = new Date('2026-10-14T10:00:00.000Z');
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], constraints, [], [lockedBlock], horizonStart, horizonEnd, newNow);
            const t1Blocks = res.blocks.filter(b => b.taskId === 't1');
            expect(t1Blocks.length).toBe(2); // The locked one + the new one
            expect(t1Blocks.find(b => b.isLocked)).toBeDefined();
            expect(t1Blocks.find(b => !b.isLocked)?.start.toISOString()).toBe('2026-10-14T10:00:00.000Z');
        });
    });
    describe('10. DETERMINISM', () => {
        it('Produces identical results 100 times', () => {
            const t1 = createTask('t1', 180, horizonEnd);
            const t2 = createTask('t2', 90, horizonEnd);
            const firstRun = (0, rescheduler_1.runReschedulerPipeline)([t1, t2], constraints, [], [], horizonStart, horizonEnd, now);
            const firstStr = JSON.stringify(firstRun.blocks);
            for (let i = 0; i < 100; i++) {
                const run = (0, rescheduler_1.runReschedulerPipeline)([t1, t2], constraints, [], [], horizonStart, horizonEnd, now);
                expect(JSON.stringify(run.blocks)).toBe(firstStr);
            }
        });
    });
    describe('14. VALIDATOR AS FINAL SAFETY NET', () => {
        it('Catches corrupted schedules', () => {
            const t = createTask('t1', 60, horizonEnd);
            // Negative duration
            const badBlock1 = { taskId: 't1', type: 'TASK', start: now, end: now, durationMinutes: -30, isLocked: false };
            expect((0, validator_1.validateSchedule)([badBlock1], constraints, [], [t])).toBe(false);
            // Sleep overlap
            const badBlock2 = { taskId: 't1', type: 'TASK', start: new Date('2026-10-14T23:30:00.000Z'), end: new Date('2026-10-15T00:30:00.000Z'), durationMinutes: 60, isLocked: false };
            expect((0, validator_1.validateSchedule)([badBlock2], constraints, [], [t])).toBe(false);
            // Exceeds remaining
            const badBlock3 = { taskId: 't1', type: 'TASK', start: now, end: new Date('2026-10-14T10:00:00.000Z'), durationMinutes: 120, isLocked: false };
            expect((0, validator_1.validateSchedule)([badBlock3], constraints, [], [t])).toBe(false);
            // Overlaps fixed
            const fixed = [{ id: 'f1', start: now, end: new Date('2026-10-14T09:00:00.000Z') }];
            const badBlock4 = { taskId: 't1', type: 'TASK', start: new Date('2026-10-14T08:30:00.000Z'), end: new Date('2026-10-14T09:30:00.000Z'), durationMinutes: 60, isLocked: false };
            expect((0, validator_1.validateSchedule)([badBlock4], constraints, fixed, [t])).toBe(false);
            // Deadline violation
            const badBlock5 = { taskId: 't1', type: 'TASK', start: new Date('2026-10-22T08:30:00.000Z'), end: new Date('2026-10-22T09:30:00.000Z'), durationMinutes: 60, isLocked: false };
            expect((0, validator_1.validateSchedule)([badBlock5], constraints, [], [t])).toBe(false);
        });
    });
    describe('11. PROPERTY / RANDOMIZED TESTING', () => {
        it('Generates valid schedules for 50 randomized inputs', () => {
            const lcg = new LCG(12345);
            for (let iter = 0; iter < 50; iter++) {
                const numTasks = lcg.nextInt(1, 15);
                const tasks = [];
                for (let i = 0; i < numTasks; i++) {
                    const dur = lcg.nextInt(1, 10) * 30; // 30m to 5h
                    const deadlineOffset = lcg.nextInt(1, 48) * 3600000; // 1 to 48 hours
                    tasks.push(createTask(`r${i}`, dur, new Date(now.getTime() + deadlineOffset)));
                }
                const res = (0, rescheduler_1.runReschedulerPipeline)(tasks, constraints, [], [], horizonStart, horizonEnd, now);
                // Assert invariants via validator
                const valid = (0, validator_1.validateSchedule)(res.blocks, constraints, [], tasks);
                expect(valid).toBe(true);
            }
        });
    });
    describe('15. BUG REGRESSION TESTS', () => {
        it('Placement Overscheduling Regression', () => {
            // 10 hours capacity. Task needs 1 hour. It must NOT take all 10 hours!
            const t = createTask('t1', 60, horizonEnd);
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], constraints, [], [], horizonStart, horizonEnd, now);
            const duration = res.blocks.reduce((acc, b) => acc + b.durationMinutes, 0);
            expect(duration).toBe(60);
        });
        it('Timezone Drift Regression (UTC)', () => {
            // Verify sleep parsing strictly honors UTC
            const localNow = new Date('2026-10-14T00:00:00.000Z');
            const t = createTask('t1', 180, horizonEnd);
            const res = (0, rescheduler_1.runReschedulerPipeline)([t], constraints, [], [], horizonStart, horizonEnd, localNow);
            expect(res.blocks[0].start.toISOString()).toBe('2026-10-14T06:00:00.000Z');
        });
    });
});
//# sourceMappingURL=scheduler.extended.test.js.map