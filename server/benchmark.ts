import { runReschedulerPipeline } from './src/scheduler/rescheduler';
import { TaskInput, ConstraintInput } from './src/scheduler/types';
import { performance } from 'perf_hooks';

class LCG {
  private seed: number;
  constructor(seed: number) { this.seed = seed; }
  next(): number {
    this.seed = (this.seed * 1664525 + 1013904223) % 4294967296;
    return this.seed / 4294967296;
  }
  nextInt(min: number, max: number): number {
    return Math.floor(this.next() * (max - min + 1)) + min;
  }
}

const constraints: ConstraintInput = {
  sleepStart: '23:00',
  sleepEnd: '06:00',
  minSleepHours: 7.0,
  peakEnergyWindows: []
};

function runBenchmark(name: string, taskCount: number, days: number) {
  const lcg = new LCG(42);
  const now = new Date('2026-10-14T08:00:00.000Z');
  const horizonStart = new Date('2026-10-14T00:00:00.000Z');
  const horizonEnd = new Date(horizonStart.getTime() + days * 24 * 3600000);

  const tasks: TaskInput[] = [];
  for(let i=0; i<taskCount; i++) {
    const dur = lcg.nextInt(1, 10) * 30; 
    const deadlineOffsetDays = lcg.nextInt(1, days);
    const deadline = new Date(now.getTime() + deadlineOffsetDays * 24 * 3600000);
    tasks.push({
      id: `t${i}`, estimateMinutes: dur, completedMinutes: 0, remainingMinutes: dur,
      deadline, academicWeight: 0.5, teamImpact: 0, cognitiveLoad: 'LOW', deferralCount: 0
    });
  }

  const t0 = performance.now();
  runReschedulerPipeline(tasks, constraints, [], [], horizonStart, horizonEnd, now);
  const t1 = performance.now();
  
  console.log(`Benchmark [${name}]: ${(t1 - t0).toFixed(2)} ms`);
}

console.log('--- PERFORMANCE BENCHMARKS ---');
runBenchmark('Case 1: 3 tasks / 5 days', 3, 5);
runBenchmark('Case 2: 25 tasks / 7 days', 25, 7);
runBenchmark('Case 3: 50 tasks / 7 days', 50, 7);
runBenchmark('Case 4: 100 tasks / 7 days', 100, 7);
