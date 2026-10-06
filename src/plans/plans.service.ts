import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PlanScope, TradingPlan } from './plan.entity';
export type PlanInput = Partial<
  Pick<
    TradingPlan,
    | 'scope'
    | 'periodKey'
    | 'title'
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
  async list(userId: string, scope?: PlanScope) {
    return this.repo.find({
      where: scope ? { userId, scope } : { userId },
      order: { periodKey: 'DESC' },
    });
  }
  async get(userId: string, scope: PlanScope, periodKey: string) {
    const row = await this.repo.findOne({
      where: { userId, scope, periodKey },
    });
    if (row) return row;
    const inherited = await this.inherited(userId, scope, periodKey);
    return {
      id: `draft-${scope}-${periodKey}`,
      userId,
      scope,
      periodKey,
      title: this.title(scope, periodKey),
      contentDelta: inherited?.contentDelta ?? [],
      timeframePairs: [],
      inheritedPlanId: inherited?.id ?? null,
      imageUrls: inherited?.imageUrls ?? [],
      inheritedFrom: inherited?.title ?? null,
    };
  }
  async upsert(userId: string, input: PlanInput) {
    const scope = input.scope ?? PlanScope.DAY;
    const periodKey = input.periodKey ?? new Date().toISOString().slice(0, 10);
    let row = await this.repo.findOne({ where: { userId, scope, periodKey } });
    row ??= this.repo.create({ userId, scope, periodKey });
    Object.assign(row, {
      title: input.title ?? this.title(scope, periodKey),
      contentDelta: input.contentDelta ?? [],
      timeframePairs: input.timeframePairs ?? [],
      imageUrls: input.imageUrls ?? [],
    });
    const inherited = await this.inherited(userId, scope, periodKey);
    row.inheritedPlanId = inherited?.id ?? null;
    return this.repo.save(row);
  }
  async remove(userId: string, id: string) {
    const row = await this.repo.findOne({ where: { userId, id } });
    if (!row) throw new NotFoundException('Plan không tồn tại');
    await this.repo.remove(row);
    return { success: true };
  }
  adminList(userId?: string) {
    return this.repo.find({
      where: userId ? { userId } : {},
      order: { updatedAt: 'DESC' },
      take: 300,
    });
  }
  private async inherited(userId: string, scope: PlanScope, key: string) {
    if (scope === PlanScope.MONTH) return null;
    if (scope === PlanScope.WEEK)
      return this.repo.findOne({
        where: { userId, scope: PlanScope.MONTH, periodKey: key.slice(0, 7) },
      });
    const date = new Date(`${key}T12:00:00Z`);
    const monday = new Date(date);
    monday.setUTCDate(date.getUTCDate() - (date.getUTCDay() || 7) + 1);
    const weekKey = monday.toISOString().slice(0, 10);
    return this.repo.findOne({
      where: { userId, scope: PlanScope.WEEK, periodKey: weekKey },
    });
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
