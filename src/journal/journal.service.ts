import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import {
  JournalMode,
  TradeDirection,
  TradeJournal,
} from './trade-journal.entity';

export type JournalInput = Partial<
  Omit<
    Pick<
      TradeJournal,
      | 'mode'
      | 'tradeDate'
      | 'symbol'
      | 'direction'
      | 'entryAt'
      | 'holdingHours'
      | 'management'
      | 'riskReward'
      | 'pnl'
      | 'timeframePair'
      | 'priceMovement'
      | 'processImageUrls'
      | 'notesDelta'
      | 'idea'
      | 'execution'
      | 'result'
    >,
    'entryAt'
  >
> & { entryAt?: string | Date | null; id?: string };

type StrategyStats = {
  label: string;
  timeframePair: string;
  priceMovement: string;
  pnl: number;
  totalR: number;
  count: number;
  wins: number;
  winRate: number;
};

@Injectable()
export class JournalService {
  constructor(
    @InjectRepository(TradeJournal)
    private readonly repo: Repository<TradeJournal>,
  ) {}
  async list(userId: string, mode: JournalMode, date?: string) {
    this.validateQuery(mode, date);
    const where: Record<string, unknown> = { userId, mode };
    if (mode === JournalMode.INTRA_DAY && date) where.tradeDate = date;
    return this.repo.find({
      where,
      order: { tradeDate: 'DESC', createdAt: 'DESC' },
    });
  }
  async summary(userId: string, mode: JournalMode, from?: string, to?: string) {
    this.validateQuery(mode, from);
    this.validateQuery(mode, to);
    if (from && to && from > to)
      throw new BadRequestException('Khoảng thời gian không hợp lệ');
    const rows = await this.repo.find({ where: { userId, mode } });
    const filtered = rows.filter((row) => {
      const date =
        row.tradeDate ??
        row.entryAt?.toISOString().slice(0, 10) ??
        row.createdAt?.toISOString().slice(0, 10);
      return (
        (!from && !to) ||
        (!!date && (!from || date >= from) && (!to || date <= to))
      );
    });
    const closed = filtered.filter((row) => row.pnl != null);
    const wins = closed.filter((row) => (row.pnl ?? 0) > 0).length;
    const losses = closed.filter((row) => (row.pnl ?? 0) < 0).length;
    return {
      mode,
      count: filtered.length,
      running: filtered.length - closed.length,
      closed: closed.length,
      wins,
      losses,
      breakeven: closed.length - wins - losses,
      winRate: closed.length ? (wins / closed.length) * 100 : 0,
      pnl: closed.reduce((sum, row) => sum + (row.pnl ?? 0), 0),
      totalR: closed.reduce((sum, row) => sum + (row.riskReward ?? 0), 0),
      bestStrategy: this.bestStrategy(closed),
      bestStrategyStats: this.bestStrategyStats(closed),
    };
  }
  async create(userId: string, input: JournalInput) {
    const row = this.repo.create(this.normalizeCreate(userId, input));
    if (!input.id) return this.repo.save(row);
    // A stable client UUID makes retries safe when the response is lost.
    const existing = await this.repo.findOne({ where: { id: input.id } });
    if (existing) {
      if (existing.userId !== userId)
        throw new ConflictException('Mã nhật ký đã được sử dụng');
      return existing;
    }
    try {
      await this.repo.insert({ ...row, id: input.id });
    } catch (error) {
      if ((error as { code?: string }).code !== '23505') throw error;
      const saved = await this.repo.findOne({
        where: { id: input.id, userId },
      });
      if (!saved) throw new ConflictException('Mã nhật ký đã được sử dụng');
      return saved;
    }
    return this.repo.findOneOrFail({ where: { id: input.id, userId } });
  }
  async update(userId: string, id: string, input: JournalInput) {
    const row = await this.repo.findOne({ where: { id, userId } });
    if (!row) throw new NotFoundException('Nhật ký không tồn tại');
    const updated = { ...row, ...this.normalizeUpdate(input) };
    if (updated.mode === JournalMode.INTRA_DAY && !updated.tradeDate) {
      throw new BadRequestException('Nhật ký trong ngày cần ngày giao dịch');
    }
    if (updated.mode === JournalMode.SWING) updated.tradeDate = null;
    Object.assign(row, updated);
    return this.repo.save(row);
  }
  async remove(userId: string, id: string) {
    const row = await this.repo.findOne({ where: { id, userId } });
    if (!row) throw new NotFoundException('Nhật ký không tồn tại');
    await this.repo.remove(row);
    return { success: true };
  }
  adminList(userId?: string) {
    return this.repo.find({
      where: userId ? { userId } : {},
      order: { createdAt: 'DESC' },
      take: 300,
    });
  }
  private normalizeCreate(userId: string, input: JournalInput) {
    const mode = input.mode ?? JournalMode.INTRA_DAY;
    return {
      ...this.normalizeUpdate(input),
      userId,
      mode,
      symbol: input.symbol?.trim().toUpperCase() || 'BTCUSDT',
      direction: input.direction ?? TradeDirection.LONG,
      tradeDate:
        mode === JournalMode.SWING
          ? null
          : (input.tradeDate ?? new Date().toISOString().slice(0, 10)),
      pnl: input.pnl === undefined ? null : input.pnl,
    };
  }
  private normalizeUpdate(input: JournalInput) {
    if (input.symbol !== undefined && !input.symbol?.trim()) {
      throw new BadRequestException('Vui lòng nhập mã tài sản');
    }
    if (input.tradeDate != null)
      this.validateQuery(input.mode ?? JournalMode.INTRA_DAY, input.tradeDate);
    const { id: _id, ...fields } = input;
    return {
      ...fields,
      ...(input.entryAt !== undefined
        ? {
            entryAt:
              typeof input.entryAt === 'string'
                ? new Date(input.entryAt)
                : input.entryAt,
          }
        : {}),
      ...(input.symbol !== undefined
        ? { symbol: input.symbol.trim().toUpperCase() }
        : {}),
      ...(input.mode === JournalMode.SWING ? { tradeDate: null } : {}),
    };
  }
  private validateQuery(mode: JournalMode, date?: string) {
    if (!Object.values(JournalMode).includes(mode)) {
      throw new BadRequestException('Loại nhật ký không hợp lệ');
    }
    if (
      date &&
      (!/^\d{4}-\d{2}-\d{2}$/.test(date) ||
        Number.isNaN(Date.parse(date)) ||
        new Date(date).toISOString().slice(0, 10) !== date)
    ) {
      throw new BadRequestException('Ngày giao dịch không hợp lệ');
    }
  }
  private bestStrategy(rows: TradeJournal[]) {
    return this.bestStrategyStats(rows)?.priceMovement ?? null;
  }

