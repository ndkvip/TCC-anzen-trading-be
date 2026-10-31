import { RedNewsService } from './red-news.service';
import { RedNews } from './red-news.entity';

describe('RedNewsService calendar sync', () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
    delete process.env.FOREX_FACTORY_SYNC_ENABLED;
    jest.restoreAllMocks();
  });

  it('imports only high-impact calendar metadata and copies no description', async () => {
    const saved: RedNews[] = [];
    const repository = {
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((value: Partial<RedNews>) => value as RedNews),
      save: jest.fn(async (value: RedNews) => {
        saved.push(value);
        return value;
      }),
      createQueryBuilder: jest.fn(() => ({
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 0 }),
      })),
    };
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => [
        {
          title: 'CPI m/m',
          country: 'USD',
          date: '2026-09-16T08:30:00-04:00',
          impact: 'High',
          forecast: '0.3%',
        },
        {
          title: 'Minor release',
          country: 'USD',
          date: '2026-09-16T10:00:00-04:00',
          impact: 'Low',
        },
      ],
    });

    const service = new RedNewsService(repository as never);
    const result = await service.syncFromCalendar();

    expect(result).toEqual({ synced: 1, skipped: false });
    expect(saved).toHaveLength(1);
    expect(saved[0]).toMatchObject({
      title: 'CPI m/m',
      currency: 'USD',
      impact: 'HIGH',
      source: 'FOREX_FACTORY_CALENDAR',
      description: null,
      isActive: true,
    });
    expect(saved[0]).not.toHaveProperty('forecast');
  });

  it('preserves the admin visibility switch when refreshing an existing event', async () => {
    const existing = {
      id: 'existing-id',
      title: 'Old title',
      currency: 'USD',
      impact: 'HIGH',
      source: 'FOREX_FACTORY_CALENDAR',
      sourceKey: 'ff:key',
      visibilityOverride: null,
      description: null,
      releaseAt: new Date('2026-09-16T12:30:00.000Z'),
      isActive: false,
    } as RedNews;
    const repository = {
      findOne: jest.fn().mockResolvedValue(existing),
      create: jest.fn((value: Partial<RedNews>) => value as RedNews),
      save: jest.fn(async (value: RedNews) => value),
      createQueryBuilder: jest.fn(() => ({
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 0 }),
      })),
    };
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => [
        {
          title: 'CPI m/m',
          country: 'USD',
          date: '2026-09-16T08:30:00-04:00',
          impact: 'High',
        },
      ],
    });

    const service = new RedNewsService(repository as never);
    await service.syncFromCalendar();

    expect(existing.isActive).toBe(true);
  });

  it('keeps an explicitly hidden event hidden during a calendar refresh', async () => {
    const existing = {
      id: 'hidden-id',
      title: 'Old title',
      currency: 'USD',
      impact: 'HIGH',
      source: 'FOREX_FACTORY_CALENDAR',
      sourceKey: 'ff:hidden',
      visibilityOverride: false,
      description: null,
      releaseAt: new Date('2026-10-28T18:00:00.000Z'),
      isActive: false,
    } as RedNews;
    const repository = {
      findOne: jest.fn().mockResolvedValue(existing),
      create: jest.fn((value: Partial<RedNews>) => value as RedNews),
      save: jest.fn(async (value: RedNews) => value),
      createQueryBuilder: jest.fn(() => ({
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 0 }),
      })),
    };
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => [
        {
          title: 'Federal Funds Rate',
          country: 'USD',
          date: '2026-10-28T14:00:00-04:00',
          impact: 'High',
        },
      ],
    });

    const service = new RedNewsService(repository as never);
    await service.syncFromCalendar();

    expect(existing.isActive).toBe(false);
  });

  it('allows an explicit admin refresh when background sync is disabled', async () => {
    process.env.FOREX_FACTORY_SYNC_ENABLED = 'false';
    const saved: RedNews[] = [];
    const repository = {
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((value: Partial<RedNews>) => value as RedNews),
      save: jest.fn(async (value: RedNews) => {
        saved.push(value);
        return value;
      }),
      createQueryBuilder: jest.fn(() => ({
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 0 }),
      })),
    };
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => [
        {
          title: 'Federal Funds Rate',
          country: 'USD',
          date: '2026-10-28T14:00:00-04:00',
          impact: 'High',
        },
      ],
    });

    const service = new RedNewsService(repository as never);
    expect(await service.syncFromCalendar()).toEqual({
      synced: 0,
      skipped: true,
    });
    expect(await service.syncFromCalendar({ force: true })).toEqual({
      synced: 1,
      skipped: false,
    });
    expect(saved).toHaveLength(1);
  });

  it('uses the fallback feed when the calendar provider is rate limited', async () => {
    const saved: RedNews[] = [];
    const repository = {
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((value: Partial<RedNews>) => value as RedNews),
      save: jest.fn(async (value: RedNews) => {
        saved.push(value);
        return value;
      }),
      createQueryBuilder: jest.fn(() => ({
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        andWhere: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({ affected: 0 }),
      })),
    };
    global.fetch = jest
      .fn()
      .mockResolvedValueOnce({ ok: false, status: 429 })
      .mockResolvedValueOnce({
        ok: true,
        text: async () =>
          `Title: [\n${JSON.stringify({
            title: 'CPI m/m',
            country: 'USD',
            date: '2026-11-04T08:30:00-05:00',
            impact: 'High',
          })}\n]`,
      });

    const service = new RedNewsService(repository as never);
    const result = await service.syncFromCalendar();

    expect(result).toEqual({ synced: 1, skipped: false });
    expect(saved[0]).toMatchObject({ title: 'CPI m/m', currency: 'USD' });
    expect(global.fetch).toHaveBeenCalledTimes(2);
  });

  it('defaults manual entries to USD so they appear on the public feed', async () => {
    const repository = {
      create: jest.fn((value: Partial<RedNews>) => value as RedNews),
      save: jest.fn(async (value: RedNews) => value),
    };
    const service = new RedNewsService(repository as never);

    await service.create({
      title: 'Tin thủ công',
      releaseAt: '2026-10-31T10:00:00.000Z',
    });

    expect(repository.create).toHaveBeenCalledWith(
      expect.objectContaining({ currency: 'USD', visibilityOverride: true }),
    );
  });

  it('returns only active USD news to the public home feed', async () => {
    const repository = {
      find: jest.fn().mockResolvedValue([]),
    };
    const service = new RedNewsService(repository as never);

    await service.listPublic();

    const options = repository.find.mock.calls[0][0];
    expect(options.where.isActive).toBe(true);
    expect(options.where.currency.getSql?.('red_news.currency')).toBe(
      'UPPER(TRIM(red_news.currency)) = :publicCurrency',
    );
    expect(options.where.currency.objectLiteralParameters).toEqual({
      publicCurrency: 'USD',
    });
  });
});
