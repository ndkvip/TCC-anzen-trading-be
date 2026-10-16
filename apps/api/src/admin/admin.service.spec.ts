import { DataSource } from 'typeorm';
import { AdminService } from './admin.service';

describe('AdminService dashboard', () => {
  it('maps aggregate strings, calculates completion, and keeps a zero denominator at zero', async () => {
    const query = jest
      .fn()
      .mockResolvedValueOnce([
        {
          studentCount: '4',
          lessonCount: '7',
          startedLessons: '0',
          completedLessons: '0',
          draftLessons: '2',
          incompleteLessons: '1',
          inactiveStudents: '1',
          unverifiedStudents: '3',
        },
      ])
      .mockResolvedValueOnce([
        { date: '2026-10-08', activeStudents: 0 },
        { date: '2026-10-09', activeStudents: 2 },
      ]);
    const service = new AdminService({ query } as unknown as DataSource);

    await expect(
      service.dashboard(new Date('2026-10-14T10:00:00.000Z')),
    ).resolves.toEqual(
      expect.objectContaining({
        studentCount: 4,
        lessonCount: 7,
        startedLessons: 0,
        completedLessons: 0,
        draftLessons: 2,
        incompleteLessons: 1,
        inactiveStudents: 1,
        unverifiedStudents: 3,
        completionRate: 0,
        activity: [
          { date: '2026-10-08', activeStudents: 0 },
          { date: '2026-10-09', activeStudents: 2 },
        ],
        timezone: 'Asia/Ho_Chi_Minh',
        generatedAt: '2026-10-14T10:00:00.000Z',
      }),
    );
    expect(query).toHaveBeenCalledTimes(2);
    expect(query.mock.calls[1][1]).toEqual(['2026-10-14T10:00:00.000Z']);
  });

  it('uses completed started lesson-progress rows for the completion rate', async () => {
    const query = jest
      .fn()
      .mockResolvedValueOnce([
        {
          studentCount: '10',
          lessonCount: '3',
          startedLessons: '8',
          completedLessons: '3',
          draftLessons: '1',
          incompleteLessons: '0',
          inactiveStudents: '0',
          unverifiedStudents: '0',
        },
      ])
      .mockResolvedValueOnce([]);
    const service = new AdminService({ query } as unknown as DataSource);

    const result = await service.dashboard(
      new Date('2026-10-14T00:00:00.000Z'),
    );

    expect(result.completionRate).toBe(37.5);
    expect(query.mock.calls[0][0]).toContain('p.progress > 0');
    expect(query.mock.calls[0][0]).toContain('progress >= 1');
  });
});
