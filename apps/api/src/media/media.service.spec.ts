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
      rows.find((row) => {
        if (where.driveFileId && row.driveFileId !== where.driveFileId)
          return false;
        if (where.ownerId && row.ownerId !== where.ownerId) return false;
        if (where.localReference && row.localReference !== where.localReference)
          return false;
        if (where.contextType?._type === 'in') {
          if (!where.contextType._value.includes(row.contextType)) return false;
        } else if (where.contextType && row.contextType !== where.contextType) {
          return false;
        }
        if (where.contextId?._type === 'isNull' && row.contextId !== null)
          return false;
        if (
          typeof where.contextId === 'string' &&
          row.contextId !== where.contextId
        )
          return false;
        return true;
      }) ?? null,
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
    upload: jest
      .fn()
      .mockImplementation(async (_buffer: Buffer, input: any) => ({
        id: `drive-${rows.length + 1}`,
        name: input.name,
        mimeType: input.mimeType,
        webViewLink: 'https://drive.google.com/file/d/test/view',
        remoteUrl: `https://drive.google.com/uc?export=download&id=drive-${rows.length + 1}`,
        folderId: 'folder-1',
        folderPath: input.folderPath,
      })),
  };
  return {
    rows,
    repo,
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

  it('reuses an uploaded local reference instead of creating a Drive duplicate', async () => {
    const { media, rows, drive } = service();
    const student = actor('user-456');
    const image = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      'base64',
    );

    const first = await media.upload(
      student,
      {
        contextType: MediaContextType.PLAN,
        name: 'chart.png',
        localReference: '/offline/chart.png',
      },
      image,
    );
    const second = await media.upload(
      student,
      {
        contextType: MediaContextType.PLAN,
        name: 'chart.png',
        localReference: '/offline/chart.png',
      },
      image,
    );

    expect(second.id).toBe(first.id);
    expect(rows).toHaveLength(1);
    expect(drive.upload).toHaveBeenCalledTimes(1);
  });

  it('serializes concurrent retries with a transaction-scoped advisory lock', async () => {
    const { media, repo, rows, drive } = service();
    let queue = Promise.resolve();
    let lockCalls = 0;
    (repo as any).manager = {
      transaction: async (callback: (manager: any) => Promise<unknown>) => {
        const previous = queue;
        let release!: () => void;
        queue = new Promise<void>((resolve) => {
          release = resolve;
        });
        await previous;
        try {
          return await callback({
            query: async () => {
              lockCalls += 1;
            },
            getRepository: () => repo,
          });
        } finally {
          release();
        }
      },
    };
    const student = actor('user-456');
    const image = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      'base64',
    );

    const uploads = await Promise.all([
      media.upload(
        student,
        {
          contextType: MediaContextType.PLAN,
          name: 'chart.png',
          localReference: '/offline/chart.png',
        },
        image,
      ),
      media.upload(
        student,
        {
          contextType: MediaContextType.PLAN,
          name: 'chart.png',
          localReference: '/offline/chart.png',
        },
        image,
      ),
    ]);

    expect(uploads[1].id).toBe(uploads[0].id);
    expect(rows).toHaveLength(1);
    expect(drive.upload).toHaveBeenCalledTimes(1);
    expect(lockCalls).toBe(2);
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

  it('allows the image owner and admin but hides other users media', async () => {
    const { media, drive } = service();
    await media.register(actor('student-a'), {
      driveFileId: 'journal-private',
      contextType: MediaContextType.JOURNAL,
    });
    await expect(
      media.downloadOwnedImage(actor('student-a'), 'journal-private'),
    ).resolves.toEqual({
      buffer: Buffer.from('image-bytes'),
      mimeType: 'image/webp',
    });
    await expect(
      media.downloadOwnedImage(
        actor('admin', UserRole.ADMIN),
        'journal-private',
      ),
    ).resolves.toBeDefined();
    await expect(
      media.downloadOwnedImage(actor('student-b'), 'journal-private'),
    ).rejects.toThrow('Ảnh không tồn tại');
    expect(drive.download).toHaveBeenCalledTimes(2);
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
