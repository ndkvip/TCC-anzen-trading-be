import { MigrationInterface, QueryRunner } from 'typeorm';

export class RedNewsCalendarSync20260916000000 implements MigrationInterface {
  name = 'RedNewsCalendarSync20260916000000';

  async up(q: QueryRunner) {
    await q.query(
      `ALTER TABLE red_news ADD COLUMN IF NOT EXISTS currency varchar`,
    );
    await q.query(
      `ALTER TABLE red_news ADD COLUMN IF NOT EXISTS impact varchar NOT NULL DEFAULT 'HIGH'`,
    );
    await q.query(
      `ALTER TABLE red_news ADD COLUMN IF NOT EXISTS source varchar NOT NULL DEFAULT 'MANUAL'`,
    );
    await q.query(
      `ALTER TABLE red_news ADD COLUMN IF NOT EXISTS source_key varchar`,
    );
    await q.query(
      `CREATE INDEX IF NOT EXISTS IDX_red_news_source ON red_news (source)`,
    );
    await q.query(
      `CREATE UNIQUE INDEX IF NOT EXISTS IDX_red_news_source_key ON red_news (source_key)`,
    );
  }

  async down(q: QueryRunner) {
    await q.query(`DROP INDEX IF EXISTS IDX_red_news_source_key`);
    await q.query(`DROP INDEX IF EXISTS IDX_red_news_source`);
    await q.query(`ALTER TABLE red_news DROP COLUMN IF EXISTS source_key`);
    await q.query(`ALTER TABLE red_news DROP COLUMN IF EXISTS source`);
    await q.query(`ALTER TABLE red_news DROP COLUMN IF EXISTS impact`);
    await q.query(`ALTER TABLE red_news DROP COLUMN IF EXISTS currency`);
  }
}
