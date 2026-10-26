import { toDate, format } from 'date-fns-tz';
import { z } from 'zod';
import { groqClient } from './groq-client.service';

export interface ParsedTaskResult {
  title: string;
  subjectName?: string;
  category?: string;
  deadline?: Date;
  deadlineIso?: string;
  estimateMinutes?: number;
  academicWeight: number; // 0.0 - 1.0
  cognitiveLoad: 'LOW' | 'MEDIUM' | 'HIGH';
  confidence: number; // 0.0 - 1.0
  ambiguities: Array<{ field: string; question: string }>;
  rawText: string;
  parserSource?: 'groq' | 'deterministic_fallback' | 'deterministic_default';
  isAmbiguous?: boolean;
  llmModel?: string;
}

export interface INlpTaskParser {
  parseTask(text: string, userTimezone: string, existingSubjects?: string[], referenceDate?: Date): ParsedTaskResult;
  parseTaskAsync(text: string, userTimezone?: string, existingSubjects?: string[], referenceDate?: Date, userId?: string): Promise<ParsedTaskResult>;
}

const groqTaskJsonSchema = z.object({
  title: z.string().min(1).max(255),
  category: z.enum(['Assignment', 'Lab', 'Revision', 'Project', 'Practice', 'Reading']).default('Assignment'),
  subjectName: z.string().nullable().optional(),
  estimateMinutes: z.number().int().positive().max(1440).nullable().optional(),
  deadlineIso: z.string().datetime().nullable().optional(),
  cognitiveLoad: z.enum(['LOW', 'MEDIUM', 'HIGH']).default('MEDIUM'),
  academicWeight: z.number().min(0).max(1).default(0.5),
  confidence: z.number().min(0).max(1).default(0.8),
  ambiguities: z.array(z.object({
    field: z.string(),
    question: z.string()
  })).default([]),
  isAmbiguous: z.boolean().default(false)
});

export class LocalNlpTaskParser implements INlpTaskParser {
  /**
   * Synchronous deterministic task parser (always available fallback)
   */
  parseTask(
    text: string,
    userTimezone: string = 'Asia/Kolkata',
    existingSubjects: string[] = [],
    referenceDate: Date = new Date()
  ): ParsedTaskResult {
    return this.parseTaskDeterministic(text, userTimezone, existingSubjects, referenceDate, 'deterministic_default');
  }

