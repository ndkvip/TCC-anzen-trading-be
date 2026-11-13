import { randomUUID } from 'node:crypto';
import { DataSource, QueryRunner } from 'typeorm';
import { PlanAssets20261113000000 } from '../database/migrations/20261113000000-PlanAssets';
import { PlanScope, TradingPlan } from './plan.entity';
import { PlansService } from './plans.service';

// Only an explicitly supplied test database is used; each case owns a new schema.
const postgresTests = process.env.PLAN_TEST_DATABASE_URL
  ? describe
  : describe.skip;
postgresTests.each(['constraint', 'index', 'both'])(
  'Plan asset migration on PostgreSQL (%s)',
  (kind) => {
    let db: DataSource;
    let runner: QueryRunner;
    let schema: string;
    const owner = '00000000-0000-0000-0000-000000000001';
    const legacyId = '00000000-0000-0000-0000-000000000002';
    const migration = new PlanAssets20261113000000();

    beforeEach(async () => {
      schema = `plan_test_${randomUUID().replaceAll('-', '')}`;
      db = new DataSource({
        type: 'postgres',
        url: process.env.PLAN_TEST_DATABASE_URL,
        schema,
        entities: [TradingPlan],
      });
      await db.initialize();
      runner = db.createQueryRunner();
      await runner.connect();
      await runner.query(`CREATE SCHEMA "${schema}"`);
      await runner.query(`SET search_path TO "${schema}", public`);
      await runner.query(
        `CREATE TYPE trading_plans_scope_enum AS ENUM ('MONTH','WEEK','DAY')`,
      );
      await runner.query(
        `CREATE TYPE trading_plans_status_enum AS ENUM ('DRAFT','COMPLETED')`,
      );
      await runner.query(`CREATE TABLE trading_plans (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL,
      scope trading_plans_scope_enum NOT NULL, period_key varchar NOT NULL,
      title varchar NOT NULL, status trading_plans_status_enum NOT NULL DEFAULT 'DRAFT',
      content_delta jsonb NOT NULL DEFAULT '[]', timeframe_pairs jsonb NOT NULL DEFAULT '[]',
      inherited_plan_id uuid, image_urls jsonb NOT NULL DEFAULT '[]',
      created_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now()
    )`);
      if (kind !== 'index')
        await runner.query(
          `ALTER TABLE trading_plans ADD CONSTRAINT legacy_unique UNIQUE(user_id, scope, period_key)`,
        );
      if (kind !== 'constraint')
        await runner.query(
          `CREATE UNIQUE INDEX legacy_typeorm_idx ON trading_plans(user_id, scope, period_key)`,
        );
      await runner.query(
        `INSERT INTO trading_plans(id,user_id,scope,period_key,title,status,content_delta,image_urls) VALUES ($1,$2,'DAY','2026-11-13','Legacy','COMPLETED','[{"insert":"old content"}]','["chart.jpg"]')`,
        [legacyId, owner],
      );
    });

    afterEach(async () => {
      if (runner) {
        await runner.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
        await runner.release();
      }
      if (db?.isInitialized) await db.destroy();
    });

    it('preserves old plans, allows one row per asset and enforces new uniqueness', async () => {
      await migration.up(runner);
      const service = new PlansService(db.getRepository(TradingPlan));
      const legacy = await service.get(owner, PlanScope.DAY, '2026-11-13');
      expect(legacy.id).toBe(legacyId);
      expect(legacy.symbol).toBe('GENERAL');
      expect(legacy.contentDelta).toEqual([{ insert: 'old content' }]);
      expect(legacy.imageUrls).toEqual(['chart.jpg']);
      expect(legacy.status).toBe('COMPLETED');
      const gold = await service.upsert(owner, {
        symbol: 'XAUUSD',
        scope: PlanScope.DAY,
        periodKey: '2026-11-13',
        title: 'Gold',
      });
      await service.upsert(owner, {
        symbol: 'BTCUSDT',
        scope: PlanScope.DAY,
        periodKey: '2026-11-13',
        title: 'Bitcoin',
      });
      expect((await service.list(owner)).length).toBe(3);
      await expect(
        runner.query(
          `INSERT INTO trading_plans(user_id,symbol,scope,period_key,title) VALUES ($1,'XAUUSD','DAY','2026-11-13','Duplicate')`,
          [owner],
        ),
      ).rejects.toMatchObject({ code: '23505' });
      await service.upsert(owner, {
        symbol: 'xauusd',
        scope: PlanScope.DAY,
        periodKey: '2026-11-13',
        title: 'Updated',
      });
      expect(
        (await service.get(owner, PlanScope.DAY, '2026-11-13', 'XAUUSD')).id,
      ).toBe(gold.id);
      await expect(migration.down(runner)).rejects.toThrow('assigned assets');
      expect((await service.list(owner)).length).toBe(3);
      await service.remove(owner, gold.id);
      expect(
        (await service.get(owner, PlanScope.DAY, '2026-11-13', 'BTCUSDT'))
          .title,
      ).toBe('Bitcoin');
    });

    it('rolls back safely before any named assets exist, preserving legacy content', async () => {
      await migration.up(runner);
      await migration.down(runner);
      const [row] = await runner.query(
        `SELECT * FROM trading_plans WHERE id = $1`,
        [legacyId],
      );
      expect(row.symbol).toBeUndefined();
      expect(row.content_delta).toEqual([{ insert: 'old content' }]);
      await expect(
        runner.query(
          `INSERT INTO trading_plans(user_id,scope,period_key,title) VALUES ($1,'DAY','2026-11-13','Duplicate')`,
          [owner],
        ),
      ).rejects.toMatchObject({ code: '23505' });
    });
  },
);
