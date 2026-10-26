import { groqClient, GroqClientService } from '../src/services/nlp/groq-client.service';
import { nlpTaskParser, LocalNlpTaskParser } from '../src/services/nlp/nlp-task-parser.service';
import { conversationalRescheduler, ConversationalReschedulerService } from '../src/services/nlp/conversational-rescheduler.service';
import { config } from '../src/config';

describe('Milestone 5 — Groq LLM Integration & Safe Rescheduling Fallbacks', () => {
  const originalKey = config.groqApiKey;

  afterEach(() => {
    config.groqApiKey = originalKey;
    jest.restoreAllMocks();
  });

  describe('1. Missing API Key & Safe Fallback', () => {
    test('when GROQ_API_KEY is empty, groqClient reports not configured and falls back to deterministic parser', async () => {
      config.groqApiKey = '';
      expect(groqClient.isConfigured()).toBe(false);

      const parsed = await nlpTaskParser.parseTaskAsync(
        'Submit AI assignment by Friday 5pm, takes 2 hours, high priority',
        'Asia/Kolkata',
        ['AI', 'DBMS']
      );

      expect(parsed).toBeDefined();
      expect(parsed.parserSource).toBe('deterministic_default');
      expect(parsed.estimateMinutes).toBe(120);
      expect(parsed.cognitiveLoad).toBe('HIGH');
      expect(parsed.subjectName).toBe('AI');
      expect(parsed.deadline).toBeInstanceOf(Date);
    });

    test('conversational rescheduler uses deterministic classifier when GROQ_API_KEY is absent', async () => {
      config.groqApiKey = '';
      const intent = conversationalRescheduler.classifyIntent('Cannot study tonight, feeling exhausted');
      expect(intent.intent).toBe('CANNOT_STUDY_TONIGHT');
    });
  });

  describe('2. Natural-Language Task Parsing via Groq', () => {
    test('correctly parses structured task when Groq returns valid JSON', async () => {
      config.groqApiKey = 'gsk_dummy_test_key';

      const mockResponse = {
        title: 'Distributed Systems Design Doc',
        category: 'Assignment' as const,
        subjectName: 'Distributed Systems',
        estimateMinutes: 180,
        deadlineIso: new Date(Date.now() + 86400000 * 2).toISOString(),
        cognitiveLoad: 'HIGH' as const,
        academicWeight: 0.85,
        confidence: 0.95,
        ambiguities: [],
        isAmbiguous: false
      };

      jest.spyOn(groqClient, 'chatCompletionJson').mockResolvedValueOnce({
        success: true,
        data: mockResponse,
        durationMs: 150,
        modelUsed: 'openai/gpt-oss-20b'
      });

      const parsed = await nlpTaskParser.parseTaskAsync(
        'Finish Distributed Systems design doc by Thursday, 3 hours, very important',
        'Asia/Kolkata',
        ['Distributed Systems']
      );

      expect(parsed.parserSource).toBe('groq');
      expect(parsed.llmModel).toBe('openai/gpt-oss-20b');
      expect(parsed.title).toBe('Distributed Systems Design Doc');
      expect(parsed.estimateMinutes).toBe(180);
      expect(parsed.cognitiveLoad).toBe('HIGH');
      expect(parsed.academicWeight).toBe(0.85);
      expect(parsed.isAmbiguous).toBe(false);
      expect(parsed.deadline).toBeInstanceOf(Date);
    });
  });

  describe('3. Ambiguous Requests & Clarification Questions', () => {
    test('flags ambiguity when deadline is missing or vague', async () => {
      config.groqApiKey = 'gsk_dummy_test_key';

      jest.spyOn(groqClient, 'chatCompletionJson').mockResolvedValueOnce({
        success: true,
        data: {
          title: 'Capstone Project',
          category: 'Project',
          subjectName: null,
          estimateMinutes: 120,
          deadlineIso: null,
          cognitiveLoad: 'MEDIUM',
          academicWeight: 0.6,
          confidence: 0.5,
          ambiguities: [
            { field: 'deadline', question: 'When would you like to finish this capstone task by?' }
          ],
          isAmbiguous: true
        },
        durationMs: 140,
        modelUsed: 'openai/gpt-oss-20b'
      });

      const parsed = await nlpTaskParser.parseTaskAsync('Work on capstone project for 2 hours sometime');

      expect(parsed.parserSource).toBe('groq');
      expect(parsed.isAmbiguous).toBe(true);
      expect(parsed.ambiguities.some(a => a.field === 'deadline')).toBe(true);
      expect(parsed.ambiguities[0].question).toContain('capstone');
    });

    test('flags ambiguity when duration is unstated', async () => {
      config.groqApiKey = 'gsk_dummy_test_key';

      jest.spyOn(groqClient, 'chatCompletionJson').mockResolvedValueOnce({
        success: true,
        data: {
          title: 'Read Biology Chapter 4',
          category: 'Reading',
          subjectName: 'Biology',
          estimateMinutes: null,
          deadlineIso: new Date(Date.now() + 86400000).toISOString(),
          cognitiveLoad: 'LOW',
          academicWeight: 0.4,
          confidence: 0.6,
          ambiguities: [
            { field: 'estimateMinutes', question: 'How much time do you plan to spend reading Chapter 4?' }
          ],
          isAmbiguous: true
        },
        durationMs: 140,
        modelUsed: 'openai/gpt-oss-20b'
      });

      const parsed = await nlpTaskParser.parseTaskAsync('Read Biology Chapter 4 by tomorrow');

      expect(parsed.isAmbiguous).toBe(true);
      expect(parsed.ambiguities.some(a => a.field === 'estimateMinutes')).toBe(true);
    });
  });

  describe('4. Safe Handling of Invalid JSON, Timeouts and Rate Limits', () => {
    test('falls back gracefully to deterministic parser when model returns invalid JSON', async () => {
      config.groqApiKey = 'gsk_dummy_test_key';

      jest.spyOn(groqClient, 'chatCompletionJson').mockResolvedValueOnce({
        success: false,
        durationMs: 200,
        error: { code: 'INVALID_JSON', message: 'Model returned malformed JSON' }
      });

      const parsed = await nlpTaskParser.parseTaskAsync(
        'Submit Physics assignment by tomorrow at 4pm for 90 minutes',
        'Asia/Kolkata',
        ['Physics']
      );

      expect(parsed).toBeDefined();
      expect(parsed.parserSource).toBe('deterministic_fallback');
      expect(parsed.estimateMinutes).toBe(90);
      expect(parsed.deadline).toBeInstanceOf(Date);
    });

    test('falls back gracefully when Groq API times out', async () => {
      config.groqApiKey = 'gsk_dummy_test_key';

      jest.spyOn(groqClient, 'chatCompletionJson').mockResolvedValueOnce({
        success: false,
        durationMs: 8000,
        error: { code: 'TIMEOUT', message: 'Groq request timed out after 8000ms.' }
      });

      const parsed = await nlpTaskParser.parseTaskAsync('Math homework 1 hour by tonight');

      expect(parsed.parserSource).toBe('deterministic_fallback');
      expect(parsed.estimateMinutes).toBe(60);
    });

    test('per-user rate limiter throttles calls exceeding limit and falls back safely', async () => {
      config.groqApiKey = 'gsk_dummy_test_key';
      const client = new GroqClientService();

      // Exhaust limit of 10 requests
      const testUserId = 'test-rate-limit-user';
      for (let i = 0; i < 10; i++) {
        (client as any).checkUserRateLimit(testUserId);
      }

      // 11th call should fail with RATE_LIMITED
      const res = await client.chatCompletionJson(
        [{ role: 'user', content: 'test' }],
        { userId: testUserId }
      );

      expect(res.success).toBe(false);
      expect(res.error?.code).toBe('RATE_LIMITED');
    });
  });

  describe('5. Conversational Rescheduling Safety', () => {
    test('requires explicit confirmation for disruptive changes like CANNOT_STUDY_TONIGHT', async () => {
      config.groqApiKey = 'gsk_dummy_test_key';

      jest.spyOn(groqClient, 'chatCompletionJson').mockResolvedValueOnce({
        success: true,
        data: {
          intent: 'CANNOT_STUDY_TONIGHT',
          interpretation: 'Student is ill and cannot study tonight.',
          summary: 'Canceling tonight study sessions and replanning for tomorrow.',
          isAmbiguous: false,
          isMateriallyDisruptive: true
        },
        durationMs: 160,
        modelUsed: 'openai/gpt-oss-20b'
      });

      // Stub database dependencies
      const fakeUserId = 'usr-test-123';
      const proposal = await conversationalRescheduler.interpretAndPropose(
        fakeUserId,
        'I have a migraine and cannot study tonight'
      );

      expect(proposal.intent).toBe('CANNOT_STUDY_TONIGHT');
      expect(proposal.requiresConfirmation).toBe(true);
      expect(proposal.source).toBe('groq');
    });

    test('identifies vague requests and prompts user for clarification', async () => {
      config.groqApiKey = 'gsk_dummy_test_key';

      jest.spyOn(groqClient, 'chatCompletionJson').mockResolvedValueOnce({
        success: true,
        data: {
          intent: 'GENERAL_RESCHEDULE',
          interpretation: 'Student wants to reschedule something but did not specify which task.',
          summary: 'Awaiting student clarification.',
          isAmbiguous: true,
          clarificationQuestion: 'Which task would you like to move or what time changes would you like to make?',
          isMateriallyDisruptive: false
        },
        durationMs: 150,
        modelUsed: 'openai/gpt-oss-20b'
      });

      const proposal = await conversationalRescheduler.interpretAndPropose(
        'usr-test-123',
        'I need to change something'
      );

      expect(proposal.isAmbiguous).toBe(true);
      expect(proposal.requiresConfirmation).toBe(true);
      expect(proposal.clarificationQuestion).toContain('Which task');
    });
  });
});
