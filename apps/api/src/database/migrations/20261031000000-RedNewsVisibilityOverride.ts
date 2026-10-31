import { MigrationInterface, QueryRunner } from 'typeorm';

export class RedNewsVisibilityOverride20261031000000
  implements MigrationInterface
{
  name = 'RedNewsVisibilityOverride20261031000000';

  async up(q: QueryRunner) {
    await q.query(
      `ALTER TABLE red_news ADD COLUMN IF NOT EXISTS visibility_override boolean`,
    );
    // Existing calendar rows that were hidden by the old expiry cleanup remain
    // calendar-managed and can be restored when they appear in a fresh feed.
    await q.query(
      `UPDATE red_news SET visibility_override = NULL WHERE source = 'FOREX_FACTORY_CALENDAR'`,
    );
    await q.query(
      `UPDATE red_news SET visibility_override = true WHERE source = 'MANUAL' AND visibility_override IS NULL`,
    );
  }

  async down(q: QueryRunner) {
    await q.query(
      `ALTER TABLE red_news DROP COLUMN IF EXISTS visibility_override`,
    );
  }
}
