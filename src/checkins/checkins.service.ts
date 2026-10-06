import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { DailyCheckin } from './checkin.entity';
@Injectable()
export class CheckinsService {
  constructor(
    @InjectRepository(DailyCheckin)
    private readonly repo: Repository<DailyCheckin>,
  ) {}
  list(userId: string) {
    return this.repo.find({
      where: { userId },
      order: { checkinDate: 'DESC' },
      take: 30,
    });
  }
  async upsert(userId: string, date: string, scores: number[]) {
    if (
      scores.length !== 5 ||
      scores.some((x) => !Number.isInteger(x) || x < 0 || x > 4)
    )
      throw new BadRequestException(
        'Điểm danh phải có đúng 5 tiêu chí, mỗi tiêu chí từ 0 đến 4',
      );
    let row = await this.repo.findOne({ where: { userId, checkinDate: date } });
    row ??= this.repo.create({ userId, checkinDate: date });
    row.scores = scores;
    row.totalScore = scores.reduce((sum, value) => sum + value, 0) / 2;
    const saved = await this.repo.save(row);
    const stale = await this.repo.find({
      where: { userId },
      order: { checkinDate: 'DESC' },
      skip: 30,
    });
    if (stale.length) await this.repo.remove(stale);
    return saved;
  }
  adminList(userId?: string) {
    return this.repo.find({
      where: userId ? { userId } : {},
      order: { checkinDate: 'DESC' },
      take: 300,
    });
  }
}
