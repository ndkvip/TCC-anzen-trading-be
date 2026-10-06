import { MigrationInterface, QueryRunner } from 'typeorm';

export class DriveMediaFolders20260903000000 implements MigrationInterface {
  name = 'DriveMediaFolders20260903000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE media_assets ADD COLUMN IF NOT EXISTS drive_folder_id varchar`,
    );
    await queryRunner.query(
      `ALTER TABLE media_assets ADD COLUMN IF NOT EXISTS folder_path text`,
    );
    await queryRunner.query(
      `ALTER TABLE media_assets ADD COLUMN IF NOT EXISTS context_id varchar`,
    );
    await queryRunner.query(
      `UPDATE media_assets SET folder_path = CASE
        WHEN context_type = 'JOURNAL' THEN 'Nhật ký giao dịch/' || owner_id::text
        WHEN context_type = 'PLAN' THEN 'Plan giao dịch/' || owner_id::text
        ELSE 'Khác/' || owner_id::text
      END WHERE folder_path IS NULL`,
    );
    await queryRunner.query(
      `ALTER TABLE media_assets ALTER COLUMN folder_path SET NOT NULL`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS idx_media_assets_context ON media_assets(context_type, context_id)`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS idx_media_assets_context`);
    await queryRunner.query(
      `ALTER TABLE media_assets DROP COLUMN IF EXISTS context_id`,
    );
    await queryRunner.query(
      `ALTER TABLE media_assets DROP COLUMN IF EXISTS folder_path`,
    );
    await queryRunner.query(
      `ALTER TABLE media_assets DROP COLUMN IF EXISTS drive_folder_id`,
    );
  }
}
