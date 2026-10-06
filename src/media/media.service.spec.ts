import { ForbiddenException } from '@nestjs/common';
import type { AuthRequestUser } from '../auth/auth.types';
import { AccountTier, LearningTier, UserRole } from '../users/user.entity';
import { MediaContextType } from './media-context';
import { MediaService } from './media.service';

const actor = (sub: string, role = UserRole.STUDENT): AuthRequestUser => ({
  sub,
  email: `${sub}@anzen.test`,
  name: sub,
  role,
  accountTier: AccountTier.STANDARD,
  learningTier: LearningTier.BASIC,
  deviceId: 'device',
  tokenVersion: 0,
  type: 'access',
});

function service() {
  const rows: any[] = [];
  const repo = {
    create: (value: any) => ({ id: `m${rows.length + 1}`, ...value }),
    save: async (value: any) => {
      rows.push(value);
      return value;
    },
    find: async ({ where }: any = {}) => {
      if (!where) return rows;
      return rows.filter(
        (row) =>
          (!where.contextId || row.contextId === where.contextId) &&
          (!where.contextType ||
            (where.contextType._type === 'in' &&
              where.contextType._value.includes(row.contextType)) ||
            row.contextType === where.contextType),
      );
    },
    remove: jest.fn(async (values: any[]) => {
      for (const value of values) {
        const index = rows.indexOf(value);
        if (index >= 0) rows.splice(index, 1);
      }
      return values;
    }),
    findOne: async ({ where }: any) =>
      rows.find((row) => row.driveFileId === where.driveFileId) ?? null,
  };
  const config = {
    get: (key: string) =>
      key === 'GOOGLE_DRIVE_FOLDER_ID' ? 'anzen-root-folder' : undefined,
  };
  const drive = {
    remove: jest.fn().mockResolvedValue(undefined),
    download: jest.fn().mockResolvedValue({
      buffer: Buffer.from('image-bytes'),
      mimeType: 'image/webp',
    }),
  };
  return {
    rows,
    drive,
    media: new MediaService(repo as never, config as never, drive as never),
  };
}

describe('MediaService Drive folder routing', () => {
  it('routes lesson, question and answer images by lesson id', async () => {
    const { media } = service();
    const admin = actor('admin-id', UserRole.ADMIN);
    const lesson = await media.register(admin, {
      remoteUrl: 'https://cdn.test/lesson.webp',
      lessonId: 'lesson-123',
      contextType: MediaContextType.LEARNING_LESSON,
    });
    const question = await media.register(admin, {
      remoteUrl: 'https://cdn.test/question.webp',
      lessonId: 'lesson-123',
      contextType: MediaContextType.LEARNING_QUESTION,
    });
    const answer = await media.register(admin, {
      remoteUrl: 'https://cdn.test/answer.webp',
      lessonId: 'lesson-123',
      contextType: MediaContextType.LEARNING_ANSWER,
    });

    expect(lesson.folderPath).toBe('Kiến thức/lesson-123/Bài học');
    expect(question.folderPath).toBe('Kiến thức/lesson-123/Bài tập/Câu hỏi');
    expect(answer.folderPath).toBe('Kiến thức/lesson-123/Bài tập/Câu trả lời');
    expect(answer.contextId).toBe('lesson-123');
  });

  it('routes journal and plan images into the signed-in user folder', async () => {
    const { media } = service();
    const student = actor('user-456');
    const journal = await media.register(student, {
      driveFileId: 'journal-file',
      contextType: MediaContextType.JOURNAL,
    });
    const plan = await media.register(student, {
      driveFileId: 'plan-file',
      contextType: MediaContextType.PLAN,
    });

    expect(journal.folderPath).toBe('Nhật ký giao dịch/user-456');
    expect(plan.folderPath).toBe('Plan giao dịch/user-456');
    expect(journal.ownerId).toBe('user-456');
    expect(plan.contextId).toBe('user-456');
  });

  it('deletes every lesson image from Drive and media_assets', async () => {
    const { media, rows, drive } = service();
    const admin = actor('admin-id', UserRole.ADMIN);

    await media.register(admin, {
      driveFileId: 'lesson-file',
      remoteUrl: 'https://drive.google.com/uc?export=download&id=lesson-file',
      lessonId: 'lesson-123',
      contextType: MediaContextType.LEARNING_LESSON,
    });
    await media.register(admin, {
      driveFileId: 'question-file',
      remoteUrl: 'https://drive.google.com/uc?export=download&id=question-file',
      lessonId: 'lesson-123',
      contextType: MediaContextType.LEARNING_QUESTION,
    });
    await media.register(admin, {
      driveFileId: 'answer-file',
      remoteUrl: 'https://drive.google.com/uc?export=download&id=answer-file',
      lessonId: 'lesson-123',
      contextType: MediaContextType.LEARNING_ANSWER,
    });
    await media.register(admin, {
      driveFileId: 'other-lesson-file',
      remoteUrl:
        'https://drive.google.com/uc?export=download&id=other-lesson-file',
      lessonId: 'lesson-999',
      contextType: MediaContextType.LEARNING_LESSON,
    });

    await expect(media.removeLessonMedia('lesson-123')).resolves.toEqual({
      deleted: 3,
    });

    expect(drive.remove).toHaveBeenCalledTimes(3);
    expect(drive.remove).toHaveBeenCalledWith('lesson-file');
    expect(drive.remove).toHaveBeenCalledWith('question-file');
    expect(drive.remove).toHaveBeenCalledWith('answer-file');
    expect(rows.map((row) => row.driveFileId)).toEqual(['other-lesson-file']);
  });

  it('downloads question and answer images through the lesson proxy', async () => {
    const { media, drive } = service();
    const admin = actor('admin-id', UserRole.ADMIN);
    await media.register(admin, {
      driveFileId: 'question-file',
      remoteUrl: 'https://drive.google.com/uc?export=download&id=question-file',
      lessonId: 'lesson-123',
      contextType: MediaContextType.LEARNING_QUESTION,
    });

    const image = await media.downloadLearningImage(
      'question-file',
      'lesson-123',
    );

    expect(image).toEqual({
      buffer: Buffer.from('image-bytes'),
      mimeType: 'image/webp',
    });
    expect(drive.download).toHaveBeenCalledWith('question-file');
  });

  it('only allows administrators to register learning media', async () => {
    const { media } = service();
    await expect(
      media.register(actor('student-id'), {
        remoteUrl: 'https://cdn.test/card.webp',
        lessonId: 'lesson-123',
        contextType: MediaContextType.LEARNING_LESSON,
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('publishes the agreed Google Drive folder contract', () => {
    const { media } = service();
    expect(media.driveConfig()).toEqual({
      provider: 'GOOGLE_DRIVE',
      configured: true,
      rootFolderId: 'anzen-root-folder',
      folderLayout: {
        learning: {
          lesson: 'Kiến thức/{lessonId}/Bài học',
          question: 'Kiến thức/{lessonId}/Bài tập/Câu hỏi',
          answer: 'Kiến thức/{lessonId}/Bài tập/Câu trả lời',
        },
        journal: 'Nhật ký giao dịch/{userId}',
        plan: 'Plan giao dịch/{userId}',
        featuredTrade: 'Tin quan trọng trong tuần',
      },
    });
  });
});
