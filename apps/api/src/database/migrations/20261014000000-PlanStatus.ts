import { MigrationInterface, QueryRunner } from 'typeorm';

export class PlanStatus20261014000000 implements MigrationInterface {
  name = 'PlanStatus20261014000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `DO $$ BEGIN CREATE TYPE "trading_plans_status_enum" AS ENUM ('DRAFT','COMPLETED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;`,
    );
    await queryRunner.query(
      `ALTER TABLE "trading_plans" ADD COLUMN IF NOT EXISTS "status" trading_plans_status_enum NOT NULL DEFAULT 'DRAFT'`,
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trading_plans" DROP COLUMN IF EXISTS "status"`,
    );
    await queryRunner.query(`DROP TYPE IF EXISTS "trading_plans_status_enum"`);
  }
}
