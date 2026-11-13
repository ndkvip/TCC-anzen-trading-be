import { PlanScope, PlanStatus } from './plan.entity';
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
    remove: jest.fn(async (v: any) => {
      rows.splice(
        rows.findIndex((row) => row.id === v.id),
        1,
      );
      return v;
    }),
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
  it('persists draft/completed status independently for each period', async () => {
    const r = repo();
    const s = new PlansService(r as never);
    const draft = await s.upsert('u1', {
      scope: PlanScope.DAY,
      periodKey: '2026-09-09',
      status: PlanStatus.DRAFT,
    });
    expect(draft.status).toBe(PlanStatus.DRAFT);

    const completed = await s.upsert('u1', {
      scope: PlanScope.DAY,
      periodKey: '2026-09-09',
      status: PlanStatus.COMPLETED,
    });
    expect(completed.status).toBe(PlanStatus.COMPLETED);
    expect((await s.get('u1', PlanScope.DAY, '2026-09-09')).status).toBe(
      PlanStatus.COMPLETED,
    );
  });

  it('stores multiple assets for one period and normalizes symbols on every lookup', async () => {
    const s = new PlansService(repo() as never);
    const input = { scope: PlanScope.DAY, periodKey: '2026-11-13' };
    const gold = await s.upsert('u1', {
      ...input,
      symbol: ' xauusd ',
      title: 'Gold',
    });
    const btc = await s.upsert('u1', {
      ...input,
      symbol: 'BTCUSDT',
      title: 'Bitcoin',
    });
    const legacy = await s.upsert('u1', { ...input, title: 'Legacy' });
    expect(new Set([gold.id, btc.id, legacy.id]).size).toBe(3);
    expect(gold.symbol).toBe('XAUUSD');
    expect(legacy.symbol).toBe('GENERAL');
    expect((await s.list('u1')).length).toBe(3);
    expect(await s.list('u1', PlanScope.DAY, ' xauusd ')).toEqual([gold]);
    expect(await s.adminList('u1', 'btcusdt')).toEqual([btc]);
    expect((await s.get('u1', PlanScope.DAY, input.periodKey)).id).toBe(
      legacy.id,
    );
    await s.upsert('u1', { ...input, symbol: 'XAUUSD', title: 'Updated gold' });
    expect(
      (await s.get('u1', PlanScope.DAY, input.periodKey, 'BTCUSDT')).title,
    ).toBe('Bitcoin');
    expect(
      (await s.get('u1', PlanScope.DAY, input.periodKey, 'GENERAL')).title,
    ).toBe('Legacy');
    await expect(s.remove('u2', btc.id)).rejects.toThrow();
    await s.remove('u1', gold.id);
    expect((await s.list('u1')).map((row) => row.id)).toEqual([
      btc.id,
      legacy.id,
    ]);
  });

  it('inherits within the same asset only, including a virtual week and a month boundary', async () => {
    const s = new PlansService(repo() as never);
    const month = await s.upsert('u1', {
      scope: PlanScope.MONTH,
      periodKey: '2026-10',
      symbol: 'XAUUSD',
      contentDelta: [{ insert: 'Gold month' }],
    });
    await s.upsert('u1', {
      scope: PlanScope.MONTH,
      periodKey: '2026-10',
      symbol: 'GENERAL',
      contentDelta: [{ insert: 'Legacy month' }],
    });
    await s.upsert('u2', {
      scope: PlanScope.WEEK,
      periodKey: '2026-10-26',
      symbol: 'BTCUSDT',
      contentDelta: [{ insert: 'Other user' }],
    });
    const gold = await s.get('u1', PlanScope.DAY, '2026-11-01', 'XAUUSD');
    expect(gold.inheritedPlanId).toBe(month.id);
    expect(gold.contentDelta).toEqual([{ insert: 'Gold month' }]);
    const bitcoin = await s.get('u1', PlanScope.DAY, '2026-11-01', 'BTCUSDT');
    expect(bitcoin.inheritedPlanId).toBeNull();
    expect(bitcoin.contentDelta).toEqual([]);
    expect(bitcoin.symbol).toBe('BTCUSDT');
    expect(bitcoin.id).not.toBe(gold.id);
    const week = await s.upsert('u1', {
      scope: PlanScope.WEEK,
      periodKey: '2026-10-26',
      symbol: 'XAUUSD',
      contentDelta: [{ insert: 'Gold week' }],
    });
    expect(
      (await s.get('u1', PlanScope.DAY, '2026-11-01', 'XAUUSD'))
        .inheritedPlanId,
    ).toBe(week.id);
  });

  it.each(['', ' ', '../foo', 'BTC USD', 'X'.repeat(31), null, ['BTCUSDT']])(
    'rejects invalid asset %p without writing',
    async (symbol) => {
      const r = repo();
      const s = new PlansService(r as never);
      // A leading dot is invalid; separators are allowed only after the first character.
      await expect(s.upsert('u1', { symbol } as never)).rejects.toThrow();
      expect(r.save).not.toHaveBeenCalled();
    },
  );
});
