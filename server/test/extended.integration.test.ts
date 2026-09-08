import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/db';

describe('Extended Integration API Tests (Focus Sessions, Exams, Subjects, Profile)', () => {
  let authToken: string;
  let userId: string;

  beforeAll(async () => {
    // Clear and create a test user
    await prisma.user.deleteMany({});
    
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'test_extended@example.com',
        password: 'password123',
        name: 'Extended Tester',
      });
    
    authToken = res.body.token;
    userId = res.body.user.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({});
    await prisma.$disconnect();
  });

  // Profile endpoints
  describe('Profile API', () => {
    it('should fetch the user profile', async () => {
      const res = await request(app)
        .get('/api/v1/profile')
        .set('Authorization', `Bearer ${authToken}`);
      
      expect(res.status).toBe(200);
      expect(res.body.name).toBeNull();
      expect(res.body.email).toBe('test_extended@example.com');
    });

    it('should update the user profile', async () => {
      const res = await request(app)
        .patch('/api/v1/profile')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          name: 'Extended Tester',
          college: 'Test University',
          themePreference: 'dark'
        });
      
      expect(res.status).toBe(200);
      expect(res.body.name).toBe('Extended Tester');
      expect(res.body.college).toBe('Test University');
      expect(res.body.themePreference).toBe('dark');
    });
  });

  // Subjects endpoints
  describe('Subjects API', () => {
    let subjectId: string;

    it('should create a new subject', async () => {
      const res = await request(app)
        .post('/api/v1/subjects')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          name: 'Computer Science',
          color: '#FF0000'
        });
      
      expect(res.status).toBe(201);
      expect(res.body.name).toBe('Computer Science');
      subjectId = res.body.id;
    });

    it('should list subjects', async () => {
      const res = await request(app)
        .get('/api/v1/subjects')
        .set('Authorization', `Bearer ${authToken}`);
      
      expect(res.status).toBe(200);
      expect(res.body.length).toBeGreaterThan(0);
      expect(res.body[0].name).toBe('Computer Science');
    });
  });

  // Exams endpoints
  describe('Exams API', () => {
    let examId: string;

    it('should create a new exam', async () => {
      const res = await request(app)
        .post('/api/v1/exams')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          title: 'Midterm',
          examDate: new Date(Date.now() + 100000000).toISOString(),
          venue: 'Room 101'
        });
      
      expect(res.status).toBe(201);
      expect(res.body.title).toBe('Midterm');
      examId = res.body.id;
    });

    it('should add a topic to an exam', async () => {
      const res = await request(app)
        .post(`/api/v1/exams/${examId}/topics`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          title: 'Chapter 1',
          estimateMinutes: 60,
          confidence: 0.5,
          topicType: 'LEARNING'
        });
      
      expect(res.status).toBe(201);
      expect(res.body.title).toBe('Chapter 1');
    });
  });

  // Focus Sessions API
  describe('Focus Sessions API', () => {
    let sessionId: string;
    let taskId: string;

    beforeAll(async () => {
      // Create a task to link to the focus session
      const res = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          title: 'Study Chapter 1',
          estimateMinutes: 60,
          deadline: new Date(Date.now() + 100000000).toISOString(),
        });
      taskId = res.body.id;
    });

    it('should start a new focus session', async () => {
      const res = await request(app)
        .post('/api/v1/focus-sessions')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          taskId,
          notes: 'Starting test session'
        });
      
      expect(res.status).toBe(201);
      expect(res.body.taskId).toBe(taskId);
      sessionId = res.body.id;
    });

    it('should end the focus session', async () => {
      const res = await request(app)
        .patch(`/api/v1/focus-sessions/${sessionId}/complete`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          notes: 'Finished early'
        });
      
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('COMPLETED');
      
      // Task should be marked as completed
      const taskRes = await request(app)
        .get(`/api/v1/tasks`)
        .set('Authorization', `Bearer ${authToken}`);
      
      const task = taskRes.body.find((t: any) => t.id === taskId);
      expect(task.status).toBe('IN_PROGRESS');
    });
  });
});
