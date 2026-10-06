import { JournalService } from './journal.service';
import { JournalMode, TradeDirection } from './trade-journal.entity';

function repo(rows: any[] = []) {
  return {
    rows,
    create: jest.fn((v: any) => ({
      id: `t${rows.length + 1}`,
      createdAt: new Date(),
      ...v,
    })),
    save: jest.fn(async (v: any) => {
      const i = rows.findIndex((x) => x.id === v.id);
      if (i >= 0) rows[i] = v;
      else rows.push(v);
      return v;
    }),
    insert: jest.fn(async (v: any) => {
      rows.push(v);
      return { identifiers: [{ id: v.id }] };
    }),
    findOneOrFail: jest.fn(async ({ where }: any) => {
      const row = rows.find((x) =>
        Object.entries(where).every(([k, v]) => x[k] === v),
      );
      if (!row) throw new Error('not found');
      return row;
    }),
    find: jest.fn(async ({ where }: any = {}) =>
      rows.filter(
        (x) => !where || Object.entries(where).every(([k, v]) => x[k] === v),
      ),
    ),
    findOne: jest.fn(
      async ({ where }: any) =>
        rows.find((x) => Object.entries(where).every(([k, v]) => x[k] === v)) ??
        null,
    ),
    remove: jest.fn(async (v: any) => {
      rows.splice(rows.indexOf(v), 1);
      return v;
    }),
  };
}

describe('JournalService Phase 3', () => {
  it('marks missing PNL as running and normalizes symbols', async () => {
    const repository = repo();
    const service = new JournalService(repository as never);
    const row = await service.create('u1', {
      mode: JournalMode.INTRA_DAY,
      symbol: ' xauusd ',
      direction: TradeDirection.LONG,
      tradeDate: '2026-09-02',
    });
    expect(row.symbol).toBe('XAUUSD');
    expect(row.pnl).toBeNull();
    expect((await service.summary('u1', JournalMode.INTRA_DAY)).running).toBe(
      1,
    );
  });
  it('summarizes PNL, R and best strategy', async () => {
    const rows = [
      {
        id: '1',
        userId: 'u1',
        mode: JournalMode.SWING,
        tradeDate: null,
        pnl: 200,
        riskReward: 2,
        priceMovement: 'AMD',
      },
      {
        id: '2',
        userId: 'u1',
        mode: JournalMode.SWING,
        tradeDate: null,
        pnl: -50,
        riskReward: -0.5,
        priceMovement: 'MMXM',
      },
      {
        id: '3',
        userId: 'u1',
        mode: JournalMode.SWING,
        tradeDate: null,
        pnl: null,
        riskReward: 0,
        priceMovement: 'AMD',
      },
    ];
    const summary = await new JournalService(repo(rows) as never).summary(
      'u1',
      JournalMode.SWING,
    );
    expect(summary).toEqual(
      expect.objectContaining({
        count: 3,
        running: 1,
        pnl: 150,
        totalR: 1.5,
        bestStrategy: 'AMD',
      }),
    );
  });
  it('patches only supplied fields', async () => {
    const rows = [
      {
        id: '1',
        userId: 'u1',
        mode: JournalMode.INTRA_DAY,
        tradeDate: '2026-09-02',
        symbol: 'BTCUSDT',
        direction: TradeDirection.LONG,
        pnl: null,
      },
    ];
    const updated = await new JournalService(repo(rows) as never).update(
      'u1',
      '1',
      { pnl: 90 },
    );
    expect(updated.symbol).toBe('BTCUSDT');
    expect(updated.pnl).toBe(90);
    expect(updated.tradeDate).toBe('2026-09-02');
  });

  it('retries a client idempotency key without creating a duplicate', async () => {
    const repository = repo();
    const service = new JournalService(repository as never);
    const id = '6f9f1f3d-9d1c-4b0d-9b1a-2fef7d0a4f01';
    const input = {
      id,
      mode: JournalMode.SWING,
      symbol: 'BTCUSDT',
      direction: TradeDirection.LONG,
    };
    const first = await service.create('u1', input);
    const second = await service.create('u1', input);
    expect(first.id).toBe(id);
    expect(second.id).toBe(id);
    expect(repository.insert).toHaveBeenCalledTimes(1);
    expect(repository.rows).toHaveLength(1);
  });
});
