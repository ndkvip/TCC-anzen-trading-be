import { MigrationInterface, QueryRunner } from 'typeorm';
export class Phase3Schema20260902000000 implements MigrationInterface {
  name = 'Phase3Schema20260902000000';
  async up(q: QueryRunner) {
    await q.query(
      `DO $$ BEGIN CREATE TYPE "lessons_tier_enum" AS ENUM ('BASIC','ADVANCED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`,
    );
    await q.query(
      `DO $$ BEGIN CREATE TYPE "trade_journals_mode_enum" AS ENUM ('INTRA_DAY','SWING'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`,
    );
    await q.query(
      `DO $$ BEGIN CREATE TYPE "trade_journals_direction_enum" AS ENUM ('LONG','SHORT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`,
    );
    await q.query(
      `DO $$ BEGIN CREATE TYPE "trading_plans_scope_enum" AS ENUM ('MONTH','WEEK','DAY'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`,
    );
    await q.query(
      `CREATE TABLE IF NOT EXISTS lessons (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), slug varchar NOT NULL UNIQUE, title varchar NOT NULL, description text NOT NULL DEFAULT '', tier lessons_tier_enum NOT NULL, position integer NOT NULL DEFAULT 0, duration_minutes integer NOT NULL DEFAULT 10, is_published boolean NOT NULL DEFAULT true, knowledge_cards jsonb NOT NULL DEFAULT '[]', questions jsonb NOT NULL DEFAULT '[]', created_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now())`,
    );
    await q.query(
      `CREATE TABLE IF NOT EXISTS lesson_progress (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, lesson_id uuid NOT NULL REFERENCES lessons(id) ON DELETE CASCADE, progress double precision NOT NULL DEFAULT 0, answered_count integer NOT NULL DEFAULT 0, correct_count integer NOT NULL DEFAULT 0, completed_at timestamptz, created_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now(), UNIQUE(user_id,lesson_id))`,
    );
    await q.query(
      `CREATE TABLE IF NOT EXISTS trade_journals (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, mode trade_journals_mode_enum NOT NULL, trade_date date, symbol varchar NOT NULL, direction trade_journals_direction_enum NOT NULL, entry_at timestamptz, holding_hours double precision, management varchar NOT NULL DEFAULT 'Xử lý lệnh', risk_reward double precision, pnl double precision, timeframe_pair varchar, price_movement varchar, process_image_urls jsonb NOT NULL DEFAULT '[]', idea text, execution text, result text, created_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now())`,
    );
    await q.query(
      `CREATE INDEX IF NOT EXISTS idx_trade_journals_user_mode_date ON trade_journals(user_id,mode,trade_date)`,
    );
    await q.query(
      `CREATE TABLE IF NOT EXISTS trading_plans (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, scope trading_plans_scope_enum NOT NULL, period_key varchar NOT NULL, title varchar NOT NULL, content_delta jsonb NOT NULL DEFAULT '[]', timeframe_pairs jsonb NOT NULL DEFAULT '[]', inherited_plan_id uuid, image_urls jsonb NOT NULL DEFAULT '[]', created_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now(), UNIQUE(user_id,scope,period_key))`,
    );
    await q.query(
      `CREATE TABLE IF NOT EXISTS daily_checkins (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, checkin_date date NOT NULL, scores jsonb NOT NULL, total_score double precision NOT NULL, created_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now(), UNIQUE(user_id,checkin_date))`,
    );
    await q.query(
      `CREATE TABLE IF NOT EXISTS media_assets (id uuid PRIMARY KEY DEFAULT uuid_generate_v4(), owner_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, drive_file_id varchar, name varchar NOT NULL, mime_type varchar NOT NULL, remote_url text NOT NULL, thumbnail_url text, local_reference text, size_bytes bigint NOT NULL DEFAULT 0, context_type varchar NOT NULL DEFAULT 'GENERAL', created_at timestamp NOT NULL DEFAULT now())`,
    );
  }
  async down(q: QueryRunner) {
    for (const table of [
      'media_assets',
      'daily_checkins',
      'trading_plans',
      'trade_journals',
      'lesson_progress',
      'lessons',
    ])
      await q.query(`DROP TABLE IF EXISTS ${table}`);
    for (const type of [
      'trading_plans_scope_enum',
      'trade_journals_direction_enum',
      'trade_journals_mode_enum',
      'lessons_tier_enum',
    ])
      await q.query(`DROP TYPE IF EXISTS ${type}`);
  }
}
