import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreateFeaturedTradeDto } from './dto/create-featured-trade.dto';
import { UpdateFeaturedTradeDto } from './dto/update-featured-trade.dto';
import { FeaturedTrade } from './featured-trade.entity';
import { FeaturedTradeImagesService } from './featured-trade-images.service';

@Injectable()
export class FeaturedTradeService {
  constructor(
    @InjectRepository(FeaturedTrade)
    private readonly repo: Repository<FeaturedTrade>,
    private readonly images: FeaturedTradeImagesService,
  ) {}

  publicForWeek(weekStart?: string) {
    if (!weekStart) return null;
    return this.repo.findOne({ where: { weekStart, isActive: true } });
  }

  adminList() {
    return this.repo.find({ order: { weekStart: 'DESC', updatedAt: 'DESC' } });
  }

  async create(dto: CreateFeaturedTradeDto) {
    const existing = await this.repo.findOne({
      where: { weekStart: dto.weekStart },
    });
    if (existing) {
      const next = this.normalize(dto);
      if (next.imageUrls) {
        const nextImageUrls = next.imageUrls;
        await this.images.remove(
          existing.imageUrls.filter((url) => !nextImageUrls.includes(url)),
        );
      }
      Object.assign(existing, next);
      return this.repo.save(existing);
    }
    return this.repo.save(this.repo.create(this.normalize(dto)));
  }

  async update(id: string, dto: UpdateFeaturedTradeDto) {
    const item = await this.repo.findOne({ where: { id } });
    if (!item) throw new NotFoundException('Giao dịch nổi bật không tồn tại');
    const next = this.normalize(dto);
    if (next.imageUrls) {
      const nextImageUrls = next.imageUrls;
      await this.images.remove(
        item.imageUrls.filter((url) => !nextImageUrls.includes(url)),
      );
    }
    Object.assign(item, next);
    if (dto.isActive !== undefined) item.isActive = dto.isActive;
    return this.repo.save(item);
  }

  async remove(id: string) {
    const item = await this.repo.findOne({ where: { id } });
    if (!item) throw new NotFoundException('Giao dịch nổi bật không tồn tại');
    await this.images.remove(item.imageUrls);
    await this.repo.remove(item);
    return { success: true };
  }

  private normalize(dto: CreateFeaturedTradeDto | UpdateFeaturedTradeDto) {
    return {
      ...(dto.weekStart !== undefined ? { weekStart: dto.weekStart } : {}),
      ...(dto.imageUrls !== undefined
        ? { imageUrls: dto.imageUrls.map((url) => url.trim()).filter(Boolean) }
        : {}),
      ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
    };
  }
}
