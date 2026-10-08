import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import type { AuthRequestUser } from '../auth/auth.types';
import { UserRole } from '../users/user.entity';
import { MediaAsset } from './media-asset.entity';
import {
  driveFolderLayout,
  MediaContextType,
  resolveMediaFolder,
} from './media-context';
import { GoogleDriveService } from './google-drive.service';
import sharp from 'sharp';

export type RegisterMediaInput = Partial<MediaAsset> & { lessonId?: string };

@Injectable()
export class MediaService {
  constructor(
    @InjectRepository(MediaAsset) private readonly repo: Repository<MediaAsset>,
    private readonly config: ConfigService,
    private readonly drive: GoogleDriveService,
  ) {}

  list(ownerId: string) {
    return this.repo.find({ where: { ownerId }, order: { createdAt: 'DESC' } });
  }

  async removeLessonMedia(lessonId: string) {
    const assets = await this.repo.find({
      where: {
        contextId: lessonId,
        contextType: In([
          MediaContextType.LEARNING_LESSON,
          MediaContextType.LEARNING_QUESTION,
          MediaContextType.LEARNING_ANSWER,
        ]),
      },
    });

    for (const asset of assets) {
      if (asset.driveFileId) await this.drive.remove(asset.driveFileId);
    }

    if (assets.length) await this.repo.remove(assets);
    return { deleted: assets.length };
  }

  async removeFeaturedMedia(urls: string[]) {
    if (!urls.length) return;
    const assets = await this.repo.find({
      where: {
        contextType: MediaContextType.FEATURED_TRADE,
        remoteUrl: In(urls),
      },
    });
    for (const asset of assets) {
      if (asset.driveFileId) await this.drive.remove(asset.driveFileId);
      await this.repo.remove(asset);
    }
  }

  async downloadFeaturedImage(fileId: string) {
    const asset = await this.repo.findOne({
      where: {
        driveFileId: fileId,
        contextType: MediaContextType.FEATURED_TRADE,
      },
    });
    if (!asset)
      throw new NotFoundException('Ảnh giao dịch nổi bật không tồn tại');
    const image = await this.drive.download(fileId);
    return { buffer: image.buffer, mimeType: asset.mimeType || image.mimeType };
  }

  async downloadLearningImage(fileId: string, lessonId: string) {
    // A lesson can contain knowledge, question, and answer images. The file ID
    // is unique in Drive, so scope the lookup to this lesson and all learning
    // media contexts instead of assuming every image is a knowledge card.
    const asset = await this.repo.findOne({
      where: {
        driveFileId: fileId,
        contextId: lessonId,
        contextType: In([
          MediaContextType.LEARNING_LESSON,
          MediaContextType.LEARNING_QUESTION,
          MediaContextType.LEARNING_ANSWER,
        ]),
      },
    });
    if (!asset) throw new NotFoundException('Ảnh bài học không tồn tại');
    const image = await this.drive.download(fileId);
    return { buffer: image.buffer, mimeType: asset.mimeType || image.mimeType };
  }

  async upload(
    actor: AuthRequestUser,
    input: RegisterMediaInput,
    buffer: Buffer,
  ) {
    if (!Buffer.isBuffer(buffer) || buffer.length === 0)
      throw new BadRequestException('Vui lòng chọn một tệp hình ảnh');
    let normalizedBuffer: Buffer;
    try {
      normalizedBuffer = await sharp(buffer, { limitInputPixels: 40_000_000 })
        .rotate()
        .resize({ width: 2560, withoutEnlargement: true })
        .webp({ quality: 85 })
        .toBuffer();
    } catch {
      throw new BadRequestException(
        'Ảnh không hợp lệ. Hãy chọn JPEG, PNG hoặc WebP',
      );
    }
    const contextType = input.contextType ?? MediaContextType.GENERAL;
    const learningMedia = [
      MediaContextType.LEARNING_LESSON,
      MediaContextType.LEARNING_QUESTION,
      MediaContextType.LEARNING_ANSWER,
    ].includes(contextType);
    if (learningMedia && actor.role !== UserRole.ADMIN)
      throw new ForbiddenException(
        'Chỉ quản trị viên được đăng ảnh cho bài học',
      );
    const folder = resolveMediaFolder(actor.sub, contextType, input.lessonId);
    const result = await this.drive.upload(normalizedBuffer, {
      name: `${(input.name?.trim() || `image-${Date.now()}`).replace(/\.[^.]+$/, '')}.webp`,
      mimeType: 'image/webp',
      folderPath: folder.folderPath,
    });
    return this.repo.save(
      this.repo.create({
        ownerId: actor.sub,
        driveFileId: result.id,
        driveFolderId: result.folderId,
        folderPath: result.folderPath,
        name: result.name,
        mimeType: result.mimeType,
        remoteUrl: result.remoteUrl,
        thumbnailUrl: result.remoteUrl,
        localReference: input.localReference || null,
        sizeBytes: String(normalizedBuffer.byteLength),
        contextType: folder.contextType,
        contextId: folder.contextId,
      }),
    );
  }

  async register(actor: AuthRequestUser, input: RegisterMediaInput) {
    const contextType = input.contextType ?? MediaContextType.GENERAL;
    const learningMedia = [
      MediaContextType.LEARNING_LESSON,
      MediaContextType.LEARNING_QUESTION,
      MediaContextType.LEARNING_ANSWER,
    ].includes(contextType);
    if (learningMedia && actor.role !== UserRole.ADMIN)
      throw new ForbiddenException(
        'Chỉ quản trị viên được đăng ảnh cho bài học',
      );

    const folder = resolveMediaFolder(actor.sub, contextType, input.lessonId);
    const driveId = input.driveFileId?.trim() || null;
    const remoteUrl =
      input.remoteUrl?.trim() ||
      (driveId ? `https://drive.google.com/uc?export=view&id=${driveId}` : '');
    if (!remoteUrl)
      throw new BadRequestException('Thiếu URL hoặc Google Drive file ID');

    return this.repo.save(
      this.repo.create({
        ownerId: actor.sub,
        driveFileId: driveId,
        driveFolderId: input.driveFolderId?.trim() || null,
        folderPath: folder.folderPath,
        name: input.name?.trim() || 'media',
        mimeType: input.mimeType || 'image/webp',
        remoteUrl,
        thumbnailUrl: input.thumbnailUrl || null,
        localReference: input.localReference || null,
        sizeBytes: String(input.sizeBytes || 0),
        contextType: folder.contextType,
        contextId: folder.contextId,
      }),
    );
  }

  driveConfig() {
    return {
      provider: 'GOOGLE_DRIVE',
      configured: Boolean(this.config.get('GOOGLE_DRIVE_FOLDER_ID')),
      rootFolderId: this.config.get('GOOGLE_DRIVE_FOLDER_ID') || null,
      folderLayout: driveFolderLayout,
    };
  }
}
