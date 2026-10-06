import { MigrationInterface, QueryRunner } from 'typeorm';

export class InitialSchema20260831000000 implements MigrationInterface {
  name = 'InitialSchema20260831000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "users_role_enum" AS ENUM ('ADMIN', 'STUDENT');
      EXCEPTION WHEN duplicate_object THEN NULL;
      END $$;
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "users_account_tier_enum" AS ENUM ('STANDARD', 'VIP1', 'VIP2');
      EXCEPTION WHEN duplicate_object THEN NULL;
      END $$;
    `);
    await queryRunner.query(`
      DO $$ BEGIN
        CREATE TYPE "users_learning_tier_enum" AS ENUM ('BASIC', 'ADVANCED');
      EXCEPTION WHEN duplicate_object THEN NULL;
      END $$;
    `);

    const usersExists = await queryRunner.hasTable('users');
    if (!usersExists) {
      await queryRunner.query(`
        CREATE TABLE "users" (
          "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
          "email" varchar NOT NULL,
          "password_hash" varchar NOT NULL,
          "name" varchar NOT NULL,
          "role" "users_role_enum" NOT NULL DEFAULT 'STUDENT',
          "account_tier" "users_account_tier_enum" NOT NULL DEFAULT 'STANDARD',
          "learning_tier" "users_learning_tier_enum" NOT NULL DEFAULT 'BASIC',
          "email_verified" boolean NOT NULL DEFAULT false,
          "verification_otp_hash" varchar,
          "verification_otp_expires_at" timestamptz,
          "verification_otp_last_sent_at" timestamptz,
          "verification_otp_attempts" integer NOT NULL DEFAULT 0,
          "is_active" boolean NOT NULL DEFAULT true,
          "current_device_id" varchar,
          "token_version" integer NOT NULL DEFAULT 0,
          "reset_token_hash" varchar,
          "reset_token_expires_at" timestamptz,
          "reset_otp_hash" varchar,
          "reset_otp_expires_at" timestamptz,
          "reset_otp_last_sent_at" timestamptz,
          "reset_otp_attempts" integer NOT NULL DEFAULT 0,
          "created_at" timestamp NOT NULL DEFAULT now(),
          "updated_at" timestamp NOT NULL DEFAULT now(),
          CONSTRAINT "PK_users_id" PRIMARY KEY ("id"),
          CONSTRAINT "UQ_users_email" UNIQUE ("email")
        )
      `);
    } else {
      const table = await queryRunner.getTable('users');
      const legacy = table?.findColumnByName('isActive');
      const current = table?.findColumnByName('is_active');
      if (legacy && !current) {
        await queryRunner.renameColumn('users', 'isActive', 'is_active');
      }
    }

    if (!(await queryRunner.hasTable('red_news'))) {
      await queryRunner.query(`
        CREATE TABLE "red_news" (
          "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
          "title" varchar NOT NULL,
          "description" text,
          "release_at" timestamptz NOT NULL,
          "is_active" boolean NOT NULL DEFAULT true,
          "created_at" timestamp NOT NULL DEFAULT now(),
          "updated_at" timestamp NOT NULL DEFAULT now(),
          CONSTRAINT "PK_red_news_id" PRIMARY KEY ("id")
        )
      `);
    }
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('DROP TABLE IF EXISTS "red_news"');
    await queryRunner.query('DROP TABLE IF EXISTS "users"');
    await queryRunner.query('DROP TYPE IF EXISTS "users_learning_tier_enum"');
    await queryRunner.query('DROP TYPE IF EXISTS "users_account_tier_enum"');
    await queryRunner.query('DROP TYPE IF EXISTS "users_role_enum"');
  }
}