  /**
   * Asynchronous task parser with Groq LLM integration and deterministic fallback
   */
  async parseTaskAsync(
    text: string,
    userTimezone: string = 'Asia/Kolkata',
    existingSubjects: string[] = [],
    referenceDate: Date = new Date(),
    userId?: string
  ): Promise<ParsedTaskResult> {
    const raw = text.trim();

    // If Groq is not configured, directly use deterministic parser
    if (!groqClient.isConfigured()) {
      return this.parseTaskDeterministic(raw, userTimezone, existingSubjects, referenceDate, 'deterministic_default');
    }

    try {
      const nowIso = referenceDate.toISOString();
      const existingSubjectsStr = existingSubjects.length > 0 ? existingSubjects.join(', ') : 'None registered';

      const systemPrompt = `You are Equilibrium's natural-language academic task extraction engine.
Extract task properties from the student's natural-language statement into structured JSON.
Current Reference Time: ${nowIso}
Student Timezone: ${userTimezone}
Student's Registered Subjects: ${existingSubjectsStr}

Return a valid JSON object matching this schema:
{
  "title": "Clean concise task title without temporal prepositions",
  "category": "Assignment" | "Lab" | "Revision" | "Project" | "Practice" | "Reading",
  "subjectName": "matched subject or null",
  "estimateMinutes": integer minutes or null if unstated,
  "deadlineIso": "ISO 8601 string in UTC or null if unstated or ambiguous",
  "cognitiveLoad": "LOW" | "MEDIUM" | "HIGH",
  "academicWeight": number between 0.0 and 1.0,
  "confidence": number between 0.0 and 1.0,
  "ambiguities": [
    { "field": "estimateMinutes" | "deadline" | "title", "question": "friendly clarification question" }
  ],
  "isAmbiguous": boolean
}

Rules:
1. If the deadline is relative (e.g. 'tomorrow at 5pm', 'by Friday 6pm'), calculate the exact ISO datetime considering the reference time and timezone.
2. If deadline is vague or missing (e.g. 'soon', 'later'), set deadlineIso to null and add a clarification question in ambiguities.
3. If estimate duration is missing, set estimateMinutes to null and add a clarification question in ambiguities.
4. If either deadline or duration is missing/vague, set isAmbiguous: true.
5. Only return JSON. Never invent facts.`;

      const response = await groqClient.chatCompletionJson(
        [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: raw }
        ],
        { userId, timeoutMs: 7000 }
      );

      if (!response.success || !response.data) {
        // Fall back seamlessly to deterministic parser
        return this.parseTaskDeterministic(raw, userTimezone, existingSubjects, referenceDate, 'deterministic_fallback');
      }

      // Validate LLM output with Zod schema
      const validation = groqTaskJsonSchema.safeParse(response.data);
      if (!validation.success) {
        return this.parseTaskDeterministic(raw, userTimezone, existingSubjects, referenceDate, 'deterministic_fallback');
      }

      const parsedData = validation.data;
      let deadline: Date | undefined;
      const ambiguities = [...parsedData.ambiguities];

      if (parsedData.deadlineIso) {
        const candidateDate = new Date(parsedData.deadlineIso);
        if (isNaN(candidateDate.getTime()) || candidateDate < referenceDate) {
          // If deadline is in the past or invalid date
          deadline = undefined;
          ambiguities.push({
            field: 'deadline',
            question: 'The specified deadline appears to be in the past. When is this task due?'
          });
        } else {
          deadline = candidateDate;
        }
      } else if (!ambiguities.some(a => a.field === 'deadline')) {
        ambiguities.push({
          field: 'deadline',
          question: 'When is this task due? (e.g., tomorrow at 5 PM or Friday)'
        });
      }

      if (!parsedData.estimateMinutes && !ambiguities.some(a => a.field === 'estimateMinutes')) {
        ambiguities.push({
          field: 'estimateMinutes',
          question: 'How long do you estimate this task will take? (e.g., 60 minutes or 2 hours)'
        });
      }

      const isAmbiguous = parsedData.isAmbiguous || ambiguities.length > 0 || !deadline || !parsedData.estimateMinutes;

      return {
        title: parsedData.title || raw,
        subjectName: parsedData.subjectName || undefined,
        category: parsedData.category,
        deadline,
        deadlineIso: deadline?.toISOString(),
        estimateMinutes: parsedData.estimateMinutes || undefined,
        academicWeight: parsedData.academicWeight,
        cognitiveLoad: parsedData.cognitiveLoad,
        confidence: parsedData.confidence,
        ambiguities,
        isAmbiguous,
        rawText: raw,
        parserSource: 'groq',
        llmModel: response.modelUsed
      };
    } catch {
      return this.parseTaskDeterministic(raw, userTimezone, existingSubjects, referenceDate, 'deterministic_fallback');
    }
  }

  /**
   * Internal deterministic rule-based extractor
   */
  private parseTaskDeterministic(
    text: string,
    userTimezone: string = 'Asia/Kolkata',
    existingSubjects: string[] = [],
    referenceDate: Date = new Date(),
    source: 'deterministic_default' | 'deterministic_fallback' = 'deterministic_default'
  ): ParsedTaskResult {
    const raw = text.trim();
    const ambiguities: Array<{ field: string; question: string }> = [];

    // 1. Duration extraction
    let estimateMinutes: number | undefined;
    const minMatch = raw.match(/(\d+)\s*(?:m|min|mins|minutes?)\b/i);
    const hrMatch = raw.match(/([\d.]+)\s*(?:h|hr|hrs|hours?)\b/i);

    if (hrMatch) {
      estimateMinutes = Math.round(parseFloat(hrMatch[1]) * 60);
    } else if (minMatch) {
      estimateMinutes = parseInt(minMatch[1], 10);
    }

    if (!estimateMinutes || estimateMinutes <= 0) {
      ambiguities.push({
        field: 'estimateMinutes',
        question: 'How long do you estimate this task will take? (e.g., 60 minutes or 1.5 hours)'
      });
    }

    // 2. Priority & Cognitive load extraction
    let academicWeight = 0.5;
    let cognitiveLoad: 'LOW' | 'MEDIUM' | 'HIGH' = 'MEDIUM';

    if (/\b(urgent|high priority|critical|asap|important|exam|test|major)\b/i.test(raw)) {
      academicWeight = 0.9;
      cognitiveLoad = 'HIGH';
    } else if (/\b(low priority|chill|easy|minor|optional)\b/i.test(raw)) {
      academicWeight = 0.3;
      cognitiveLoad = 'LOW';
    } else if (/\b(medium priority|moderate|normal)\b/i.test(raw)) {
      academicWeight = 0.6;
      cognitiveLoad = 'MEDIUM';
    }

    // 3. Category extraction
    let category = 'Assignment';
    if (/\b(lab|practical|experiment|viva)\b/i.test(raw)) {
      category = 'Lab';
    } else if (/\b(revision|revising|review)\b/i.test(raw)) {
      category = 'Revision';
    } else if (/\b(project|capstone|code|coding)\b/i.test(raw)) {
      category = 'Project';
    } else if (/\b(practice|numerical|problem|quiz)\b/i.test(raw)) {
      category = 'Practice';
    } else if (/\b(reading|chapter|notes)\b/i.test(raw)) {
      category = 'Reading';
    }

    // 4. Subject extraction
    let matchedSubject: string | undefined;
    for (const sub of existingSubjects) {
      const reg = new RegExp(`\\b${sub}\\b`, 'i');
      if (reg.test(raw)) {
        matchedSubject = sub;
        break;
      }
    }
    if (!matchedSubject) {
      const acronymMatch = raw.match(/\b(DBMS|OS|CN|AI|ML|DS|DSA|MATH|MATHS|PHYSICS|CHEM|SE|COA|DAA)\b/i);
      if (acronymMatch) {
        matchedSubject = acronymMatch[1].toUpperCase();
      }
    }

    // 5. Deadline & Time extraction
    const nowRef = referenceDate;
    const nowDayStr = format(nowRef, 'yyyy-MM-dd', { timeZone: userTimezone });
    let deadlineDateStr: string | undefined;
    let deadlineTimeStr = '23:59';

    const timeMatch = raw.match(/(?:by|at|before)?\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b/i) ||
                      raw.match(/(?:by|at|before)\s*(\d{1,2}):(\d{2})\b/i);

    if (timeMatch) {
      if (timeMatch[3]) {
        let hr = parseInt(timeMatch[1], 10);
        const mn = timeMatch[2] ? parseInt(timeMatch[2], 10) : 0;
        const ampm = timeMatch[3].toLowerCase();
        if (ampm === 'pm' && hr < 12) hr += 12;
        if (ampm === 'am' && hr === 12) hr = 0;
        deadlineTimeStr = `${String(hr).padStart(2, '0')}:${String(mn).padStart(2, '0')}`;
      } else if (timeMatch[1] && timeMatch[2]) {
        deadlineTimeStr = `${String(timeMatch[1]).padStart(2, '0')}:${String(timeMatch[2]).padStart(2, '0')}`;
      }
    }

    if (/\btomorrow\b/i.test(raw)) {
      const d = new Date(nowRef.getTime() + 24 * 3600000);
      deadlineDateStr = format(d, 'yyyy-MM-dd', { timeZone: userTimezone });
    } else if (/\b(today|tonight)\b/i.test(raw)) {
      deadlineDateStr = nowDayStr;
      if (/\btonight\b/i.test(raw) && !timeMatch) {
        deadlineTimeStr = '22:00';
      }
    } else if (/\bthis\s+weekend\b/i.test(raw)) {
      const nowDayNum = nowRef.getDay();
      const daysUntilSunday = nowDayNum === 0 ? 0 : 7 - nowDayNum;
      const d = new Date(nowRef.getTime() + daysUntilSunday * 24 * 3600000);
      deadlineDateStr = format(d, 'yyyy-MM-dd', { timeZone: userTimezone });
    } else {
      const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
      const dayMatch = raw.match(/\b(?:next|on|this)?\s*(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b/i);
      if (dayMatch) {
        const targetDayName = dayMatch[1].toLowerCase();
        const targetDayNum = dayNames.indexOf(targetDayName);
        let daysAhead = targetDayNum - nowRef.getDay();
        if (daysAhead <= 0) daysAhead += 7;
        const d = new Date(nowRef.getTime() + daysAhead * 24 * 3600000);
        deadlineDateStr = format(d, 'yyyy-MM-dd', { timeZone: userTimezone });
      }
    }

    if (!deadlineDateStr) {
      const isoDateMatch = raw.match(/\b(\d{4}-\d{2}-\d{2})\b/);
      if (isoDateMatch) {
        deadlineDateStr = isoDateMatch[1];
      }
    }

    let deadline: Date | undefined;
    if (deadlineDateStr) {
      deadline = toDate(`${deadlineDateStr}T${deadlineTimeStr}:00`, { timeZone: userTimezone });
    } else {
      ambiguities.push({
        field: 'deadline',
        question: 'When is this due? (e.g., tomorrow at 5 PM or Friday)'
      });
    }

    // 6. Clean Title Extraction
    let cleanTitle = raw
      .replace(/^(?:i\s+need\s+to|i\s+have\s+to|please\s+schedule|add\s+task|schedule)\s+/i, '')
      .replace(/\b(?:by|at|before)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b/gi, '')
      .replace(/\b(?:tomorrow|today|tonight|this\s+weekend|next\s+\w+|on\s+\w+)\b/gi, '')
      .replace(/\b(?:\d+\s*(?:m|min|mins|minutes?)|[\d.]+\s*(?:h|hr|hrs|hours?))\b/gi, '')
      .replace(/\b(?:it\s+will\s+take|takes\s+about|around|about|approx|duration)\b/gi, '')
      .replace(/\b(?:and\s+is|is\s+)?(?:high|medium|low|urgent)\s+priority\b/gi, '')
      .replace(/\s{2,}/g, ' ')
      .trim();

    if (cleanTitle.length > 0) {
      cleanTitle = cleanTitle.charAt(0).toUpperCase() + cleanTitle.slice(1);
    } else {
      cleanTitle = matchedSubject ? `${matchedSubject} ${category}` : 'Academic Task';
    }

    let confidence = 0.5;
    if (estimateMinutes) confidence += 0.2;
    if (deadline) confidence += 0.2;
    if (matchedSubject) confidence += 0.1;

    const isAmbiguous = ambiguities.length > 0 || !deadline || !estimateMinutes;

    return {
      title: cleanTitle,
      subjectName: matchedSubject,
      category,
      deadline,
      deadlineIso: deadline?.toISOString(),
      estimateMinutes,
      academicWeight,
      cognitiveLoad,
      confidence: Math.min(confidence, 1.0),
      ambiguities,
      isAmbiguous,
      rawText: raw,
      parserSource: source
    };
  }
}

export const nlpTaskParser = new LocalNlpTaskParser();
