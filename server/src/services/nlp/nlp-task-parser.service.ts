import { toDate, format } from 'date-fns-tz';

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
}

export interface INlpTaskParser {
  parseTask(text: string, userTimezone: string, existingSubjects?: string[], referenceDate?: Date): ParsedTaskResult;
}

export class LocalNlpTaskParser implements INlpTaskParser {
  parseTask(
    text: string,
    userTimezone: string = 'Asia/Kolkata',
    existingSubjects: string[] = [],
    referenceDate: Date = new Date()
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
    // Also common subject acronyms if not in existing subjects
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
    let deadlineTimeStr = '23:59'; // default end of day

    // Check specific time: e.g. "by 5 PM", "at 4:30 pm", "at 17:00", "5pm"
    const timeMatch = raw.match(/(?:by|at|before)?\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b/i) ||
                      raw.match(/(?:by|at|before)\s*(\d{1,2}):(\d{2})\b/i);

    if (timeMatch) {
      if (timeMatch[3]) {
        // 12-hour format with am/pm
        let hr = parseInt(timeMatch[1], 10);
        const mn = timeMatch[2] ? parseInt(timeMatch[2], 10) : 0;
        const ampm = timeMatch[3].toLowerCase();
        if (ampm === 'pm' && hr < 12) hr += 12;
        if (ampm === 'am' && hr === 12) hr = 0;
        deadlineTimeStr = `${String(hr).padStart(2, '0')}:${String(mn).padStart(2, '0')}`;
      } else if (timeMatch[1] && timeMatch[2]) {
        // 24-hour format
        deadlineTimeStr = `${String(timeMatch[1]).padStart(2, '0')}:${String(timeMatch[2]).padStart(2, '0')}`;
      }
    }

    // Relative dates: today, tomorrow, tonight, next Monday, this weekend
    if (/\btomorrow\b/i.test(raw)) {
      const d = new Date(nowRef.getTime() + 24 * 3600000);
      deadlineDateStr = format(d, 'yyyy-MM-dd', { timeZone: userTimezone });
    } else if (/\b(today|tonight)\b/i.test(raw)) {
      deadlineDateStr = nowDayStr;
      if (/\btonight\b/i.test(raw) && !timeMatch) {
        deadlineTimeStr = '22:00';
      }
    } else if (/\bthis\s+weekend\b/i.test(raw)) {
      // nearest Sunday
      const nowDayNum = nowRef.getDay(); // 0 is Sunday
      const daysUntilSunday = nowDayNum === 0 ? 0 : 7 - nowDayNum;
      const d = new Date(nowRef.getTime() + daysUntilSunday * 24 * 3600000);
      deadlineDateStr = format(d, 'yyyy-MM-dd', { timeZone: userTimezone });
    } else {
      // Day of week match: e.g. "on Friday", "next Monday"
      const dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
      const dayMatch = raw.match(/\b(?:next|on|this)?\s*(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b/i);
      if (dayMatch) {
        const targetDayName = dayMatch[1].toLowerCase();
        const targetDayNum = dayNames.indexOf(targetDayName);
        let daysAhead = targetDayNum - nowRef.getDay();
        if (daysAhead <= 0) daysAhead += 7; // strictly next occurrence
        const d = new Date(nowRef.getTime() + daysAhead * 24 * 3600000);
        deadlineDateStr = format(d, 'yyyy-MM-dd', { timeZone: userTimezone });
      }
    }

    // Explicit date match: YYYY-MM-DD or e.g. "25th Oct", "Oct 25"
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

    // Capitalize first letter
    if (cleanTitle.length > 0) {
      cleanTitle = cleanTitle.charAt(0).toUpperCase() + cleanTitle.slice(1);
    } else {
      cleanTitle = matchedSubject ? `${matchedSubject} ${category}` : 'Academic Task';
    }

    // Confidence calculation
    let confidence = 0.5;
    if (estimateMinutes) confidence += 0.2;
    if (deadline) confidence += 0.2;
    if (matchedSubject) confidence += 0.1;

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
      rawText: raw
    };
  }
}

export const nlpTaskParser = new LocalNlpTaskParser();
