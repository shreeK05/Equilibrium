/**
 * Minimal in-memory stand-in for PrismaClient, covering exactly the calls made by the
 * register -> exam -> topics -> schedule-topics -> replan flow. Lets regression tests drive
 * the real Express routes and services end-to-end without a Postgres instance.
 */
import { randomUUID } from 'crypto';

type Row = Record<string, any>;

function matches(row: Row, where: Row = {}): boolean {
  return Object.entries(where).every(([key, cond]) => {
    if (cond && typeof cond === 'object' && !(cond instanceof Date)) {
      if ('notIn' in cond) return !cond.notIn.includes(row[key]);
      if ('in' in cond) return cond.in.includes(row[key]);
      if ('not' in cond) return row[key] !== cond.not;
      return true;
    }
    return row[key] === cond;
  });
}

function sortBy(rows: Row[], orderBy?: Row | Row[]): Row[] {
  if (!orderBy) return rows;
  const orders = Array.isArray(orderBy) ? orderBy : [orderBy];
  return [...rows].sort((a, b) => {
    for (const o of orders) {
      const [k, dir] = Object.entries(o)[0] as [string, string];
      const av = a[k] instanceof Date ? a[k].getTime() : a[k];
      const bv = b[k] instanceof Date ? b[k].getTime() : b[k];
      if (av < bv) return dir === 'asc' ? -1 : 1;
      if (av > bv) return dir === 'asc' ? 1 : -1;
    }
    return 0;
  });
}

function applyUpdate(row: Row, data: Row) {
  for (const [k, v] of Object.entries(data)) {
    if (v && typeof v === 'object' && 'increment' in v) row[k] = (row[k] ?? 0) + v.increment;
    else if (v && typeof v === 'object' && 'set' in v) row[k] = v.set;
    else row[k] = v;
  }
  row.updatedAt = new Date();
}

