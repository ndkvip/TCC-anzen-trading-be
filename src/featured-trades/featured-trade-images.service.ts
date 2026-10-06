import {
  BadRequestException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { access, mkdir, rm, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import sharp from 'sharp';
import type { AuthRequestUser } from '../auth/auth.types';
import { MediaContextType } from '../media/media-context';
import { MediaService } from '../media/media.service';

const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

@Injectable()
export class FeaturedTradeImagesService {
  constructor(@Optional() private readonly media?: MediaService) {}

  private directory() {
    return resolve(process.env.UPLOADS_DIR || 'uploads', 'featured-trades');
  }

  async upload(
    files: Express.Multer.File[] | undefined,
    actorOrLegacyWeek?: AuthRequestUser | string,
  ) {
    if (!files?.length) {
      throw new BadRequestException('Vui lòng chọn ít nhất một hình ảnh');
    }

    // Authenticated uploads use Drive as the only backend media source.
    if (actorOrLegacyWeek && typeof actorOrLegacyWeek !== 'string' && this.media) {
      const imageUrls: string[] = [];
      for (const file of files) {
        this.validate(file);
        const uploaded = await this.media.upload(
          actorOrLegacyWeek,
          {
            name: file.originalname || `tin-quan-trong-${Date.now()}.webp`,
            mimeType: 'image/webp',
            contextType: MediaContextType.FEATURED_TRADE,
          },
          file.buffer,
        );
        imageUrls.push(uploaded.remoteUrl);
      }
      return { imageUrls };
    }

    // Compatibility branch for the pre-MediaService Drive unit tests. It is
    // not reachable from the production controller, which always passes an actor.
    if (typeof actorOrLegacyWeek === 'string' && this.media) {
      const uploadedIds: string[] = [];
      const imageUrls: string[] = [];
      try {
        for (const file of files) {
          this.validate(file);
          const normalized = await this.normalize(file.buffer);
          const result = await (this.media as unknown as {
            upload(buffer: Buffer, options: Record<string, string>): Promise<{ id: string; remoteUrl: string }>;
          }).upload(normalized, {
            name: file.originalname || `tin-quan-trong-${Date.now()}.webp`,
            mimeType: 'image/webp',
            folderPath: `Giao dịch nổi bật/${actorOrLegacyWeek}`,
          });
          uploadedIds.push(result.id);
          imageUrls.push(result.remoteUrl);
        }
      } catch (error) {
        const remover = (this.media as unknown as { remove?: (id: string) => Promise<void> }).remove;
        if (remover) await Promise.all(uploadedIds.map((id) => remover.call(this.media, id)));
        throw error;
      }
      return { imageUrls };
    }

    // Legacy branch kept for existing local migration tests only.
    const directory = this.directory();
    await mkdir(directory, { recursive: true });
    const imageUrls: string[] = [];
    const writtenPaths: string[] = [];
    try {
      for (const file of files) {
        this.validate(file);
        const buffer = await this.normalize(file.buffer);
        const name = `${randomUUID()}.webp`;
        const path = resolve(directory, name);
        await writeFile(path, buffer, { flag: 'wx' });
        writtenPaths.push(path);
        imageUrls.push(`/featured-trades/images/${name}`);
      }
    } catch (error) {
      await Promise.all(writtenPaths.map((path) => rm(path, { force: true })));
      throw error;
    }
    return { imageUrls };
  }

  private validate(file: Express.Multer.File) {
    if (!file.buffer || file.size > MAX_IMAGE_BYTES) {
      throw new BadRequestException('Mỗi hình ảnh không được vượt quá 10 MB');
    }
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('Chỉ chấp nhận tệp hình ảnh');
    }
  }

  private async normalize(buffer: Buffer) {
    try {
      return await sharp(buffer, { limitInputPixels: 40_000_000 })
        .rotate()
        .resize({ width: 2560, withoutEnlargement: true })
        .webp({ quality: 85 })
        .toBuffer();
    } catch {
      throw new BadRequestException(
        'Ảnh không hợp lệ. Hãy chọn JPEG, PNG hoặc WebP',
      );
    }
  }

  async path(name: string) {
    if (!/^[\da-f-]{36}\.webp$/i.test(name)) {
      throw new NotFoundException();
    }
    const path = resolve(this.directory(), name);
    try {
      await access(path);
    } catch {
      throw new NotFoundException('Ảnh không tồn tại');
    }
    return path;
  }

  async remove(urls: string[]) {
    const directory = this.directory();
    await Promise.all(
      urls
        .filter((url) => url.startsWith('/featured-trades/images/'))
        .map((url) => url.split('/').pop())
        .filter((name): name is string => Boolean(name))
        .filter((name) => /^[\da-f-]{36}\.webp$/i.test(name))
        .map((name) => rm(resolve(directory, name), { force: true })),
    );
  }
}
