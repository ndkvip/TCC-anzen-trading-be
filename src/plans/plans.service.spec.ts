import { PlanScope } from './plan.entity';
import { PlansService } from './plans.service';
function repo(rows: any[] = []) {
  return {
    rows,
    find: jest.fn(async ({ where }: any) =>
      rows.filter((x) => Object.entries(where).every(([k, v]) => x[k] === v)),
    ),
    findOne: jest.fn(
      async ({ where }: any) =>
        rows.find((x) => Object.entries(where).every(([k, v]) => x[k] === v)) ??
        null,
    ),
    create: jest.fn((v: any) => ({ id: `p${rows.length + 1}`, ...v })),
    save: jest.fn(async (v: any) => {
      const i = rows.findIndex((x) => x.id === v.id);
      if (i >= 0) rows[i] = v;
      else rows.push(v);
      return v;
    }),
    remove: jest.fn(async (v: any) => v),
  };
}
describe('PlansService Phase 3', () => {
  it('inherits month to week and week to day but month inherits nothing', async () => {
    const r = repo();
    const s = new PlansService(r as never);
    const month = await s.upsert('u1', {
      scope: PlanScope.MONTH,
      periodKey: '2026-09',
      contentDelta: [{ insert: 'month' }],
      imageUrls: ['month.jpg'],
    });
    const week = await s.get('u1', PlanScope.WEEK, '2026-09-07');
    expect(week.inheritedPlanId).toBe(month.id);
    expect(week.contentDelta).toEqual([{ insert: 'month' }]);
    const savedWeek = await s.upsert('u1', {
      scope: PlanScope.WEEK,
      periodKey: '2026-09-07',
      contentDelta: [{ insert: 'week' }],
    });
    const day = await s.get('u1', PlanScope.DAY, '2026-09-09');
    expect(day.inheritedPlanId).toBe(savedWeek.id);
    expect(day.contentDelta).toEqual([{ insert: 'week' }]);
    const otherMonth = await s.get('u1', PlanScope.MONTH, '2026-10');
    expect(otherMonth.inheritedPlanId).toBeNull();
    expect(otherMonth.contentDelta).toEqual([]);
  });
  it('isolates periods and users', async () => {
    const r = repo();
    const s = new PlansService(r as never);
    await s.upsert('u1', {
      scope: PlanScope.DAY,
      periodKey: '2026-09-02',
      title: 'A',
    });
    expect((await s.list('u2')).length).toBe(0);
    expect((await s.get('u1', PlanScope.DAY, '2026-09-03')).title).not.toBe(
      'A',
    );
  });
});
