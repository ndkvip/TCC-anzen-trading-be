import { MigrationInterface, QueryRunner } from 'typeorm';

export class UnpublishEmptyLessons20260929000000 implements MigrationInterface {
  name = 'UnpublishEmptyLessons20260929000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      UPDATE "lessons"
      SET "is_published" = false
      WHERE "is_published" = true
        AND (
          jsonb_array_length(COALESCE("knowledge_cards", '[]'::jsonb)) = 0
          OR jsonb_array_length(COALESCE("questions", '[]'::jsonb)) = 0
        )
    `);
  }

  async down(): Promise<void> {
    // Empty lessons cannot be safely republished automatically.
  }
}
