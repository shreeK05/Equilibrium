"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const supertest_1 = __importDefault(require("supertest"));
const app_1 = require("../src/app");
const db_1 = require("../src/db");
let userAToken;
let userAId;
let userBToken;
let taskAId;
let versionId;
beforeAll(async () => {
    // Clean up specific users to avoid parallel test state leakage
    await db_1.prisma.user.deleteMany({
        where: { email: { in: ['userA@test.com', 'userB@test.com'] } }
    });
});
afterAll(async () => {
    await db_1.prisma.user.deleteMany({
        where: { email: { in: ['userA@test.com', 'userB@test.com'] } }
    });
    await db_1.prisma.$disconnect();
});
describe('Equilibrium API Integration Tests', () => {
    describe('1. Authentication & Security', () => {
        it('should register User A successfully', async () => {
            const res = await (0, supertest_1.default)(app_1.app).post('/api/v1/auth/register').send({
                email: 'userA@test.com',
                password: 'password123'
            });
            expect(res.status).toBe(200);
            expect(res.body.token).toBeDefined();
            userAToken = res.body.token;
            userAId = res.body.user.id;
        });
        it('should login User A', async () => {
            const res = await (0, supertest_1.default)(app_1.app).post('/api/v1/auth/login').send({
                email: 'userA@test.com',
                password: 'password123'
            });
            expect(res.status).toBe(200);
            expect(typeof res.body.token).toBe('string');
        });
        it('should register User B for isolation tests', async () => {
            const res = await (0, supertest_1.default)(app_1.app).post('/api/v1/auth/register').send({
                email: 'userB@test.com',
                password: 'password123'
            });
            expect(res.status).toBe(200);
            userBToken = res.body.token;
        });
        it('should reject invalid auth input', async () => {
            const res = await (0, supertest_1.default)(app_1.app).post('/api/v1/auth/register').send({
                email: 'not-an-email',
                password: 'short'
            });
            expect(res.status).toBe(400);
            expect(res.body.error.code).toBe('VALIDATION_ERROR');
        });
    });
    describe('2. Constraints & Tasks API', () => {
        it('should retrieve default constraints for User A', async () => {
            const res = await (0, supertest_1.default)(app_1.app).get('/api/v1/constraints').set('Authorization', `Bearer ${userAToken}`);
            expect(res.status).toBe(200);
            expect(res.body.minSleepHours).toBe(7.0);
        });
        it('should accept valid overnight sleep (23:00 -> 06:00)', async () => {
            const res = await (0, supertest_1.default)(app_1.app).patch('/api/v1/constraints').set('Authorization', `Bearer ${userAToken}`).send({
                minSleepHours: 7.0, sleepStart: '23:00', sleepEnd: '06:00'
            });
            expect(res.status).toBe(200);
        });
        it('should accept valid overnight sleep (22:00 -> 07:00)', async () => {
            const res = await (0, supertest_1.default)(app_1.app).patch('/api/v1/constraints').set('Authorization', `Bearer ${userAToken}`).send({
                minSleepHours: 8.0, sleepStart: '22:00', sleepEnd: '07:00'
            });
            expect(res.status).toBe(200);
        });
        it('should accept valid same-day sleep (08:00 -> 17:00)', async () => {
            const res = await (0, supertest_1.default)(app_1.app).patch('/api/v1/constraints').set('Authorization', `Bearer ${userAToken}`).send({
                minSleepHours: 8.0, sleepStart: '08:00', sleepEnd: '17:00'
            });
            expect(res.status).toBe(200);
        });
        it('should reject ambiguous 23h sleep (08:00 -> 07:00)', async () => {
            const res = await (0, supertest_1.default)(app_1.app).patch('/api/v1/constraints').set('Authorization', `Bearer ${userAToken}`).send({
                minSleepHours: 8.0, sleepStart: '08:00', sleepEnd: '07:00'
            });
            expect(res.status).toBe(400);
            expect(res.body.error.code).toBe('VALIDATION_ERROR');
        });
        it('should reject sleep interval shorter than minSleepHours', async () => {
            const res = await (0, supertest_1.default)(app_1.app).patch('/api/v1/constraints').set('Authorization', `Bearer ${userAToken}`).send({
                minSleepHours: 8.0, sleepStart: '23:00', sleepEnd: '05:00' // 6h sleep
            });
            expect(res.status).toBe(400);
        });
        it('should reject invalid time strings', async () => {
            const res = await (0, supertest_1.default)(app_1.app).patch('/api/v1/constraints').set('Authorization', `Bearer ${userAToken}`).send({
                minSleepHours: 8.0, sleepStart: '25:00', sleepEnd: '05:00'
            });
            expect(res.status).toBe(400);
        });
        it('should reject malformed energy windows', async () => {
            const res = await (0, supertest_1.default)(app_1.app).patch('/api/v1/constraints').set('Authorization', `Bearer ${userAToken}`).send({
                minSleepHours: 8.0, sleepStart: '22:00', sleepEnd: '06:00',
                peakEnergyWindowsJson: '[{"start":"09:00","end":"08:00"}]' // invalid same-day wrap
            });
            expect(res.status).toBe(400);
        });
        it('should create a task for User A', async () => {
            const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
            const res = await (0, supertest_1.default)(app_1.app)
                .post('/api/v1/tasks')
                .set('Authorization', `Bearer ${userAToken}`)
                .send({
                title: 'Math Assignment',
                estimateMinutes: 240,
                deadline,
                academicWeight: 0.9,
                cognitiveLoad: 'HIGH'
            });
            expect(res.status).toBe(201);
            expect(res.body.title).toBe('Math Assignment');
            taskAId = res.body.id;
        });
        it('should securely isolate User A tasks from User B', async () => {
            const res = await (0, supertest_1.default)(app_1.app)
                .get(`/api/v1/tasks/${taskAId}`)
                .set('Authorization', `Bearer ${userBToken}`);
            expect(res.status).toBe(404);
        });
    });
    describe('3. Scheduler Core Integration', () => {
        it('should generate a schedule for User A', async () => {
            const res = await (0, supertest_1.default)(app_1.app)
                .post('/api/v1/schedules/generate')
                .set('Authorization', `Bearer ${userAToken}`);
            expect(res.status).toBe(201);
            expect(res.body.blocks).toBeDefined();
            expect(res.body.decisionLogs).toBeDefined();
            expect(res.body.blocks.length).toBeGreaterThan(0);
            versionId = res.body.id;
        });
        it('should retrieve current schedule', async () => {
            const res = await (0, supertest_1.default)(app_1.app)
                .get('/api/v1/schedules/current')
                .set('Authorization', `Bearer ${userAToken}`);
            expect(res.status).toBe(200);
            expect(res.body.id).toBe(versionId);
        });
        it('should retrieve explainability decisions', async () => {
            const res = await (0, supertest_1.default)(app_1.app)
                .get(`/api/v1/schedules/${versionId}/decisions`)
                .set('Authorization', `Bearer ${userAToken}`);
            expect(res.status).toBe(200);
            expect(Array.isArray(res.body)).toBe(true);
            expect(res.body[0].priorityComponents).toBeDefined();
            expect(res.body[0].reasonCode).toBe('SUCCESS');
        });
    });
    describe('4. Rescheduling Integration', () => {
        it('should simulate disruption and reschedule', async () => {
            // 1. Mark task partially done
            await (0, supertest_1.default)(app_1.app).patch(`/api/v1/tasks/${taskAId}`)
                .set('Authorization', `Bearer ${userAToken}`)
                .send({ completedMinutes: 120 });
            // 2. Lock a past block directly via DB to simulate time passing
            const blockId = (await db_1.prisma.scheduleBlock.findFirst({ where: { versionId } })).id;
            await db_1.prisma.scheduleBlock.update({ where: { id: blockId }, data: { isLocked: true } });
            // 3. Trigger reschedule
            const res = await (0, supertest_1.default)(app_1.app)
                .post(`/api/v1/schedules/${versionId}/reschedule`)
                .set('Authorization', `Bearer ${userAToken}`);
            expect(res.status).toBe(201);
            expect(res.body.triggerType).toBe('DISRUPTION');
            expect(res.body.id).not.toBe(versionId); // Must be a new version
            // The locked block must be in the new version too
            const blocks = res.body.blocks;
            expect(blocks.some((b) => b.isLocked === true)).toBe(true);
        });
    });
    describe('5. Health', () => {
        it('should return health check', async () => {
            const res = await (0, supertest_1.default)(app_1.app).get('/api/v1/health');
            expect(res.status).toBe(200);
            expect(res.body.status).toBe('ok');
        });
    });
});
//# sourceMappingURL=api.test.js.map