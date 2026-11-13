import { MigrationInterface, QueryRunner } from 'typeorm';

export class HomePosts20261113010000 implements MigrationInterface {
  name = 'HomePosts20261113010000';

  async up(q: QueryRunner) {
    await q.query(`ALTER TABLE featured_trades
      ADD COLUMN placement varchar NOT NULL DEFAULT 'FEATURED_TRADE',
      ADD CONSTRAINT featured_trades_placement_check
        CHECK (placement IN ('FEATURED_TRADE', 'HOME_POST'))`);
    await q.query(`CREATE INDEX featured_trades_placement_active_created_idx
      ON featured_trades (placement, is_active, created_at DESC)`);
  }

  async down(q: QueryRunner) {
    const [row] = await q.query(`SELECT EXISTS (
      SELECT 1 FROM featured_trades WHERE placement = 'HOME_POST'
    ) AS has_posts`);
    if (row.has_posts)
      throw new Error('Cannot revert HomePosts while home posts exist');
    await q.query('DROP INDEX featured_trades_placement_active_created_idx');
    await q.query('ALTER TABLE featured_trades DROP COLUMN placement');
  }
}
