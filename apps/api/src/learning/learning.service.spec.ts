import { AccountTier, UserRole } from '../users/user.entity';
import { LearningService } from './learning.service';
import { LessonTier } from './lesson.entity';

function repository<T extends Record<string, any>>(rows: T[] = []) {
  return {
    rows,
    count: jest.fn(async () => rows.length),
    create: jest.fn(
      (value: Partial<T>) =>
        ({ id: value.id ?? `id-${rows.length + 1}`, ...value }) as T,
    ),
    save: jest.fn(async (value: T | T[]) => {
      if (Array.isArray(value)) {
        rows.push(...value);
        return value;
      }
      const index = rows.findIndex((row) => row.id === value.id);
      if (index >= 0) rows[index] = value;
      else rows.push(value);
      return value;
    }),
    find: jest.fn(async ({ where, order }: any = {}) =>
      rows
        .filter(
          (row) =>
            !where ||
            Object.entries(where).every(([key, value]) => row[key] === value),
        )
        .sort((a, b) => (order?.position ? a.position - b.position : 0)),
    ),
    findOne: jest.fn(
      async ({ where }: any) =>
        rows.find((row) =>
          Object.entries(where).every(([key, value]) => row[key] === value),
        ) ?? null,
    ),
    remove: jest.fn(async (value: T) => {
      const index = rows.indexOf(value);
      if (index >= 0) rows.splice(index, 1);
      return value;
    }),
  };
}

describe('LearningService Phase 3', () => {
  const lessons = [
    ...Array.from({ length: 4 }, (_, position) => ({
      id: `b${position}`,
      slug: `b-${position}`,
      title: `B${position}`,
      description: '',
      tier: LessonTier.BASIC,
      position,
      durationMinutes: 10,
      isPublished: true,
      knowledgeCards: [],
      questions: [],
    })),
    ...Array.from({ length: 4 }, (_, position) => ({
      id: `a${position}`,
      slug: `a-${position}`,
      title: `A${position}`,
      description: '',
      tier: LessonTier.ADVANCED,
      position,
      durationMinutes: 10,
      isPublished: true,
      knowledgeCards: [],
      questions: [],
    })),
  ];

  it('applies STANDARD, VIP1 and VIP2 lesson access and lock flags', async () => {
    const lessonRepo = repository(lessons.map((item) => ({ ...item })));
    const service = new LearningService(
      lessonRepo as never,
      repository([]) as never,
    );
    const standard = await service.list({
      sub: 'u1',
      role: UserRole.STUDENT,
      accountTier: AccountTier.STANDARD,
    });
    const vip1 = await service.list({
      sub: 'u2',
      role: UserRole.STUDENT,
      accountTier: AccountTier.VIP1,
    });
    const vip2 = await service.list({
      sub: 'u3',
      role: UserRole.STUDENT,
      accountTier: AccountTier.VIP2,
    });
    expect(
      new Set(standard.filter((item) => !item.locked).map((item) => item.id)),
    ).toEqual(new Set(['a0', 'b0', 'b1', 'b2']));
    expect(
      new Set(vip1.filter((item) => !item.locked).map((item) => item.id)),
    ).toEqual(new Set(['a0', 'a1', 'a2', 'b0', 'b1', 'b2', 'b3']));
    expect(vip2.every((item) => !item.locked)).toBe(true);
  });

  it('returns a content fingerprint so edited lessons invalidate mobile cache', async () => {
    const lessonRepo = repository([
      { ...lessons[0], updatedAt: new Date('2026-10-04T00:00:00.000Z') },
    ]);
    const service = new LearningService(
      lessonRepo as never,
      repository([]) as never,
    );
    const actor = {
      sub: 'u1',
      role: UserRole.STUDENT,
      accountTier: AccountTier.VIP2,
    };
    const original = (await service.list(actor)).find(
      (item) => item.id === 'b0',
    )!;
    lessonRepo.rows[0].title = 'Cấu trúc thị trường đã sửa';
    const updated = (await service.list(actor)).find(
      (item) => item.id === 'b0',
    )!;
    expect(updated.updatedAt).toEqual(original.updatedAt);
    expect(updated.contentVersion).not.toEqual(original.contentVersion);
  });

  it('keeps progress monotonic and records completion', async () => {
    const lessonRepo = repository([{ ...lessons[0] }]);
    const progressRepo = repository<any>([]);
    const service = new LearningService(
      lessonRepo as never,
      progressRepo as never,
    );
    const actor = {
      sub: 'u1',
      role: UserRole.STUDENT,
      accountTier: AccountTier.STANDARD,
    };
    await service.saveProgress('b0', actor, {
      progress: 0.75,
      answeredCount: 2,
      correctCount: 1,
    });
    const saved = await service.saveProgress('b0', actor, {
      progress: 0.25,
      answeredCount: 1,
      correctCount: 0,
    });
    expect(saved.progress).toBe(0.75);
    expect(saved.answeredCount).toBe(2);
    await service.saveProgress('b0', actor, {
      progress: 1,
      answeredCount: 3,
      correctCount: 2,
    });
    expect(progressRepo.rows[0].completedAt).toBeInstanceOf(Date);
  });
});

