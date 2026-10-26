import { timetableParserService } from '../src/services/timetable-parser.service';

describe('Milestone 4 — College Timetable OCR & Text Parsing', () => {
  const existingCommitments = [
    { title: 'Operating Systems', daysOfWeek: '[2]' }
  ];

  test('1. Parses tabular timetable rows with days, times, subjects and venues', () => {
    const rawOcr = `
Monday 09:00 - 10:00 Database Management Systems Room 302
Monday 10:00 - 11:00 Computer Architecture LH-1
Tuesday 11:15 - 12:15 Operating Systems Room 204
Wednesday 2:00 PM - 4:00 PM Networks Laboratory Lab 3
Friday 09:00 - 10:00 Discrete Mathematics Room 101
    `.trim();

    const candidates = timetableParserService.parseTimetableText(rawOcr, existingCommitments);
    expect(candidates.length).toBe(5);

    // Monday DBMS
    expect(candidates[0].dayOfWeek).toBe(1);
    expect(candidates[0].dayName).toBe('Monday');
    expect(candidates[0].startTime).toBe('09:00');
    expect(candidates[0].endTime).toBe('10:00');
    expect(candidates[0].subject).toContain('Database Management Systems');
    expect(candidates[0].venue).toBe('Room 302');
    expect(candidates[0].isUncertain).toBe(false);

    // Wednesday PM Lab
    expect(candidates[3].dayOfWeek).toBe(3);
    expect(candidates[3].startTime).toBe('14:00');
    expect(candidates[3].endTime).toBe('16:00');
    expect(candidates[3].venue).toBe('Lab 3');
  });

  test('2. Correctly flags duplicates against existing student commitments', () => {
    const rawOcr = `Tuesday 11:00 - 12:00 Operating Systems Room 204`;
    const candidates = timetableParserService.parseTimetableText(rawOcr, existingCommitments);
    expect(candidates.length).toBe(1);
    expect(candidates[0].isDuplicate).toBe(true);
  });

  test('3. Flags uncertainty when day header is missing', () => {
    const rawOcr = `09:00 - 10:00 Cloud Computing LH-3`;
    const candidates = timetableParserService.parseTimetableText(rawOcr, existingCommitments);
    expect(candidates.length).toBe(1);
    expect(candidates[0].isUncertain).toBe(true);
    expect(candidates[0].uncertaintyReason).toBeDefined();
  });
});