export function createFakePrisma() {
  const db: Record<string, Row[]> = {
    user: [], userConstraint: [], subject: [], exam: [], examTopic: [], task: [],
    fixedCommitment: [], scheduleVersion: [], scheduleBlock: [], decisionLog: [],
    disruptionEvent: [], focusSession: [], taskProgressOperation: [],
  };

  const now = () => new Date();
  const withTopics = (exam: Row, include?: Row) => {
    if (!exam) return exam;
    const out: Row = { ...exam };
    if (include?.topics) out.topics = sortBy(db.examTopic.filter(t => t.examId === exam.id), { createdAt: 'asc' });
    if (include?.subject) out.subject = null;
    return out;
  };
  const withBlocks = (v: Row, include?: Row) => {
    if (!v) return v;
    const out: Row = { ...v };
    if (include?.blocks) out.blocks = db.scheduleBlock.filter(b => b.versionId === v.id);
    if (include?.decisionLogs) out.decisionLogs = db.decisionLog.filter(l => l.versionId === v.id);
    return out;
  };

  const client: any = {
    __db: db,
    user: {
      // Mirrors the LEGACY column default ("UTC") on purpose: code must set timezone explicitly,
      // so the regression test stays valid even if the schema default were ever reverted.
      create: async ({ data }: any) => {
        const row = { id: randomUUID(), timezone: 'UTC', tokenVersion: 0, themePreference: 'system',
          createdAt: now(), updatedAt: now(), ...data };
        if (row.timezone === undefined) row.timezone = 'UTC';
        db.user.push(row);
        return { ...row };
      },
      findUnique: async ({ where }: any) => db.user.find(u => matches(u, where)) ?? null,
      update: async ({ where, data }: any) => { const u = db.user.find(r => matches(r, where))!; applyUpdate(u, data); return u; },
    },
    userConstraint: {
      findUnique: async ({ where }: any) => db.userConstraint.find(c => matches(c, where)) ?? null,
      upsert: async ({ where, create, update }: any) => {
        const existing = db.userConstraint.find(c => matches(c, where));
        if (existing) { applyUpdate(existing, update); return existing; }
        const { user, ...rest } = create;
        const row = { id: randomUUID(), userId: user?.connect?.id ?? where.userId, ...rest };
        db.userConstraint.push(row);
        return row;
      },
    },
    subject: {
      createMany: async ({ data }: any) => {
        for (const d of data) db.subject.push({ id: randomUUID(), createdAt: now(), updatedAt: now(), ...d });
        return { count: data.length };
      },
      findFirst: async ({ where }: any) => db.subject.find(s => matches(s, where)) ?? null,
    },
    exam: {
      create: async ({ data, include }: any) => {
        const row = { id: randomUUID(), createdAt: now(), updatedAt: now(), venue: null, subjectId: null, ...data };
        db.exam.push(row);
        return withTopics(row, include);
      },
      findFirst: async ({ where, include }: any) => withTopics(db.exam.find(e => matches(e, where)) as Row, include) ?? null,
    },
    examTopic: {
      create: async ({ data }: any) => {
        const row = { id: randomUUID(), isCompleted: false, linkedTaskId: null, createdAt: new Date(Date.now() + db.examTopic.length), updatedAt: now(), ...data };
        db.examTopic.push(row);
        return row;
      },
      update: async ({ where, data }: any) => { const t = db.examTopic.find(r => matches(r, where))!; applyUpdate(t, data); return t; },
    },
    task: {
      create: async ({ data }: any) => {
        const row = { id: randomUUID(), completedMinutes: 0, actualMinutes: data.actualMinutes ?? 0,
          remainingMinutes: data.remainingMinutes ?? (data.status === 'COMPLETED' ? 0 : data.estimateMinutes),
          scheduledMinutes: 0, dailyTargetMinutes: null,
          deferralCount: 0, status: 'PENDING', teamImpactWeight: 0, academicWeight: 0.5, cognitiveLoad: 'MEDIUM',
          createdAt: now(), updatedAt: now(), ...data,
          deadline: data.deadline instanceof Date ? data.deadline : new Date(data.deadline) };
        db.task.push(row);
        return { ...row };
      },
      findUnique: async ({ where }: any) => db.task.find(t => matches(t, where)) ?? null,
      findFirst: async ({ where }: any) => db.task.find(t => matches(t, where)) ?? null,
      findMany: async ({ where, orderBy }: any = {}) => sortBy(db.task.filter(t => matches(t, where)), orderBy).map(t => ({ ...t })),
      update: async ({ where, data }: any) => { const t = db.task.find(r => matches(r, where))!; applyUpdate(t, data); return { ...t }; },
      updateMany: async ({ where, data }: any) => {
        const matching = db.task.filter(t => matches(t, where));
        matching.forEach(t => applyUpdate(t, data));
        return { count: matching.length };
      },
      delete: async ({ where }: any) => {
        const idx = db.task.findIndex(t => matches(t, where));
        return idx !== -1 ? db.task.splice(idx, 1)[0] : null;
      },
    },
    fixedCommitment: {
      findMany: async ({ where }: any = {}) => db.fixedCommitment.filter(f => f.userId === where?.userId && f.isActive !== false),
    },
    scheduleVersion: {
      findFirst: async ({ where, orderBy, include }: any) => {
        const rows = sortBy(db.scheduleVersion.filter(v => matches(v, where)), orderBy);
        return rows[0] ? withBlocks(rows[0], include) : null;
      },
      create: async ({ data, include }: any) => {
        const { blocks, decisionLogs, ...rest } = data;
        const version = { id: randomUUID(), algorithmVersion: '1.0.0', generatedAt: new Date(Date.now() + db.scheduleVersion.length), ...rest };
        db.scheduleVersion.push(version);
        for (const b of blocks?.create ?? []) db.scheduleBlock.push({ id: randomUUID(), versionId: version.id, isCompleted: false, ...b });
        for (const l of decisionLogs?.create ?? []) db.decisionLog.push({ id: randomUUID(), versionId: version.id, ...l });
        return withBlocks(version, include);
      },
    },
    scheduleBlock: {
      findMany: async ({ where }: any) => db.scheduleBlock.filter(b => matches(b, where)),
      updateMany: async ({ where, data }: any) => {
        const matching = db.scheduleBlock.filter(b => matches(b, where));
        matching.forEach(b => applyUpdate(b, data));
        return { count: matching.length };
      },
    },
    disruptionEvent: {
      create: async ({ data }: any) => {
        const row = { id: randomUUID(), detectedAt: now(), ...data };
        db.disruptionEvent.push(row);
        return row;
      },
      findMany: async ({ where }: any = {}) => db.disruptionEvent.filter(e => matches(e, where)),
    },
    focusSession: {
      create: async ({ data, include }: any) => {
        const row = { id: randomUUID(), elapsedSeconds: 0, totalPausedMs: 0, startedAt: now(), notes: null, ...data };
        db.focusSession.push(row);
        const res: Row = { ...row };
        if (include?.task && row.taskId) {
          const t = db.task.find(x => x.id === row.taskId);
          if (t) res.task = { id: t.id, title: t.title, estimateMinutes: t.estimateMinutes, completedMinutes: t.completedMinutes, actualMinutes: t.actualMinutes, remainingMinutes: t.remainingMinutes, status: t.status };
        }
        return res;
      },
      findFirst: async ({ where, include }: any) => {
        const row = db.focusSession.find(s => matches(s, where));
        if (!row) return null;
        const res: Row = { ...row };
        if (include?.task && row.taskId) {
          const t = db.task.find(x => x.id === row.taskId);
          if (t) res.task = { id: t.id, title: t.title, estimateMinutes: t.estimateMinutes, completedMinutes: t.completedMinutes, actualMinutes: t.actualMinutes, remainingMinutes: t.remainingMinutes, status: t.status };
        }
        return res;
      },
      findMany: async ({ where, orderBy, take }: any = {}) => {
        let rows = sortBy(db.focusSession.filter(s => matches(s, where)), orderBy);
        if (take) rows = rows.slice(0, take);
        return rows.map(s => ({ ...s }));
      },
      update: async ({ where, data, include }: any) => {
        const s = db.focusSession.find(r => matches(r, where))!;
        applyUpdate(s, data);
        const res: Row = { ...s };
        if (include?.task && s.taskId) {
          const t = db.task.find(x => x.id === s.taskId);
          if (t) res.task = { id: t.id, title: t.title, estimateMinutes: t.estimateMinutes, completedMinutes: t.completedMinutes, actualMinutes: t.actualMinutes, remainingMinutes: t.remainingMinutes, status: t.status };
        }
        return res;
      },
      updateMany: async ({ where, data }: any) => {
        const matching = db.focusSession.filter(s => matches(s, where));
        matching.forEach(s => applyUpdate(s, data));
        return { count: matching.length };
      },
    },
    taskProgressOperation: {
      findUnique: async ({ where }: any) => db.taskProgressOperation.find(op => matches(op, where)) ?? null,
      findFirst: async ({ where }: any) => db.taskProgressOperation.find(op => matches(op, where)) ?? null,
      create: async ({ data }: any) => {
        const existing = db.taskProgressOperation.find(op => op.operationId === data.operationId);
        if (existing) {
          const err: any = new Error('Unique constraint failed on the fields: (`operationId`)');
          err.code = 'P2002';
          throw err;
        }
        const row = { id: randomUUID(), createdAt: now(), ...data };
        db.taskProgressOperation.push(row);
        return { ...row };
      },
      findMany: async ({ where }: any = {}) => db.taskProgressOperation.filter(op => matches(op, where)).map(op => ({ ...op })),
    },
  };
  // Interactive transactions: executed one at a time (a simple lock) and rolled back on error by
  // restoring a row-level snapshot. NOTE: this models atomicity/rollback and SERIALIZED isolation
  // only. It does NOT model PostgreSQL READ COMMITTED interleavings, row locks or lock waits, so
  // passing tests here are not evidence of real-database concurrency behaviour.
  let txLock: Promise<void> = Promise.resolve();
  const snapshot = () => Object.fromEntries(Object.entries(db).map(([k, rows]) => [k, rows.map(r => ({ ...r }))]));
  const restore = (snap: Record<string, Row[]>) => {
    for (const [k, rows] of Object.entries(snap)) { db[k].length = 0; db[k].push(...rows); }
  };
  client.$transaction = async (arg: any) => {
    if (typeof arg !== 'function') return Promise.all(arg);
    const previous = txLock;
    let release!: () => void;
    txLock = new Promise<void>(resolve => { release = resolve; });
    await previous;
    const snap = snapshot();
    try {
      return await arg(client);
    } catch (err) {
      restore(snap);
      throw err;
    } finally {
      release();
    }
  };
  client.$disconnect = async () => {};
  return client;
}