describe('LearningService Phase 4 lesson validation', () => {
  const lessonId = '11111111-1111-4111-8111-111111111111';
  const knowledgeCards = [{ imageUrl: 'https://cdn.example.com/lesson.webp' }];
  const validQuestion = {
    question: 'Đâu là vùng chờ hợp lệ?',
    options: [
      { text: 'Vùng có phản ứng rõ ràng' },
      { text: 'Bất kỳ vị trí nào' },
      { imageUrl: 'https://cdn.example.com/answer.webp' },
    ],
    correctIndex: 0,
    explanation: 'Cần có bối cảnh và phản ứng giá.',
  };

  function serviceWithLesson(overrides: Record<string, unknown> = {}) {
    const lessonRepo = repository<any>([
      {
        id: lessonId,
        slug: 'market-structure',
        title: 'Cấu trúc thị trường',
        description: '',
        tier: LessonTier.BASIC,
        position: 0,
        durationMinutes: 10,
        isPublished: false,
        knowledgeCards,
        questions: [],
        ...overrides,
      },
    ]);
    return {
      service: new LearningService(
        lessonRepo as never,
        repository([]) as never,
      ),
      lessonRepo,
    };
  }

  it('accepts question and answer images and removes unsupported fields', async () => {
    const { service } = serviceWithLesson();
    const exerciseUrl = `/learning/lessons/${lessonId}/exercise-images/22222222-2222-4222-8222-222222222222.webp`;
    const saved = await service.update(lessonId, {
      questions: [
        {
          question: '',
          imageUrl: exerciseUrl,
          options: [
            { text: 'Đáp án chữ', debug: true },
            { imageUrl: exerciseUrl },
            { text: 'Cả chữ', imageUrl: exerciseUrl },
          ],
          correctIndex: 1,
          explanation: 'Giải thích',
          ignored: 'field',
        },
      ],
    });

    expect(saved.questions).toEqual([
      {
        question: '',
        imageUrl: exerciseUrl,
        options: [
          { text: 'Đáp án chữ' },
          { imageUrl: exerciseUrl },
          { text: 'Cả chữ', imageUrl: exerciseUrl },
        ],
        correctIndex: 1,
        explanation: 'Giải thích',
      },
    ]);
  });

  it.each([
    {
      name: 'requires question content',
      question: { ...validQuestion, question: '' },
      message: 'cần có chữ hoặc hình ảnh',
    },
    {
      name: 'requires exactly three answers',
      question: {
        ...validQuestion,
        options: validQuestion.options.slice(0, 2),
      },
      message: 'cần đúng 3 đáp án',
    },
    {
      name: 'rejects an empty answer',
      question: {
        ...validQuestion,
        options: [{}, ...validQuestion.options.slice(1)],
      },
      message: 'cần có chữ hoặc hình ảnh',
    },
    {
      name: 'requires a valid correct answer',
      question: { ...validQuestion, correctIndex: 3 },
      message: 'cần chọn một đáp án đúng',
    },
  ])('$name', async ({ question, message }) => {
    const { service } = serviceWithLesson();
    await expect(
      service.update(lessonId, { questions: [question] }),
    ).rejects.toThrow(message);
  });

  it('rejects protected exercise images belonging to another lesson', async () => {
    const { service } = serviceWithLesson();
    await expect(
      service.update(lessonId, {
        questions: [
          {
            ...validQuestion,
            imageUrl:
              '/learning/lessons/33333333-3333-4333-8333-333333333333/exercise-images/22222222-2222-4222-8222-222222222222.webp',
          },
        ],
      }),
    ).rejects.toThrow('Ảnh bài tập không thuộc bài học này');
  });

  it('does not publish a lesson without a knowledge image', async () => {
    const { service } = serviceWithLesson({ knowledgeCards: [] });
    await expect(
      service.update(lessonId, { isPublished: true }),
    ).rejects.toThrow('Cần ít nhất một ảnh');
  });

  it('does not publish a lesson without a quiz question', async () => {
    const { service } = serviceWithLesson();
    await expect(
      service.update(lessonId, { isPublished: true }),
    ).rejects.toThrow('Cần ít nhất một câu hỏi');
  });

  it('creates new lessons as drafts by default', async () => {
    const service = new LearningService(
      repository<any>([]) as never,
      repository([]) as never,
    );
    const saved = await service.create({
      title: 'Bài mới',
      knowledgeCards,
      questions: [validQuestion],
    });
    expect(saved.isPublished).toBe(false);
  });
});
