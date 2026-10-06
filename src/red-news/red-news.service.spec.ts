import { RedNewsService } from './red-news.service';
import { RedNews } from './red-news.entity';

describe('RedNewsService calendar sync', () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
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

    expect(existing.isActive).toBe(false);
  });
});
