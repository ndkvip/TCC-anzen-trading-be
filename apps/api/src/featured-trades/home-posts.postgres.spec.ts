import { randomUUID } from 'node:crypto';
import { DataSource, QueryRunner } from 'typeorm';
import { HomePosts20261113010000 } from '../database/migrations/20261113010000-HomePosts';
import { FeaturedTrade } from './featured-trade.entity';
import { FeaturedTradeService } from './featured-trade.service';

const postgresTests = process.env.HOME_POSTS_TEST_DATABASE_URL
  ? describe
  : describe.skip;
postgresTests('Home posts migration and persistence on PostgreSQL', () => {
  let db: DataSource;
  let runner: QueryRunner;
  let schema: string;
  const legacyId = '00000000-0000-0000-0000-000000000001';
  const migration = new HomePosts20261113010000();
  beforeEach(async () => {
    schema = `home_posts_test_${randomUUID().replaceAll('-', '')}`;
    db = new DataSource({
      type: 'postgres',
      url: process.env.HOME_POSTS_TEST_DATABASE_URL,
      schema,
      entities: [FeaturedTrade],
    });
    await db.initialize();
    runner = db.createQueryRunner();
    await runner.connect();
    await runner.query(`CREATE SCHEMA "${schema}"`);
    await runner.query(`SET search_path TO "${schema}", public`);
    await runner.query(`CREATE TABLE featured_trades (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(), week_start date NOT NULL,
      title varchar NOT NULL DEFAULT '', summary text, cover_image_url text,
      content_blocks jsonb NOT NULL DEFAULT '[]', image_urls jsonb NOT NULL DEFAULT '[]',
      is_active boolean NOT NULL DEFAULT true, created_at timestamp NOT NULL DEFAULT now(),
      updated_at timestamp NOT NULL DEFAULT now()
    )`);
    await runner.query(
      `INSERT INTO featured_trades (id,week_start,title,content_blocks,cover_image_url)
      VALUES ($1,'2026-11-09','Existing trade','[{"type":"text","text":"Keep me"}]','cover.webp')`,
      [legacyId],
    );
  });
  afterEach(async () => {
    if (runner) {
      await runner.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`);
      await runner.release();
    }
    if (db?.isInitialized) await db.destroy();
  });

  it('preserves legacy trades, isolates post CRUD, sorts newest first and never expires by week', async () => {
    await migration.up(runner);
    const service = new FeaturedTradeService(db.getRepository(FeaturedTrade), {
      remove: jest.fn(),
    } as never);
    const [legacy] = await service.publicForWeek('2026-11-09');
    expect(legacy.id).toBe(legacyId);
    expect(legacy.placement).toBe('FEATURED_TRADE');
    expect(legacy.contentBlocks).toEqual([{ type: 'text', text: 'Keep me' }]);
    expect(legacy.coverImageUrl).toBe('cover.webp');
    const old = await service.createHomePost({
      title: 'Old post',
      contentBlocks: [{ type: 'text', text: 'Still relevant' }],
    });
    await runner.query(
      `UPDATE featured_trades SET week_start='2020-01-06',created_at='2020-01-06' WHERE id=$1`,
      [old.id],
    );
    const latest = await service.createHomePost({
      title: 'Latest post',
      contentBlocks: [{ type: 'text', text: 'New content' }],
    });
    expect((await service.publicHomePosts()).map((p) => p.id)).toEqual([
      latest.id,
      old.id,
    ]);
    expect(
      (await service.publicForWeek('2026-11-09')).map((p) => p.id),
    ).toEqual([legacyId]);
    expect(await service.adminList()).toHaveLength(1);
    expect(await service.adminList('HOME_POST')).toHaveLength(2);
    await expect(
      service.update(legacyId, { isActive: false }, 'HOME_POST'),
    ).rejects.toThrow('không tồn tại');
    await expect(service.remove(latest.id)).rejects.toThrow('không tồn tại');
    await service.update(
      latest.id,
      { title: 'Edited', isActive: false },
      'HOME_POST',
    );
    expect((await service.publicHomePosts()).map((p) => p.id)).toEqual([
      old.id,
    ]);
    expect((await service.adminList('HOME_POST'))[0].title).toBe('Edited');
    await expect(migration.down(runner)).rejects.toThrow('home posts exist');
    expect(await service.adminList('HOME_POST')).toHaveLength(2);
    await service.remove(latest.id, 'HOME_POST');
    await service.remove(old.id, 'HOME_POST');
    expect(await service.publicHomePosts()).toEqual([]);
    expect(await service.adminList()).toHaveLength(1);
  });

  it('enforces known placements in PostgreSQL', async () => {
    await migration.up(runner);
    await expect(
      runner.query(
        `INSERT INTO featured_trades(week_start,title,placement) VALUES ('2026-11-09','Invalid','UNKNOWN')`,
      ),
    ).rejects.toMatchObject({ code: '23514' });
  });

  it('rolls back before posts exist without losing existing trade content', async () => {
    await migration.up(runner);
    await migration.down(runner);
    const [legacy] = await runner.query(
      'SELECT * FROM featured_trades WHERE id=$1',
      [legacyId],
    );
    expect(legacy.placement).toBeUndefined();
    expect(legacy.content_blocks).toEqual([{ type: 'text', text: 'Keep me' }]);
    expect(legacy.cover_image_url).toBe('cover.webp');
  });
});
