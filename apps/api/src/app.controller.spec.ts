import { ServiceUnavailableException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';
import { HealthController } from './health/health.controller';

describe('HealthController', () => {
  it('returns an ok response when PostgreSQL responds', async () => {
    const module = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        {
          provide: DataSource,
          useValue: { query: jest.fn().mockResolvedValue([{ '?column?': 1 }]) },
        },
      ],
    }).compile();

    const result = await module.get(HealthController).check();
    expect(result.status).toBe('ok');
    expect(result.dependencies.database).toBe('ok');
  });

  it('reports a database failure as service unavailable', async () => {
    const module = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        {
          provide: DataSource,
          useValue: {
            query: jest.fn().mockRejectedValue(new Error('offline')),
          },
        },
      ],
    }).compile();

    try {
      await module.get(HealthController).check();
      fail('Expected the health check to reject');
    } catch (error) {
      expect(error).toBeInstanceOf(ServiceUnavailableException);
      expect((error as ServiceUnavailableException).getStatus()).toBe(503);
      expect((error as ServiceUnavailableException).getResponse()).toEqual(
        expect.objectContaining({
          status: 'degraded',
          dependencies: { database: 'error' },
        }),
      );
    }
  });
});