  private bestStrategyStats(rows: TradeJournal[]): StrategyStats | null {
    const totals = new Map<
      string,
      {
        timeframePair: string;
        priceMovement: string;
        pnl: number;
        totalR: number;
        count: number;
        wins: number;
      }
    >();
    for (const row of rows) {
      const timeframePair = row.timeframePair || 'Chưa chọn khung';
      const priceMovement = row.priceMovement || 'Chưa phân loại';
      const key = `${timeframePair}|${priceMovement}`;
      const item = totals.get(key) ?? {
        timeframePair,
        priceMovement,
        pnl: 0,
        totalR: 0,
        count: 0,
        wins: 0,
      };
      item.pnl += row.pnl ?? 0;
      item.totalR += row.riskReward ?? 0;
      item.count += 1;
      if ((row.pnl ?? 0) > 0) item.wins += 1;
      totals.set(key, item);
    }
    const best = [...totals.values()].sort((a, b) => {
      if (b.pnl !== a.pnl) return b.pnl - a.pnl;
      if (b.totalR !== a.totalR) return b.totalR - a.totalR;
      return b.count - a.count;
    })[0];
    if (!best) return null;
    return {
      ...best,
      label: `${best.timeframePair} · ${best.priceMovement}`,
      winRate: best.count ? (best.wins / best.count) * 100 : 0,
    };
  }
}
