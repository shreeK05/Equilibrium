import { nlpTaskParser } from '../src/services/nlp/nlp-task-parser.service';
import { conversationalRescheduler } from '../src/services/nlp/conversational-rescheduler.service';
import { toDate, format } from 'date-fns-tz';

describe('Milestone 2 — Natural-Language Task Creation & Conversational Rescheduling', () => {
  const IST = 'Asia/Kolkata';
  // Reference date: Monday, Oct 26, 2026 10:00 AM IST
  const refDate = toDate('2026-10-26T10:00:00', { timeZone: IST });
  const subjects = ['DBMS', 'Operating Systems', 'Mathematics', 'Computer Networks'];

  describe('1. Natural Language Task Parsing', () => {
    test('Extracts title, subject, duration, priority and relative deadline correctly', () => {
      const text = 'I need to complete my DBMS assignment tomorrow by 5 PM. It will take about 90 minutes and is high priority.';
      const res = nlpTaskParser.parseTask(text, IST, subjects, refDate);

      expect(res.subjectName).toBe('DBMS');
      expect(res.category).toBe('Assignment');
      expect(res.estimateMinutes).toBe(90);
      expect(res.academicWeight).toBeGreaterThanOrEqual(0.8); // High priority
      expect(res.cognitiveLoad).toBe('HIGH');
      expect(res.ambiguities.length).toBe(0);

      // Tomorrow is Oct 27, 2026. 5 PM is 17:00 IST
      expect(res.deadline).toBeDefined();
      const deadlineStr = format(res.deadline!, 'yyyy-MM-dd HH:mm', { timeZone: IST });
      expect(deadlineStr).toBe('2026-10-27 17:00');
    });

    test('Parses fractional hours duration: 1.5 hours -> 90 minutes', () => {
      const text = 'Prep for Operating Systems lab on Friday 3pm for 1.5 hours, urgent';
      const res = nlpTaskParser.parseTask(text, IST, subjects, refDate);

      expect(res.estimateMinutes).toBe(90);
      expect(res.category).toBe('Lab');
      expect(res.academicWeight).toBeGreaterThanOrEqual(0.8);
      expect(res.deadline).toBeDefined();
      const deadlineDay = format(res.deadline!, 'EEEE', { timeZone: IST });
      expect(deadlineDay).toBe('Friday');
    });

    test('Detects missing duration and produces concise ambiguity question', () => {
      const text = 'Finish Mathematics homework tomorrow at 4pm';
      const res = nlpTaskParser.parseTask(text, IST, subjects, refDate);

      expect(res.estimateMinutes).toBeUndefined();
      const durationAmbiguity = res.ambiguities.find(a => a.field === 'estimateMinutes');
      expect(durationAmbiguity).toBeDefined();
      expect(durationAmbiguity?.question).toContain('How long');
    });

    test('Detects missing deadline and produces concise ambiguity question', () => {
      const text = 'Read DBMS Chapter 4 for 45 mins low priority';
      const res = nlpTaskParser.parseTask(text, IST, subjects, refDate);

      expect(res.estimateMinutes).toBe(45);
      expect(res.academicWeight).toBeLessThanOrEqual(0.4); // Low priority
      const deadlineAmbiguity = res.ambiguities.find(a => a.field === 'deadline');
      expect(deadlineAmbiguity).toBeDefined();
      expect(deadlineAmbiguity?.question).toContain('When is this due');
    });

    test('Supports "this weekend" relative deadline', () => {
      const text = 'Computer Networks project 3 hours high priority this weekend';
      const res = nlpTaskParser.parseTask(text, IST, subjects, refDate);

      expect(res.estimateMinutes).toBe(180);
      expect(res.deadline).toBeDefined();
      const deadlineDay = format(res.deadline!, 'EEEE', { timeZone: IST });
      expect(deadlineDay).toBe('Sunday');
    });
  });

  describe('2. Conversational Rescheduling Intent Classification', () => {
    test('Classifies "I am unable to study tonight" -> CANNOT_STUDY_TONIGHT', () => {
      const classification = conversationalRescheduler.classifyIntent("I am unable to study tonight");
      expect(classification.intent).toBe('CANNOT_STUDY_TONIGHT');
    });

    test('Classifies "I couldn\'t finish this task today" -> MISSED_TASK', () => {
      const classification = conversationalRescheduler.classifyIntent("I couldn't finish this task today");
      expect(classification.intent).toBe('MISSED_TASK');
    });

    test('Classifies "Move this assignment to the next available slot" -> MOVE_TO_NEXT_SLOT', () => {
      const classification = conversationalRescheduler.classifyIntent("Move this assignment to the next available slot");
      expect(classification.intent).toBe('MOVE_TO_NEXT_SLOT');
    });

    test('Classifies "I have only one hour free today" -> REDUCED_CAPACITY_TODAY with 1 hour', () => {
      const classification = conversationalRescheduler.classifyIntent("I have only 1 hour free today");
      expect(classification.intent).toBe('REDUCED_CAPACITY_TODAY');
      expect(classification.details?.freeHours).toBe(1);
    });

    test('Classifies "I have an extra college lecture tomorrow" -> EXTRA_CLASS', () => {
      const classification = conversationalRescheduler.classifyIntent("I have an extra college lecture tomorrow");
      expect(classification.intent).toBe('EXTRA_CLASS');
    });
  });
});
