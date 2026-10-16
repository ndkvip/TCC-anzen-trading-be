import { MigrationInterface, QueryRunner } from 'typeorm';

export class FeaturedTrades20260912000000 implements MigrationInterface {
  name = 'FeaturedTrades20260912000000';

  async up(q: QueryRunner) {
    await q.query(`
      CREATE TABLE IF NOT EXISTS featured_trades (
        id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
        week_start date NOT NULL UNIQUE,
        title varchar NOT NULL,
        description text,
        symbol varchar NOT NULL,
        direction varchar NOT NULL DEFAULT 'LONG',
        pnl double precision,
        risk_reward double precision,
        setup varchar,
        timeframe_pair varchar,
        image_url text,
        is_active boolean NOT NULL DEFAULT true,
        created_at timestamp NOT NULL DEFAULT now(),
        updated_at timestamp NOT NULL DEFAULT now()
      )
    `);
  }

  async down(q: QueryRunner) {
    await q.query('DROP TABLE IF EXISTS featured_trades');
  }
}
