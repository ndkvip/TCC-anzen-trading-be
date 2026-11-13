import { BadRequestException } from '@nestjs/common';

export const LEGACY_PLAN_SYMBOL = 'GENERAL';
export const PLAN_SYMBOL_PATTERN = /^[A-Z0-9][A-Z0-9._/-]{0,29}$/;

export function normalizePlanSymbol(
  value: unknown = LEGACY_PLAN_SYMBOL,
): string {
  if (typeof value !== 'string') {
    throw new BadRequestException('Mã tài sản không hợp lệ');
  }
  const symbol = value.trim().toUpperCase();
  if (!PLAN_SYMBOL_PATTERN.test(symbol)) {
    throw new BadRequestException(
      'Mã tài sản phải có 1-30 ký tự chữ, số hoặc . _ / -',
    );
  }
  return symbol;
}
