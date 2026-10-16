import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Repository } from 'typeorm';
import type { AuthRequestUser } from '../auth/auth.types';
import { User, UserRole } from '../users/user.entity';
import { MediaQueryDto } from './media-query.dto';
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

  async adminList(actor: AuthRequestUser, input: MediaQueryDto) {
    if (actor.role !== UserRole.ADMIN) throw new ForbiddenException();
    const query = this.repo
      .createQueryBuilder('asset')
      .leftJoin(User, 'owner', 'owner.id = asset.ownerId')
      .addSelect('owner.name', 'ownerName')
      .addSelect('owner.email', 'ownerEmail');
    if (input.ownerId)
      query.andWhere('asset.ownerId = :ownerId', { ownerId: input.ownerId });
    if (input.contextType)
      query.andWhere('asset.contextType = :contextType', {
        contextType: input.contextType,
      });
    if (input.search?.trim()) {
      // Treat wildcard characters as text, not arbitrary ILIKE patterns.
      const search = `%${input.search.trim().replace(/[\\%_]/g, '\\$&')}%`;
      query.andWhere(
        `(asset.name ILIKE :search OR asset.driveFileId ILIKE :search OR asset.folderPath ILIKE :search OR owner.name ILIKE :search OR owner.email ILIKE :search)`,
        { search },
      );
    }
    const total = await query.getCount();
    const { entities, raw } = await query
      .orderBy('asset.createdAt', 'DESC')
      .addOrderBy('asset.id', 'DESC')
      .offset((input.page - 1) * input.pageSize)
      .limit(input.pageSize)
      .getRawAndEntities();
    return {
      data: entities.map((asset, index) => {
        const ownerRow = raw[index] as
          { ownerName?: string | null; ownerEmail?: string | null } | undefined;
        return {
          ...asset,
          owner: {
            id: asset.ownerId,
            name: ownerRow?.ownerName ?? null,
            email: ownerRow?.ownerEmail ?? null,
          },
          // Only acknowledged uploads are present in the server catalogue.
          storageStatus: asset.driveFileId ? 'DRIVE' : 'EXTERNAL',
          previewPath: asset.driveFileId
            ? `/media/drive-images/${encodeURIComponent(asset.driveFileId)}`
            : null,
        };
      }),
      total,
      page: input.page,
      pageSize: input.pageSize,
    };
  }

  async downloadOwnedImage(actor: AuthRequestUser, fileId: string) {
    const asset = await this.repo.findOne({ where: { driveFileId: fileId } });
    if (
      !asset ||
      (actor.role !== UserRole.ADMIN && asset.ownerId !== actor.sub)
    )
      throw new NotFoundException('Ảnh không tồn tại');
    const image = await this.drive.download(fileId);
    return { buffer: image.buffer, mimeType: asset.mimeType || image.mimeType };
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
    const localReference = input.localReference?.trim();
    const persist = async (mediaRepo: Repository<MediaAsset>) => {
      if (localReference) {
        // Mobile retries the same local file after a lost response. Reuse the
        // existing Drive asset instead of creating duplicate files.
        const existing = await this.findByLocalReference(
          mediaRepo,
          actor.sub,
          folder.contextType,
          folder.contextId,
          localReference,
        );
        if (existing) return existing;
      }

      const result = await this.drive.upload(normalizedBuffer, {
        name: `${(input.name?.trim() || `image-${Date.now()}`).replace(/\.[^.]+$/, '')}.webp`,
        mimeType: 'image/webp',
        folderPath: folder.folderPath,
      });
      try {
        return await mediaRepo.save(
          mediaRepo.create({
            ownerId: actor.sub,
            driveFileId: result.id,
            driveFolderId: result.folderId,
            folderPath: result.folderPath,
            name: result.name,
            mimeType: result.mimeType,
            remoteUrl: result.remoteUrl,
            thumbnailUrl: result.remoteUrl,
            localReference: localReference || null,
            sizeBytes: String(normalizedBuffer.byteLength),
            contextType: folder.contextType,
            contextId: folder.contextId,
          }),
        );
      } catch (error) {
        // Do not leave an unreferenced Drive file when the metadata write fails.
        try {
          await this.drive.remove(result.id);
        } catch {
          // Preserve the original database error; cleanup can be retried later.
        }
        throw error;
      }
    };

    if (!localReference) return persist(this.repo);

    // A pre-check alone is racy when two mobile retries arrive together. The
    // transaction-scoped PostgreSQL advisory lock serializes the same logical
    // upload across API instances before either request calls Google Drive.
    return this.withLocalReferenceLock(
      actor.sub,
      folder.contextType,
      folder.contextId,
      localReference,
      (mediaRepo) => persist(mediaRepo),
    );
  }

  private async findByLocalReference(
    mediaRepo: Repository<MediaAsset>,
    ownerId: string,
    contextType: MediaContextType,
    contextId: string | null,
    localReference: string,
  ) {
    const baseWhere = { ownerId, localReference, contextType };
    return contextId
      ? mediaRepo.findOne({ where: { ...baseWhere, contextId } })
      : mediaRepo.findOne({
          // TypeORM's nullable column type is narrower than its IsNull
          // operator in this version, so keep the operator boundary local.
          where: { ...baseWhere, contextId: IsNull() },
        });
  }

  private async withLocalReferenceLock<T>(
    ownerId: string,
    contextType: MediaContextType,
    contextId: string | null,
    localReference: string,
    action: (mediaRepo: Repository<MediaAsset>) => Promise<T>,
  ): Promise<T> {
    const manager = this.repo.manager;
    if (!manager?.transaction) return action(this.repo);

    const lockKey = [
      'media-upload',
      ownerId,
      contextType,
      contextId ?? '',
      localReference,
    ].join(':');
    return manager.transaction(async (transactionManager) => {
      await transactionManager.query(
        'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
        [lockKey],
      );
      return action(transactionManager.getRepository(MediaAsset));
    });
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
    const rootFolderId =
      this.config.get<string>('GOOGLE_DRIVE_FOLDER_ID') ?? null;
    return {
      provider: 'GOOGLE_DRIVE',
      configured: Boolean(rootFolderId),
      rootFolderId,
      folderLayout: driveFolderLayout,
    };
  }
}
