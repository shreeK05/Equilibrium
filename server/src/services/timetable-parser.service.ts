export interface TimetableEntryCandidate {
  id: string;
  dayOfWeek: number; // 0=Sunday, 1=Monday, ..., 6=Saturday
  dayName: string;   // "Monday", "Tuesday", etc.
  startTime: string; // "09:00"
  endTime: string;   // "10:00"
  subject: string;   // e.g. "DBMS"
  venue?: string;    // e.g. "Room 302"
  confidence: number; // 0.0 - 1.0
  isUncertain: boolean;
  uncertaintyReason?: string;
  isDuplicate?: boolean;
  rawText: string;
}

const DAYS_MAP: Record<string, { num: number; name: string }> = {
  'mon': { num: 1, name: 'Monday' },
  'monday': { num: 1, name: 'Monday' },
  'tue': { num: 2, name: 'Tuesday' },
  'tues': { num: 2, name: 'Tuesday' },
  'tuesday': { num: 2, name: 'Tuesday' },
  'wed': { num: 3, name: 'Wednesday' },
  'wednesday': { num: 3, name: 'Wednesday' },
  'thu': { num: 4, name: 'Thursday' },
  'thur': { num: 4, name: 'Thursday' },
  'thursday': { num: 4, name: 'Thursday' },
  'fri': { num: 5, name: 'Friday' },
  'friday': { num: 5, name: 'Friday' },
  'sat': { num: 6, name: 'Saturday' },
  'saturday': { num: 6, name: 'Saturday' },
  'sun': { num: 0, name: 'Sunday' },
  'sunday': { num: 0, name: 'Sunday' }
};

export class TimetableParserService {
  /**
   * Parse extracted OCR text from college timetable image into structured editable rows.
   */
  parseTimetableText(
    rawText: string,
    existingCommitments: Array<{ title: string; daysOfWeek?: string | null }> = []
  ): TimetableEntryCandidate[] {
    const lines = rawText.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
    const candidates: TimetableEntryCandidate[] = [];
    let currentDay: { num: number; name: string } | null = null;
    let entryIndex = 0;

    for (const line of lines) {
      // 1. Check if the line is purely a Day header (e.g., "MONDAY" or "Tuesday:")
      const dayHeaderMatch = line.match(/^(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)[:\s]*$/i);
      if (dayHeaderMatch) {
        const key = dayHeaderMatch[1].toLowerCase();
        if (DAYS_MAP[key]) {
          currentDay = DAYS_MAP[key];
          continue;
        }
      }

      // 2. Check for inline day mention
      let lineDay = currentDay;
      const inlineDayMatch = line.match(/\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b/i);
      if (inlineDayMatch) {
        const key = inlineDayMatch[1].toLowerCase();
        if (DAYS_MAP[key]) {
          lineDay = DAYS_MAP[key];
        }
      }

      // 3. Match time ranges (24h or 12h am/pm)
      // e.g. "09:00 - 10:00", "9:00am - 10:00am", "2:00 PM to 4:00 PM", "09:00-11:00"
      const timeRangeMatch =
        line.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:-|to|–)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/i);

      if (timeRangeMatch) {
        let startHr = parseInt(timeRangeMatch[1], 10);
        const startMin = timeRangeMatch[2] ? parseInt(timeRangeMatch[2], 10) : 0;
        const startAmPm = timeRangeMatch[3]?.toLowerCase();

        let endHr = parseInt(timeRangeMatch[4], 10);
        const endMin = timeRangeMatch[5] ? parseInt(timeRangeMatch[5], 10) : 0;
        const endAmPm = timeRangeMatch[6]?.toLowerCase() || startAmPm;

        if (startAmPm === 'pm' && startHr < 12) startHr += 12;
        if (startAmPm === 'am' && startHr === 12) startHr = 0;
        if (endAmPm === 'pm' && endHr < 12) endHr += 12;
        if (endAmPm === 'am' && endHr === 12) endHr = 0;

        // If end hour is less than start hour and no am/pm specified, likely crossed noon (e.g. 11:00 - 1:00)
        if (endHr < startHr && endHr <= 6) {
          endHr += 12;
        }

        const startTime = `${String(startHr).padStart(2, '0')}:${String(startMin).padStart(2, '0')}`;
        const endTime = `${String(endHr).padStart(2, '0')}:${String(endMin).padStart(2, '0')}`;

        // 4. Extract venue / room (e.g. "Room 302", "LH-1", "Lab 3", "CR-4")
        let venue: string | undefined;
        const venueMatch = line.match(/\b(?:room|lh|hall|lab|cr)[-\s]+[0-9a-z]+\b/i);
        if (venueMatch) {
          venue = venueMatch[0].trim();
        }

        // 5. Clean Subject
        let subject = line
          .replace(/\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b/gi, '')
          .replace(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*(?:-|to|–)\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)?/gi, '')
          .replace(/\b(?:room|lh|hall|lab|cr)[-\s]+[0-9a-z]+\b/gi, '')
          .replace(/[|:;,\-_/]/g, ' ')
          .replace(/\s{2,}/g, ' ')
          .trim();


        if (subject.length === 0) {
          subject = 'Lecture';
        }

        // 6. Confidence & Uncertainty calculation
        let confidence = 0.6;
        let isUncertain = false;
        let uncertaintyReason: string | undefined;

        if (!lineDay) {
          // Fallback to Monday if day is absent
          lineDay = { num: 1, name: 'Monday' };
          confidence -= 0.3;
          isUncertain = true;
          uncertaintyReason = 'Weekday not clearly detected. Please verify.';
        } else {
          confidence += 0.2;
        }

        if (venue) confidence += 0.1;
        if (subject.length > 3) confidence += 0.1;

        // 7. Duplicate Check
        const isDuplicate = existingCommitments.some(c => {
          const titleMatch = c.title.toLowerCase().includes(subject.toLowerCase()) || subject.toLowerCase().includes(c.title.toLowerCase());
          const dayMatch = c.daysOfWeek ? c.daysOfWeek.includes(String(lineDay?.num)) : false;
          return titleMatch && dayMatch;
        });

        entryIndex++;
        candidates.push({
          id: `entry-${entryIndex}-${Date.now()}`,
          dayOfWeek: lineDay.num,
          dayName: lineDay.name,
          startTime,
          endTime,
          subject,
          venue,
          confidence: Math.min(confidence, 1.0),
          isUncertain,
          uncertaintyReason,
          isDuplicate,
          rawText: line
        });
      }
    }

    return candidates;
  }
}

export const timetableParserService = new TimetableParserService();
