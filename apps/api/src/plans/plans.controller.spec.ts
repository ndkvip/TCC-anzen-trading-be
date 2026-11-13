import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PlansController } from './plans.controller';
import { PlansService } from './plans.service';

// Exercise the real routing/validation pipe without a database or external auth.
describe('Plans HTTP asset contract', () => {
  let app: INestApplication;
  const service = {
    upsert: jest.fn(async (_user, input) => input),
    get: jest.fn(async (_user, scope, periodKey, symbol) => ({
      scope,
      periodKey,
      symbol,
    })),
    list: jest.fn(async () => []),
    adminList: jest.fn(async () => []),
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [PlansController],
      providers: [{ provide: PlansService, useValue: service }],
    })
      .overrideGuard(JwtAuthGuard)
      .useValue({
        canActivate: (context) => {
          context.switchToHttp().getRequest().user = { sub: 'owner' };
          return true;
        },
      })
      .overrideGuard(RolesGuard)
      .useValue({ canActivate: () => true })
      .compile();
    app = module.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    );
    await app.init();
  });
  afterAll(async () => app.close());
  beforeEach(() => jest.clearAllMocks());

  it('accepts and normalizes the asset on PUT, resolve, list and admin queries', async () => {
    await request(app.getHttpServer())
      .put('/plans')
      .send({ symbol: ' xauusd ', scope: 'DAY', periodKey: '2026-11-13' })
      .expect(200);
    expect(service.upsert).toHaveBeenCalledWith(
      'owner',
      expect.objectContaining({ symbol: 'XAUUSD' }),
    );
    await request(app.getHttpServer())
      .get('/plans/resolve')
      .query({ symbol: 'btc/usd', scope: 'DAY', periodKey: '2026-11-13' })
      .expect(200);
    expect(service.get).toHaveBeenCalledWith(
      'owner',
      'DAY',
      '2026-11-13',
      'BTC/USD',
    );
    await request(app.getHttpServer())
      .get('/plans')
      .query({ symbol: 'nas100', scope: 'WEEK' })
      .expect(200);
    expect(service.list).toHaveBeenCalledWith('owner', 'WEEK', 'NAS100');
    await request(app.getHttpServer())
      .get('/plans/admin/all')
      .query({ symbol: 'ethusdt', userId: 'student' })
      .expect(200);
    expect(service.adminList).toHaveBeenCalledWith('student', 'ETHUSDT');
  });

  it.each(['', ' ', 'BTC USD', 'X'.repeat(31), '../gold', null, ['XAUUSD']])(
    'rejects invalid body symbol %p',
    async (symbol) => {
      await request(app.getHttpServer())
        .put('/plans')
        .send({ symbol })
        .expect(400);
      expect(service.upsert).not.toHaveBeenCalled();
    },
  );

  it('rejects blank/repeated query symbols and missing resolve coordinates', async () => {
    await request(app.getHttpServer()).get('/plans?symbol=').expect(400);
    await request(app.getHttpServer())
      .get('/plans?symbol=XAUUSD&symbol=BTCUSDT')
      .expect(400);
    await request(app.getHttpServer())
      .get('/plans/resolve?symbol=XAUUSD')
      .expect(400);
    expect(service.list).not.toHaveBeenCalled();
    expect(service.get).not.toHaveBeenCalled();
  });

  it('keeps symbol optional for old clients', async () => {
    await request(app.getHttpServer())
      .put('/plans')
      .send({ title: 'Legacy plan' })
      .expect(200);
    await request(app.getHttpServer()).get('/plans').expect(200);
    expect(service.list).toHaveBeenCalledWith('owner', undefined, undefined);
  });
});
