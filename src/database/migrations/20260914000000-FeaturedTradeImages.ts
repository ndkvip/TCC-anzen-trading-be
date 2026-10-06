import { MigrationInterface, QueryRunner } from 'typeorm';

export class FeaturedTradeImages20260914000000 implements MigrationInterface {
  name = 'FeaturedTradeImages20260914000000';

  async up(q: QueryRunner) {
    await q.query(
      `ALTER TABLE featured_trades ADD COLUMN IF NOT EXISTS image_urls jsonb NOT NULL DEFAULT '[]'::jsonb`,
    );
    await q.query(
      `ALTER TABLE featured_trades ALTER COLUMN title DROP NOT NULL`,
    );
    await q.query(
      `ALTER TABLE featured_trades ALTER COLUMN symbol DROP NOT NULL`,
    );
  }

  async down(q: QueryRunner) {
    await q.query(
      `ALTER TABLE featured_trades DROP COLUMN IF EXISTS image_urls`,
    );
  }
}
