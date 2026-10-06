import { BadRequestException } from '@nestjs/common';
import { CheckinsService } from './checkins.service';
function repo(rows: any[] = []) {
  return {
    rows,
    find: jest.fn(async ({ where, order, skip = 0, take }: any) => {
      const r = rows
        .filter((x) => Object.entries(where).every(([k, v]) => x[k] === v))
        .sort((a, b) => b.checkinDate.localeCompare(a.checkinDate))
        .slice(skip, take ? skip + take : undefined);
      return r;
    }),
    findOne: jest.fn(
      async ({ where }: any) =>
        rows.find((x) => Object.entries(where).every(([k, v]) => x[k] === v)) ??
        null,
    ),
    create: jest.fn((v: any) => ({ id: `c${rows.length + 1}`, ...v })),
    save: jest.fn(async (v: any) => {
      const i = rows.findIndex((x) => x.id === v.id);
      if (i >= 0) rows[i] = v;
      else rows.push(v);
      return v;
    }),
    remove: jest.fn(async (v: any[]) => {
      for (const x of v) rows.splice(rows.indexOf(x), 1);
      return v;
    }),
  };
}
describe('CheckinsService Phase 3', () => {
  it('requires five 0..4 scores and calculates /10', async () => {
    const r = repo();
    const s = new CheckinsService(r as never);
    await expect(s.upsert('u1', '2026-09-02', [1, 2])).rejects.toBeInstanceOf(
      BadRequestException,
    );
    const row = await s.upsert('u1', '2026-09-02', [4, 3, 2, 1, 0]);
    expect(row.totalScore).toBe(5);
  });
  it('updates once per day and keeps newest 30', async () => {
    const r = repo();
    const s = new CheckinsService(r as never);
    for (let i = 1; i <= 31; i++)
      await s.upsert(
        'u1',
        `2026-08-${String(i).padStart(2, '0')}`,
        [2, 2, 2, 2, 2],
      );
    expect(r.rows).toHaveLength(30);
    expect(r.rows.some((x) => x.checkinDate === '2026-08-01')).toBe(false);
    const count = r.rows.length;
    await s.upsert('u1', '2026-08-31', [4, 4, 4, 4, 4]);
    expect(r.rows).toHaveLength(count);
    expect(r.rows.find((x) => x.checkinDate === '2026-08-31').totalScore).toBe(
      10,
    );
  });
});
