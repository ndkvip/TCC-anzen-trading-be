import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreateFeaturedTradeDto } from './dto/create-featured-trade.dto';
import { UpdateFeaturedTradeDto } from './dto/update-featured-trade.dto';
import { FeaturedTrade, FeaturedTradeBlock } from './featured-trade.entity';
import { FeaturedTradeImagesService } from './featured-trade-images.service';

@Injectable()
export class FeaturedTradeService {
  constructor(
    @InjectRepository(FeaturedTrade)
    private readonly repo: Repository<FeaturedTrade>,
    private readonly images: FeaturedTradeImagesService,
  ) {}

  publicForWeek(weekStart?: string) {
    if (!weekStart) return [];
    return this.repo.find({
      where: { weekStart, isActive: true },
      order: { createdAt: 'DESC' },
    });
  }

  adminList() {
    return this.repo.find({ order: { weekStart: 'DESC', updatedAt: 'DESC' } });
  }

  async create(dto: CreateFeaturedTradeDto) {
    const value = this.normalize(dto);
    this.validateArticle(value);
    return this.repo.save(this.repo.create(value));
  }

  async update(id: string, dto: UpdateFeaturedTradeDto) {
    const item = await this.repo.findOne({ where: { id } });
    if (!item) throw new NotFoundException('Giao dịch nổi bật không tồn tại');
    const next = this.normalize(dto);
    this.validateArticle({ ...item, ...next });
    const nextUrls = this.allImageUrls(next, item);
    const removedUrls = this.allImageUrls(item).filter(
      (url) => !nextUrls.includes(url),
    );
    Object.assign(item, next);
    const saved = await this.repo.save(item);
    await this.images.remove(await this.unreferencedUrls(removedUrls));
    return saved;
  }

  async remove(id: string) {
    const item = await this.repo.findOne({ where: { id } });
    if (!item) throw new NotFoundException('Giao dịch nổi bật không tồn tại');
    const urls = this.allImageUrls(item);
    await this.repo.remove(item);
    await this.images.remove(await this.unreferencedUrls(urls));
    return { success: true };
  }

  private normalize(dto: CreateFeaturedTradeDto | UpdateFeaturedTradeDto) {
    const blocks = dto.contentBlocks
      ?.map((block): FeaturedTradeBlock =>
        block.type === 'text'
          ? { type: 'text', text: block.text?.trim() ?? '' }
          : { type: 'image', imageUrl: block.imageUrl?.trim() ?? '' },
      )
      .filter((block) =>
        block.type === 'image' ? Boolean(block.imageUrl) : Boolean(block.text),
      );
    const imageUrls = dto.imageUrls?.map((url) => url.trim()).filter(Boolean);
    return {
      ...(dto.weekStart !== undefined ? { weekStart: dto.weekStart } : {}),
      ...(dto.title !== undefined ? { title: dto.title.trim() } : {}),
      ...(dto.summary !== undefined
        ? { summary: dto.summary.trim() || null }
        : {}),
      ...(dto.coverImageUrl !== undefined
        ? { coverImageUrl: dto.coverImageUrl.trim() || null }
        : {}),
      ...(blocks !== undefined
        ? { contentBlocks: blocks, imageUrls: imageUrls ?? [] }
        : {}),
      ...(imageUrls !== undefined ? { imageUrls } : {}),
      ...(dto.isActive !== undefined ? { isActive: dto.isActive } : {}),
    };
  }

  private validateArticle(value: Partial<FeaturedTrade>) {
    if (!value.title?.trim())
      throw new BadRequestException('Vui lòng nhập tiêu đề bài');
    if (!value.contentBlocks?.length && !value.imageUrls?.length)
      throw new BadRequestException(
        'Bài viết cần ít nhất một đoạn chữ hoặc hình ảnh',
      );
  }

  private async unreferencedUrls(urls: string[]) {
    if (!urls.length) return [];
    const articles = await this.repo.find();
    const referenced = new Set(
      articles.flatMap((article) => this.allImageUrls(article)),
    );
    return urls.filter((url) => !referenced.has(url));
  }

  private allImageUrls(
    value: Partial<FeaturedTrade>,
    fallback?: FeaturedTrade,
  ) {
    const blocks = value.contentBlocks ?? fallback?.contentBlocks ?? [];
    const legacy = value.imageUrls ?? fallback?.imageUrls ?? [];
    const cover =
      value.coverImageUrl !== undefined
        ? value.coverImageUrl
        : fallback?.coverImageUrl;
    return [
      ...new Set([
        ...(cover ? [cover] : []),
        ...legacy,
        ...blocks
          .filter((block) => block.type === 'image' && block.imageUrl)
          .map((block) => block.imageUrl!),
      ]),
    ];
  }
}
