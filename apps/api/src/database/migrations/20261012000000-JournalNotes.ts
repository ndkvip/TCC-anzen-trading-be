import { MigrationInterface, QueryRunner } from 'typeorm';

export class JournalNotes20261012000000 implements MigrationInterface {
  name = 'JournalNotes20261012000000';
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trade_journals" ADD COLUMN "notes_delta" jsonb NOT NULL DEFAULT '[]'::jsonb`,
    );
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trade_journals" DROP COLUMN "notes_delta"`,
    );
  }
}
