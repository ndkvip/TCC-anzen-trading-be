import { MigrationInterface, QueryRunner } from 'typeorm';

export class FeaturedTradeArticles20261007000000 implements MigrationInterface {
  name = 'FeaturedTradeArticles20261007000000';

  async up(q: QueryRunner) {
    await q.query(`
      ALTER TABLE featured_trades
        ADD COLUMN IF NOT EXISTS summary text,
        ADD COLUMN IF NOT EXISTS cover_image_url text,
        ADD COLUMN IF NOT EXISTS content_blocks jsonb NOT NULL DEFAULT '[]'::jsonb,
        ADD COLUMN IF NOT EXISTS title varchar NOT NULL DEFAULT ''
    `);
    // There may be a generated TypeORM name, so remove every unique constraint
    // whose definition includes week_start and allow multiple articles per week.
    await q.query(`
      UPDATE featured_trades
      SET title = CASE WHEN title IS NULL OR btrim(title) = '' THEN 'Giao dịch nổi bật tuần ' || week_start::text ELSE title END,
          cover_image_url = CASE WHEN cover_image_url IS NULL AND jsonb_array_length(image_urls) > 0 THEN image_urls->>0 ELSE cover_image_url END,
          content_blocks = CASE
            WHEN jsonb_array_length(content_blocks) = 0 AND jsonb_array_length(image_urls) > 0 THEN
              (SELECT COALESCE(jsonb_agg(jsonb_build_object('type', 'image', 'imageUrl', value)), '[]'::jsonb)
               FROM jsonb_array_elements_text(image_urls) AS value)
            ELSE content_blocks
          END
      WHERE title IS NULL OR btrim(title) = '' OR cover_image_url IS NULL OR jsonb_array_length(content_blocks) = 0;
    `);
    await q.query(
      `ALTER TABLE featured_trades ALTER COLUMN title SET NOT NULL`,
    );
    await q.query(`
      DO $$
      DECLARE constraint_name text;
      BEGIN
        FOR constraint_name IN
          SELECT conname
          FROM pg_constraint
          WHERE conrelid = 'featured_trades'::regclass
            AND contype = 'u'
            AND pg_get_constraintdef(oid) ILIKE '%week_start%'
        LOOP
          EXECUTE format('ALTER TABLE featured_trades DROP CONSTRAINT IF EXISTS %I', constraint_name);
        END LOOP;
      END $$;
    `);
  }

  async down(q: QueryRunner) {
    await q.query(
      'ALTER TABLE featured_trades ADD CONSTRAINT featured_trades_week_start_key UNIQUE (week_start)',
    );
    await q.query(
      'ALTER TABLE featured_trades DROP COLUMN IF EXISTS content_blocks, DROP COLUMN IF EXISTS cover_image_url, DROP COLUMN IF EXISTS summary',
    );
  }
}
