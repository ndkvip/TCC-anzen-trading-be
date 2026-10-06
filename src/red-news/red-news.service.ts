import {
  Injectable,
  Logger,
  NotFoundException,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreateRedNewsDto } from './dto/create-red-news.dto';
import { UpdateRedNewsDto } from './dto/update-red-news.dto';
import { RedNews } from './red-news.entity';

type CalendarEvent = {
  title?: unknown;
  country?: unknown;
  date?: unknown;
  impact?: unknown;
};

@Injectable()
export class RedNewsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedNewsService.name);
  private syncTimer?: ReturnType<typeof setInterval>;
  private syncInProgress = false;

  constructor(
    @InjectRepository(RedNews)
    private readonly news: Repository<RedNews>,
  ) {}

  onModuleInit() {
    if (this.syncEnabled) {
      void this.syncFromCalendar();
      this.syncTimer = setInterval(
        () => void this.syncFromCalendar(),
        this.syncIntervalMs,
      );
    }
  }

  onModuleDestroy() {
    if (this.syncTimer) clearInterval(this.syncTimer);
  }

  private get syncEnabled() {
    return process.env.FOREX_FACTORY_SYNC_ENABLED !== 'false';
  }

  private get syncIntervalMs() {
    const minutes = Number(
      process.env.FOREX_FACTORY_SYNC_INTERVAL_MINUTES ?? 30,
    );
    return Math.max(Number.isFinite(minutes) ? minutes : 30, 5) * 60_000;
  }

  private get calendarUrl() {
    return (
      process.env.FOREX_FACTORY_CALENDAR_URL ??
      'https://nfs.faireconomy.media/ff_calendar_thisweek.json'
    );
  }

  listPublic() {
    return this.news.find({
      where: { isActive: true },
      order: { releaseAt: 'ASC' },
    });
  }

  listAdmin() {
    return this.news.find({ order: { releaseAt: 'ASC' } });
  }

  async syncFromCalendar() {
    if (!this.syncEnabled || this.syncInProgress)
      return { synced: 0, skipped: true };
    this.syncInProgress = true;
    try {
      const response = await fetch(this.calendarUrl, {
        headers: {
          Accept: 'application/json',
          'User-Agent': 'ANZEN-TRADING-calendar-sync/1.0',
        },
        signal: AbortSignal.timeout(10_000),
      });
      if (!response.ok) throw new Error(`calendar HTTP ${response.status}`);
      const payload = (await response.json()) as unknown;
      const events = Array.isArray(payload) ? payload : [];
      let synced = 0;
      for (const event of events) {
        const item = this.toImportantEvent(event);
        if (!item) continue;
        const existing = await this.news.findOne({
          where: { sourceKey: item.sourceKey },
        });
        if (existing) {
          // Refresh calendar metadata but preserve an admin's manual hide switch.
          existing.title = item.title;
          existing.currency = item.currency;
          existing.impact = item.impact;
          existing.releaseAt = item.releaseAt;
          existing.source = item.source;
          await this.news.save(existing);
        } else {
          await this.news.save(this.news.create(item));
        }
        synced += 1;
      }
      if (synced > 0) {
        await this.news
          .createQueryBuilder()
          .update(RedNews)
          .set({ isActive: false })
          .where('source = :source', { source: 'FOREX_FACTORY_CALENDAR' })
          .andWhere("release_at < NOW() - INTERVAL '2 days'")
          .execute();
      }
      this.logger.log(
        `Đã đồng bộ ${synced} tin quan trọng từ lịch Forex Factory`,
      );
      return { synced, skipped: false };
    } catch (error) {
      this.logger.warn(
        `Không đồng bộ được lịch Forex Factory: ${error instanceof Error ? error.message : String(error)}`,
      );
      return { synced: 0, skipped: false };
    } finally {
      this.syncInProgress = false;
    }
  }

  private toImportantEvent(event: unknown) {
    if (!event || typeof event !== 'object') return null;
    const row = event as CalendarEvent;
    if (String(row.impact ?? '').toLowerCase() !== 'high') return null;
    const title = String(row.title ?? '').trim();
    const country = String(row.country ?? '').trim();
    const date = String(row.date ?? '').trim();
    const releaseAt = new Date(date);
    if (!title || !date || Number.isNaN(releaseAt.getTime())) return null;
    const sourceKey = `ff:${date}:${country}:${title}`.toLowerCase();
    return {
      title,
      description: null,
      currency: country || null,
      impact: 'HIGH' as const,
      releaseAt,
      isActive: true,
      source: 'FOREX_FACTORY_CALENDAR' as const,
      sourceKey,
    };
  }

  create(dto: CreateRedNewsDto) {
    return this.news.save(
      this.news.create({
        title: dto.title.trim(),
        description: dto.description?.trim() || null,
        currency: dto.currency?.trim() || null,
        impact: dto.impact ?? 'HIGH',
        releaseAt: new Date(dto.releaseAt),
        source: 'MANUAL',
        sourceKey: null,
      }),
    );
  }

  async update(id: string, dto: UpdateRedNewsDto) {
    const item = await this.news.findOne({ where: { id } });
    if (!item) throw new NotFoundException('Tin quan trọng không tồn tại');

    if (dto.title !== undefined) item.title = dto.title.trim();
    if (dto.description !== undefined)
      item.description = dto.description.trim() || null;
    if (dto.currency !== undefined) item.currency = dto.currency.trim() || null;
    if (dto.releaseAt !== undefined) item.releaseAt = new Date(dto.releaseAt);
    if (dto.isActive !== undefined) item.isActive = dto.isActive;
    return this.news.save(item);
  }

  async remove(id: string) {
    const item = await this.news.findOne({ where: { id } });
    if (!item) throw new NotFoundException('Tin quan trọng không tồn tại');
    await this.news.remove(item);
    return { success: true };
  }
}
