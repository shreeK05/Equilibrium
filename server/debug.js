"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const rescheduler_1 = require("./src/scheduler/rescheduler");
const now = new Date('2026-10-14T08:00:00.000Z');
const horizonStart = new Date('2026-10-14T00:00:00.000Z');
const customEnd = new Date('2026-10-14T11:00:00.000Z');
const tasks = [
    { id: 'A', remainingMinutes: 150, estimateMinutes: 150, completedMinutes: 0, remainingMinutes: 150, deadline: customEnd, academicWeight: 0.5, teamImpact: 0, cognitiveLoad: 'LOW', deferralCount: 0 },
    { id: 'B', remainingMinutes: 90, estimateMinutes: 90, completedMinutes: 0, remainingMinutes: 90, deadline: customEnd, academicWeight: 0.4, teamImpact: 0, cognitiveLoad: 'LOW', deferralCount: 0 },
    { id: 'C', remainingMinutes: 90, estimateMinutes: 90, completedMinutes: 0, remainingMinutes: 90, deadline: customEnd, academicWeight: 0.4, teamImpact: 0, cognitiveLoad: 'LOW', deferralCount: 0 }
];
const constraints = { sleepStart: '23:00', sleepEnd: '06:00', minSleepHours: 7.0, peakEnergyWindows: [] };
const res = (0, rescheduler_1.runReschedulerPipeline)(tasks, constraints, [], [], horizonStart, customEnd, now);
console.log('Result blocks:', res.blocks.map(b => b.taskId));
console.log('Logs:', res.logs);
//# sourceMappingURL=debug.js.map