import {
  BadRequestException,
  Injectable,
  Optional,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { AuthRequestUser } from '../auth/auth.types';
import { MediaContextType } from '../media/media-context';
import { MediaService } from '../media/media.service';
import { mkdir, access, rm, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import sharp from 'sharp';

@Injectable()
export class LessonImagesService {
  constructor(@Optional() private readonly media?: MediaService) {}
  private directory(lessonId: string, group: 'Bài học' | 'Bài tập') {
    if (!/^[\da-f-]{36}$/i.test(lessonId))
      throw new BadRequestException('Mã bài học không hợp lệ');
    return resolve(
      process.env.UPLOADS_DIR || 'uploads',
      'Kiến thức',
      lessonId,
      group,
    );
  }

  async upload(
    lessonId: string,
    file: Express.Multer.File | undefined,
    group: 'Bài học' | 'Bài tập' = 'Bài học',
    actor?: AuthRequestUser,
    mediaContext?: MediaContextType,
  ) {
    if (!file?.buffer) throw new BadRequestException('Vui lòng chọn ảnh');
    // Production uploads go directly to Drive. The local branch remains only
    // for legacy unit tests and old migration tooling that call this service
    // without an authenticated actor.
    if (actor && this.media) {
      const context =
        mediaContext ??
        (group === 'Bài học'
          ? MediaContextType.LEARNING_LESSON
          : MediaContextType.LEARNING_QUESTION);
      const uploaded = await this.media.upload(
        actor,
        {
          name: file.originalname || `lesson-${Date.now()}.webp`,
          mimeType: file.mimetype || 'image/webp',
          contextType: context,
          lessonId,
        },
        file.buffer,
      );
      return {
        imageUrl: uploaded.remoteUrl,
        driveFileId: uploaded.driveFileId,
      };
    }
    let buffer: Buffer;
    try {
      buffer = await sharp(file.buffer, { limitInputPixels: 40_000_000 })
        .rotate()
        .resize({ width: 2560, withoutEnlargement: true })
        .webp({ quality: 85 })
        .toBuffer();
    } catch {
      throw new BadRequestException(
        'Ảnh không hợp lệ. Hãy chọn JPEG, PNG hoặc WebP',
      );
    }
    const directory = this.directory(lessonId, group);
    await mkdir(directory, { recursive: true });
    const name = `${randomUUID()}.webp`;
    await writeFile(resolve(directory, name), buffer, { flag: 'wx' });
    return { imageUrl: `/learning/lessons/${lessonId}/images/${name}` };
  }

  async driveImage(lessonId: string, fileId: string) {
    if (!this.media) throw new NotFoundException('Ảnh bài học không tồn tại');
    return this.media.downloadLearningImage(fileId, lessonId);
  }

  async removeLesson(lessonId: string) {
    if (this.media) await this.media.removeLessonMedia(lessonId);
    const lessonDirectory = resolve(this.directory(lessonId, 'Bài học'), '..');
    await rm(lessonDirectory, { recursive: true, force: true });
  }

  async path(
    lessonId: string,
    name: string,
    group: 'Bài học' | 'Bài tập' = 'Bài học',
  ) {
    if (!/^[\da-f-]{36}\.webp$/i.test(name)) throw new NotFoundException();
    const path = resolve(this.directory(lessonId, group), name);
    try {
      await access(path);
    } catch {
      throw new NotFoundException('Ảnh không tồn tại');
    }
    return path;
  }
}
