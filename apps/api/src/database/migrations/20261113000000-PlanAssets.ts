import {
  MigrationInterface,
  QueryRunner,
  TableIndex,
  TableUnique,
} from 'typeorm';

const oldColumns = ['user_id', 'scope', 'period_key'];
const assetIndex = 'UQ_trading_plans_user_symbol_period';
const isOldIdentity = (columns: string[]) =>
  columns.length === oldColumns.length &&
  oldColumns.every((column) => columns.includes(column));

export class PlanAssets20261113000000 implements MigrationInterface {
  name = 'PlanAssets20261113000000';

  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "trading_plans" ADD COLUMN "symbol" varchar(30) NOT NULL DEFAULT 'GENERAL'`,
    );
    const table = await queryRunner.getTable('trading_plans');
    if (!table) throw new Error('trading_plans table is missing');
    // Older databases may have the raw SQL constraint, a TypeORM index, or both.
    for (const unique of table.uniques.filter((item) =>
      isOldIdentity(item.columnNames),
    )) {
      await queryRunner.dropUniqueConstraint(table, unique);
    }
    for (const index of table.indices.filter(
      (item) => item.isUnique && isOldIdentity(item.columnNames),
    )) {
      await queryRunner.dropIndex(table, index);
    }
    await queryRunner.createIndex(
      'trading_plans',
      new TableIndex({
        name: assetIndex,
        columnNames: ['user_id', 'symbol', 'scope', 'period_key'],
        isUnique: true,
      }),
    );
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    const assigned = await queryRunner.query(
      `SELECT 1 FROM "trading_plans" WHERE symbol <> 'GENERAL' LIMIT 1`,
    );
    if (assigned.length) {
      throw new Error(
        'Cannot revert PlanAssets: plans have assigned assets. Export and reconcile plans first.',
      );
    }
    await queryRunner.dropIndex('trading_plans', assetIndex);
    await queryRunner.createUniqueConstraint(
      'trading_plans',
      new TableUnique({
        name: 'UQ_trading_plans_user_period',
        columnNames: oldColumns,
      }),
    );
    await queryRunner.query(`ALTER TABLE "trading_plans" DROP COLUMN "symbol"`);
  }
}
