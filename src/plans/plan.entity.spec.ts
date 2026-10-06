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
});
