"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const rescheduler_1 = require("../src/scheduler/rescheduler");
const types_1 = require("../src/scheduler/types");
const guard_1 = require("../src/scheduler/guard");
const priority_1 = require("../src/scheduler/priority");
describe('Equilibrium Core Scheduler', () => {
    const now = new Date('2026-10-14T08:00:00.000Z');
    const horizonStart = new Date('2026-10-14T00:00:00.000Z');
    const horizonEnd = new Date('2026-10-15T00:00:00.000Z');
    const constraints = {
        sleepStart: '23:00',
        sleepEnd: '06:00',
        minSleepHours: 7.0,
        peakEnergyWindows: [{ start: '09:00', end: '12:00' }]
    };
    it('A. Sleep Shield Invariant - Never overlaps', () => {
        const tasks = [{
                id: 't1', estimateMinutes: 300, completedMinutes: 0, remainingMinutes: 300,
                deadline: new Date('2026-10-14T23:59:00.000Z'), academicWeight: 1.0, teamImpact: 0, cognitiveLoad: 'MEDIUM', deferralCount: 0
            }];
        const result = (0, rescheduler_1.runReschedulerPipeline)(tasks, constraints, [], [], horizonStart, horizonEnd, now);
        // Assert 0 overlaps with 23:00-06:00
        const sleepStart = new Date('2026-10-14T23:00:00.000Z');
        const sleepEnd = new Date('2026-10-15T06:00:00.000Z');
        for (const b of result.blocks) {
            if (b.type === 'TASK') {
                const overlaps = (0, guard_1.intervalsIntersect)(b.start, b.end, sleepStart, sleepEnd);
                expect(overlaps).toBe(false);
            }
        }
    });
    it('B. Fixed Commitments Protection', () => {
        const fixed = [{
                id: 'f1', start: new Date('2026-10-14T09:00:00.000Z'), end: new Date('2026-10-14T12:00:00.000Z')
            }];
        const tasks = [{
                id: 't1', estimateMinutes: 480, completedMinutes: 0, remainingMinutes: 480,
                deadline: new Date('2026-10-14T22:00:00.000Z'), academicWeight: 1.0, teamImpact: 0, cognitiveLoad: 'MEDIUM', deferralCount: 0
            }];
        const result = (0, rescheduler_1.runReschedulerPipeline)(tasks, constraints, fixed, [], horizonStart, horizonEnd, now);
        for (const b of result.blocks) {
            if (b.type === 'TASK') {
                const overlaps = (0, guard_1.intervalsIntersect)(b.start, b.end, fixed[0].start, fixed[0].end);
                expect(overlaps).toBe(false);
            }
        }
    });
    it('C. Capacity and E. Knapsack Optimal Selection (0/1 Determinism)', () => {
        const customEnd = new Date('2026-10-14T11:00:00.000Z'); // 3 hours available (08:00 to 11:00)
        const tasks = [
            { id: 'A', remainingMinutes: 150, estimateMinutes: 150, completedMinutes: 0, deadline: customEnd, academicWeight: 0.5, teamImpact: 0, cognitiveLoad: 'LOW', deferralCount: 0 },
            { id: 'B', remainingMinutes: 90, estimateMinutes: 90, completedMinutes: 0, deadline: customEnd, academicWeight: 0.4, teamImpact: 0, cognitiveLoad: 'LOW', deferralCount: 0 },
            { id: 'C', remainingMinutes: 90, estimateMinutes: 90, completedMinutes: 0, deadline: customEnd, academicWeight: 0.4, teamImpact: 0, cognitiveLoad: 'LOW', deferralCount: 0 }
        ];
        const result = (0, rescheduler_1.runReschedulerPipeline)(tasks, constraints, [], [], horizonStart, customEnd, now);
        const scheduledIds = result.blocks.map(b => b.taskId);
        expect(scheduledIds).toContain('B');
        expect(scheduledIds).toContain('C');
        expect(scheduledIds).not.toContain('A');
    });
    it('F & G. Splitting and Partial Scheduling', () => {
        const tasks = [{
                id: 'splitMe', estimateMinutes: 300, completedMinutes: 0, remainingMinutes: 300, // 5 hours
                deadline: new Date('2026-10-14T23:59:00.000Z'), academicWeight: 1.0, teamImpact: 0, cognitiveLoad: 'MEDIUM', deferralCount: 0
            }];
        const result = (0, rescheduler_1.runReschedulerPipeline)(tasks, constraints, [], [], horizonStart, horizonEnd, now);
        const chunks = result.blocks.filter(b => b.taskId === 'splitMe');
        expect(chunks.length).toBeGreaterThan(1);
        expect(chunks[0].durationMinutes).toBeLessThanOrEqual(240); // Max 4h chunk logic
        const log = result.logs.find(l => l.taskId === 'splitMe');
        expect(log).toBeDefined();
        // It should fit perfectly since we have 15h capacity
        expect(log?.decisionType).toBe('FULLY_SCHEDULED');
    });
    it('D. Priority Engine components breakdown', () => {
        const task = {
            id: 'P', estimateMinutes: 60, completedMinutes: 0, remainingMinutes: 60,
            deadline: new Date('2026-10-14T09:00:00.000Z'), academicWeight: 0.8, teamImpact: 0.5, cognitiveLoad: 'LOW', deferralCount: 2
        };
        const p = (0, priority_1.calculatePriority)(task, now); // 1 hour to deadline
        expect(p.components.academic).toBeCloseTo(1.6);
        expect(p.components.urgency).toBeCloseTo(0.75); // 1.5 * (1/2)
        expect(p.components.team).toBeCloseTo(0.5);
        expect(p.components.debt).toBeCloseTo(0.4); // 2/5
        expect(p.score).toBeCloseTo(3.25);
    });
    it('Phase 2 Acceptance Test - E2E Disruption', () => {
        const fixed = [{
                id: 'class', start: new Date('2026-10-14T09:00:00.000Z'), end: new Date('2026-10-14T12:00:00.000Z')
            }];
        const tasks = [
            { id: 'DSA', estimateMinutes: 180, completedMinutes: 0, remainingMinutes: 180, deadline: new Date('2026-10-15T00:00:00.000Z'), academicWeight: 1.0, teamImpact: 0, cognitiveLoad: 'HIGH', deferralCount: 0 },
            { id: 'Project', estimateMinutes: 240, completedMinutes: 0, remainingMinutes: 240, deadline: new Date('2026-10-16T00:00:00.000Z'), academicWeight: 0.5, teamImpact: 1.0, cognitiveLoad: 'MEDIUM', deferralCount: 0 },
            { id: 'Reading', estimateMinutes: 120, completedMinutes: 0, remainingMinutes: 120, deadline: new Date('2026-10-18T00:00:00.000Z'), academicWeight: 0.2, teamImpact: 0, cognitiveLoad: 'LOW', deferralCount: 0 }
        ];
        const t0 = performance.now();
        const result1 = (0, rescheduler_1.runReschedulerPipeline)(tasks, constraints, fixed, [], horizonStart, new Date('2026-10-19T00:00:00.000Z'), now);
        const t1 = performance.now();
        expect(result1.blocks.length).toBeGreaterThan(0);
        // Simulate disruption: Project took 2 extra hours.
        // We lock the completed blocks.
        const lockedBlocks = result1.blocks.map(b => ({ ...b, isLocked: true }));
        const tasksDisrupted = [
            { id: 'Project', estimateMinutes: 360, completedMinutes: 240, remainingMinutes: 120, deadline: new Date('2026-10-16T00:00:00.000Z'), academicWeight: 0.5, teamImpact: 1.0, cognitiveLoad: 'MEDIUM', deferralCount: 0 },
            { id: 'DSA', estimateMinutes: 180, completedMinutes: 180, remainingMinutes: 0, deadline: new Date('2026-10-15T00:00:00.000Z'), academicWeight: 1.0, teamImpact: 0, cognitiveLoad: 'HIGH', deferralCount: 0 } // DSA finished
        ];
        const newNow = new Date('2026-10-14T18:00:00.000Z'); // Fast forward
        const result2 = (0, rescheduler_1.runReschedulerPipeline)(tasksDisrupted, constraints, fixed, lockedBlocks, horizonStart, new Date('2026-10-19T00:00:00.000Z'), newNow);
        // Validate Project gets extra time scheduled without destroying previous blocks
        const projectBlocks = result2.blocks.filter(b => b.taskId === 'Project');
        expect(projectBlocks.length).toBeGreaterThanOrEqual(1);
        console.log(`Performance: E2E Pipeline ran in ${(t1 - t0).toFixed(2)} ms for 3 tasks over 5 days.`);
    });
});
//# sourceMappingURL=scheduler.test.js.map