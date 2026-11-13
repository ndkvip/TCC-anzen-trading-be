import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PlanScope, PlanStatus, TradingPlan } from './plan.entity';
import { normalizePlanSymbol } from './plan-symbol';
export type PlanInput = Partial<
  Pick<
    TradingPlan,
    | 'symbol'
    | 'scope'
    | 'periodKey'
    | 'title'
    | 'status'
    | 'contentDelta'
    | 'timeframePairs'
    | 'imageUrls'
  >
>;
@Injectable()
export class PlansService {
  constructor(
    @InjectRepository(TradingPlan)
    private readonly repo: Repository<TradingPlan>,
  ) {}
  async list(userId: string, scope?: PlanScope, symbol?: string) {
    return this.repo.find({
      where: {
        userId,
        ...(scope ? { scope } : {}),
        ...(symbol === undefined
          ? {}
          : { symbol: normalizePlanSymbol(symbol) }),
      },
      order: { periodKey: 'DESC' },
    });
  }
  async get(
    userId: string,
    scope: PlanScope,
    periodKey: string,
    asset?: string,
  ) {
    const symbol = normalizePlanSymbol(asset);
    const row = await this.repo.findOne({
      where: { userId, symbol, scope, periodKey },
    });
    if (row) return row;
    const inherited = await this.inherited(userId, symbol, scope, periodKey);
    return {
      id: `draft-${encodeURIComponent(symbol)}-${scope}-${periodKey}`,
      userId,
      symbol,
      scope,
      periodKey,
      title: this.title(scope, periodKey),
      status: PlanStatus.DRAFT,
      contentDelta: inherited?.contentDelta ?? [],
      timeframePairs: [],
      inheritedPlanId: inherited?.id ?? null,
      imageUrls: inherited?.imageUrls ?? [],
      inheritedFrom: inherited?.title ?? null,
    };
  }
  async upsert(userId: string, input: PlanInput) {
    const symbol = normalizePlanSymbol(input.symbol);
    const scope = input.scope ?? PlanScope.DAY;
    const periodKey = input.periodKey ?? new Date().toISOString().slice(0, 10);
    let row = await this.repo.findOne({
      where: { userId, symbol, scope, periodKey },
    });
    row ??= this.repo.create({ userId, symbol, scope, periodKey });
    Object.assign(row, {
      title: input.title ?? this.title(scope, periodKey),
      status: input.status ?? row.status ?? PlanStatus.DRAFT,
      contentDelta: input.contentDelta ?? [],
      timeframePairs: input.timeframePairs ?? [],
      imageUrls: input.imageUrls ?? [],
    });
    const inherited = await this.inherited(userId, symbol, scope, periodKey);
    row.inheritedPlanId = inherited?.id ?? null;
    return this.repo.save(row);
  }
  async remove(userId: string, id: string) {
    const row = await this.repo.findOne({ where: { userId, id } });
    if (!row) throw new NotFoundException('Plan không tồn tại');
    await this.repo.remove(row);
    return { success: true };
  }
  adminList(userId?: string, symbol?: string) {
    return this.repo.find({
      where: {
        ...(userId ? { userId } : {}),
        ...(symbol === undefined
          ? {}
          : { symbol: normalizePlanSymbol(symbol) }),
      },
      order: { updatedAt: 'DESC' },
      take: 300,
    });
  }
  private async inherited(
    userId: string,
    symbol: string,
    scope: PlanScope,
    key: string,
  ) {
    if (scope === PlanScope.MONTH) return null;
    if (scope === PlanScope.WEEK)
      return this.repo.findOne({
        where: {
          userId,
          symbol,
          scope: PlanScope.MONTH,
          periodKey: key.slice(0, 7),
        },
      });
    const date = new Date(`${key}T12:00:00Z`);
    const monday = new Date(date);
    monday.setUTCDate(date.getUTCDate() - (date.getUTCDay() || 7) + 1);
    const weekKey = monday.toISOString().slice(0, 10);
    const week = await this.repo.findOne({
      where: { userId, symbol, scope: PlanScope.WEEK, periodKey: weekKey },
    });
    return (
      week ??
      this.repo.findOne({
        where: {
          userId,
          symbol,
          scope: PlanScope.MONTH,
          periodKey: weekKey.slice(0, 7),
        },
      })
    );
  }
  private title(scope: PlanScope, key: string) {
    if (scope === PlanScope.MONTH)
      return `Plan tháng ${Number(key.slice(5, 7))}`;
    if (scope === PlanScope.WEEK) {
      const date = new Date(`${key}T12:00:00Z`);
      const end = new Date(date);
      end.setUTCDate(date.getUTCDate() + 6);
      return `Plan tuần ${key.slice(8, 10)}/${key.slice(5, 7)} - ${end.toISOString().slice(8, 10)}/${end.toISOString().slice(5, 7)}`;
    }
    return `Plan ngày ${key.split('-').reverse().join('/')}`;
  }
}
