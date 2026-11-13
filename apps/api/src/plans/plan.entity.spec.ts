import { getMetadataArgsStorage } from 'typeorm';
import { TradingPlan } from './plan.entity';

describe('TradingPlan persistence mapping', () => {
  it('maps JSON plan fields to the Phase 3 snake_case columns', () => {
    const columns = getMetadataArgsStorage().columns.filter(
      (column) => column.target === TradingPlan,
    );

    expect(
      columns.find((column) => column.propertyName === 'contentDelta')?.options
        .name,
    ).toBe('content_delta');
    expect(
      columns.find((column) => column.propertyName === 'timeframePairs')
        ?.options.name,
    ).toBe('timeframe_pairs');
  });

  it('uniquely identifies a user plan by asset and period', () => {
    const storage = getMetadataArgsStorage();
    const indexes = storage.indices.filter(
      (index) => index.target === TradingPlan,
    );
    expect(
      indexes.filter((index) => index.unique).map((index) => index.columns),
    ).toEqual([['userId', 'symbol', 'scope', 'periodKey']]);
    const symbol = storage.columns.find(
      (column) =>
        column.target === TradingPlan && column.propertyName === 'symbol',
    );
    expect(symbol?.options.default).toBe('GENERAL');
    expect(symbol?.options.length).toBe(30);
  });
});
