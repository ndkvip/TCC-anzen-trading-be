import { MigrationInterface, QueryRunner } from 'typeorm';

export class RedNewsVisibilityRestore20261031010000
  implements MigrationInterface
{
  name = 'RedNewsVisibilityRestore20261031010000';

  async up(q: QueryRunner) {
    // Restore calendar rows hidden by the old two-day cleanup. Admin hides are
    // preserved once visibility_override has been explicitly set.
    await q.query(
      `UPDATE red_news
       SET is_active = TRUE
       WHERE source = 'FOREX_FACTORY_CALENDAR'
         AND visibility_override IS NULL`,
    );
  }

  async down(_q: QueryRunner) {
    // Visibility is intentionally not reverted: the old cleanup was the bug.
  }
}
