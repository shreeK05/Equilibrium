"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const rescheduler_1 = require("./src/scheduler/rescheduler");
const types_1 = require("./src/scheduler/types");
const perf_hooks_1 = require("perf_hooks");
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
const constraints = {
    sleepStart: '23:00',
    sleepEnd: '06:00',
    minSleepHours: 7.0,
    peakEnergyWindows: []
};
function runBenchmark(name, taskCount, days) {
    const lcg = new LCG(42);
    const now = new Date('2026-10-14T08:00:00.000Z');
    const horizonStart = new Date('2026-10-14T00:00:00.000Z');
    const horizonEnd = new Date(horizonStart.getTime() + days * 24 * 3600000);
    const tasks = [];
    for (let i = 0; i < taskCount; i++) {
        const dur = lcg.nextInt(1, 10) * 30;
        const deadlineOffsetDays = lcg.nextInt(1, days);
        const deadline = new Date(now.getTime() + deadlineOffsetDays * 24 * 3600000);
        tasks.push({
            id: `t${i}`, estimateMinutes: dur, completedMinutes: 0, remainingMinutes: dur,
            deadline, academicWeight: 0.5, teamImpact: 0, cognitiveLoad: 'LOW', deferralCount: 0
        });
    }
    const t0 = perf_hooks_1.performance.now();
    (0, rescheduler_1.runReschedulerPipeline)(tasks, constraints, [], [], horizonStart, horizonEnd, now);
    const t1 = perf_hooks_1.performance.now();
    console.log(`Benchmark [${name}]: ${(t1 - t0).toFixed(2)} ms`);
}
console.log('--- PERFORMANCE BENCHMARKS ---');
runBenchmark('Case 1: 3 tasks / 5 days', 3, 5);
runBenchmark('Case 2: 25 tasks / 7 days', 25, 7);
runBenchmark('Case 3: 50 tasks / 7 days', 50, 7);
runBenchmark('Case 4: 100 tasks / 7 days', 100, 7);
//# sourceMappingURL=benchmark.js.map