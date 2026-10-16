import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  OnApplicationBootstrap,
} from '@nestjs/common';
import { createHash } from 'node:crypto';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AccountTier, UserRole } from '../users/user.entity';
import { LessonProgress } from './lesson-progress.entity';
import { Lesson, LessonTier } from './lesson.entity';

export type LearningActor = {
  sub: string;
  role: UserRole;
  accountTier: AccountTier;
};
export type LessonInput = Partial<
  Pick<
    Lesson,
    | 'title'
    | 'description'
    | 'tier'
    | 'position'
    | 'durationMinutes'
    | 'isPublished'
    | 'knowledgeCards'
    | 'questions'
  >
> & { slug?: string };

@Injectable()
export class LearningService implements OnApplicationBootstrap {
  constructor(
    @InjectRepository(Lesson) private readonly lessons: Repository<Lesson>,
    @InjectRepository(LessonProgress)
    private readonly progress: Repository<LessonProgress>,
  ) {}

  async onApplicationBootstrap() {
    if (await this.lessons.count()) return;
    await this.lessons.save(
      this.seedLessons().map((item) => this.lessons.create(item)),
    );
  }

  async list(actor: LearningActor) {
    const lessons = await this.lessons.find({
      where: { isPublished: true },
      order: { tier: 'ASC', position: 'ASC' },
    });
    const progressRows = await this.progress.find({
      where: { userId: actor.sub },
    });
    const progressMap = new Map(progressRows.map((row) => [row.lessonId, row]));
    return Promise.all(
      lessons.map(async (lesson) =>
        this.toListItem(
          lesson,
          !(await this.canAccess(lesson, actor)),
          progressMap.get(lesson.id),
        ),
      ),
    );
  }

  async detail(id: string, actor: LearningActor) {
    const lesson = await this.lessons.findOne({
      where: { id, isPublished: true },
    });
    if (!lesson) throw new NotFoundException('Bài học không tồn tại');
    if (!(await this.canAccess(lesson, actor)))
      throw new ForbiddenException('Bài học đang khóa');
    const progress = await this.progress.findOne({
      where: { userId: actor.sub, lessonId: id },
    });
    return {
      ...this.toListItem(lesson, false, progress ?? undefined),
      knowledgeCards: lesson.knowledgeCards,
      questions: lesson.questions,
    };
  }

  async saveProgress(
    lessonId: string,
    actor: LearningActor,
    input: { progress: number; answeredCount?: number; correctCount?: number },
  ) {
    const lesson = await this.lessons.findOne({ where: { id: lessonId } });
    if (!lesson) throw new NotFoundException('Bài học không tồn tại');
    if (!(await this.canAccess(lesson, actor)))
      throw new ForbiddenException('Bài học đang khóa');
    let row = await this.progress.findOne({
      where: { userId: actor.sub, lessonId },
    });
    row ??= this.progress.create({ userId: actor.sub, lessonId });
    row.progress = Math.max(
      row.progress ?? 0,
      Math.min(1, Math.max(0, input.progress)),
    );
    row.answeredCount = Math.max(
      row.answeredCount ?? 0,
      input.answeredCount ?? 0,
    );
    row.correctCount = Math.max(row.correctCount ?? 0, input.correctCount ?? 0);
    if (row.progress >= 1 && !row.completedAt) row.completedAt = new Date();
    return this.progress.save(row);
  }

  adminList() {
    return this.lessons.find({ order: { tier: 'ASC', position: 'ASC' } });
  }

  async imageAccess(id: string, actor?: LearningActor) {
    const lesson = await this.lessons.findOne({ where: { id } });
    if (!lesson) throw new NotFoundException('Bài học không tồn tại');
    if (
      actor &&
      actor.role !== UserRole.ADMIN &&
      (!lesson.isPublished || !(await this.canAccess(lesson, actor)))
    )
      throw new ForbiddenException('Bài học đang khóa');
  }

  private imageCards(cards: Record<string, unknown>[]) {
    return cards.map((card) => {
      const imageUrl = card?.imageUrl;
      if (
        typeof imageUrl !== 'string' ||
        !/^(https?:\/\/[^\s]+|\/learning\/lessons\/[\da-f-]{36}\/images\/[\da-f-]{36}\.webp)$/i.test(
          imageUrl,
        )
      )
        throw new BadRequestException(
          'Mỗi thẻ kiến thức cần một ảnh. Hãy tải ảnh lên thay cho nội dung chữ.',
        );
      return { imageUrl };
    });
  }

  private quizImageUrl(value: unknown, lessonId?: string) {
    if (value === undefined || value === null || value === '') return undefined;
    if (typeof value !== 'string')
      throw new BadRequestException('Ảnh bài tập không hợp lệ');
    if (/^https?:\/\/[^\s]+$/i.test(value)) return value;
    if (
      lessonId &&
      new RegExp(
        `^/learning/lessons/${lessonId}/exercise-images/[\\da-f-]{36}\\.webp$`,
        'i',
      ).test(value)
    )
      return value;
    throw new BadRequestException('Ảnh bài tập không thuộc bài học này');
  }

  private quizQuestions(
    questions: Record<string, unknown>[],
    lessonId?: string,
  ) {
    return questions.map((question, questionIndex) => {
      const text =
        typeof question.question === 'string' ? question.question.trim() : '';
      const imageUrl = this.quizImageUrl(
        question.imageUrl ?? question.imageLabel,
        lessonId,
      );
      if (!text && !imageUrl)
        throw new BadRequestException(
          `Câu hỏi ${questionIndex + 1} cần có chữ hoặc hình ảnh`,
        );

      const rawOptions = Array.isArray(question.options)
        ? question.options
        : [];
      if (rawOptions.length !== 3)
        throw new BadRequestException(
          `Câu hỏi ${questionIndex + 1} cần đúng 3 đáp án`,
        );
      const options = rawOptions.map((rawOption, optionIndex) => {
        if (!rawOption || typeof rawOption !== 'object')
          throw new BadRequestException(
            `Đáp án ${optionIndex + 1} của câu ${questionIndex + 1} không hợp lệ`,
          );
        const option = rawOption as Record<string, unknown>;
        const optionText =
          typeof option.text === 'string' ? option.text.trim() : '';
        const optionImageUrl = this.quizImageUrl(
          option.imageUrl ?? option.imageLabel,
          lessonId,
        );
        if (!optionText && !optionImageUrl)
          throw new BadRequestException(
            `Đáp án ${optionIndex + 1} của câu ${questionIndex + 1} cần có chữ hoặc hình ảnh`,
          );
        return {
          ...(optionText ? { text: optionText } : {}),
          ...(optionImageUrl ? { imageUrl: optionImageUrl } : {}),
        };
      });
      const correctIndex = Number(question.correctIndex);
      if (
        !Number.isInteger(correctIndex) ||
        correctIndex < 0 ||
        correctIndex > 2
      )
        throw new BadRequestException(
          `Câu hỏi ${questionIndex + 1} cần chọn một đáp án đúng`,
        );
      return {
        question: text,
        ...(imageUrl ? { imageUrl } : {}),
        options,
        correctIndex,
        explanation:
          typeof question.explanation === 'string'
            ? question.explanation.trim()
            : '',
      };
    });
  }

  private validatePublish(
    isPublished: boolean,
    cards: Record<string, unknown>[],
    questions: Record<string, unknown>[],
  ) {
    if (!isPublished) return;
    if (!cards.length)
      throw new BadRequestException('Cần ít nhất một ảnh trước khi xuất bản');
    if (!questions.length)
      throw new BadRequestException(
        'Cần ít nhất một câu hỏi trước khi xuất bản',
      );
  }

  create(input: LessonInput) {
    const cards = this.imageCards(input.knowledgeCards ?? []);
    const questions = this.quizQuestions(input.questions ?? []);
    this.validatePublish(input.isPublished ?? false, cards, questions);
    return this.lessons.save(
      this.lessons.create({
        slug: input.slug?.trim() || `lesson-${Date.now()}`,
        title: input.title?.trim() || 'Bài học mới',
        description: input.description?.trim() || '',
        tier: input.tier ?? LessonTier.BASIC,
        position: input.position ?? 0,
        durationMinutes: input.durationMinutes ?? 10,
        isPublished: input.isPublished ?? false,
        knowledgeCards: cards,
        questions,
      }),
    );
  }

  async update(id: string, input: LessonInput) {
    const lesson = await this.lessons.findOne({ where: { id } });
    if (!lesson) throw new NotFoundException('Bài học không tồn tại');
    const cards =
      input.knowledgeCards === undefined
        ? lesson.knowledgeCards
        : this.imageCards(input.knowledgeCards);
    const questions =
      input.questions === undefined
        ? lesson.questions
        : this.quizQuestions(input.questions, id);
    this.validatePublish(
      input.isPublished ?? lesson.isPublished,
      cards,
      questions,
    );
    Object.assign(lesson, {
      ...(input.slug !== undefined ? { slug: input.slug.trim() } : {}),
      ...(input.title !== undefined ? { title: input.title.trim() } : {}),
      ...(input.description !== undefined
        ? { description: input.description.trim() }
        : {}),
      ...(input.tier !== undefined ? { tier: input.tier } : {}),
      ...(input.position !== undefined ? { position: input.position } : {}),
      ...(input.durationMinutes !== undefined
        ? { durationMinutes: input.durationMinutes }
        : {}),
      ...(input.isPublished !== undefined
        ? { isPublished: input.isPublished }
        : {}),
      ...(input.knowledgeCards !== undefined ? { knowledgeCards: cards } : {}),
      ...(input.questions !== undefined ? { questions } : {}),
    });
    return this.lessons.save(lesson);
  }

  async remove(id: string) {
    const lesson = await this.lessons.findOne({ where: { id } });
    if (!lesson) throw new NotFoundException('Bài học không tồn tại');
    await this.lessons.remove(lesson);
    return { success: true };
  }

  private async canAccess(lesson: Lesson, actor: LearningActor) {
    if (actor.role === UserRole.ADMIN || actor.accountTier === AccountTier.VIP2)
      return true;
    const sameTier = await this.lessons.find({
      where: { tier: lesson.tier, isPublished: true },
      order: { position: 'ASC' },
    });
    const index = sameTier.findIndex((item) => item.id === lesson.id);
    if (actor.accountTier === AccountTier.STANDARD)
      return lesson.tier === LessonTier.BASIC ? index < 3 : index < 1;
    return lesson.tier === LessonTier.BASIC || index < 3;
  }

  private contentVersion(lesson: Lesson) {
    // A content fingerprint catches edits even when a database timestamp is
    // rounded or an imported record keeps the same updated_at value.
    return createHash('sha256')
      .update(
        JSON.stringify({
          title: lesson.title,
          description: lesson.description,
          tier: lesson.tier,
          position: lesson.position,
          durationMinutes: lesson.durationMinutes,
          isPublished: lesson.isPublished,
          knowledgeCards: lesson.knowledgeCards,
          questions: lesson.questions,
        }),
      )
      .digest('hex');
  }

  private toListItem(
    lesson: Lesson,
    locked: boolean,
    progress?: LessonProgress,
  ) {
    return {
      id: lesson.id,
      slug: lesson.slug,
      title: lesson.title,
      description: lesson.description,
      tier: lesson.tier,
      position: lesson.position,
      durationMinutes: lesson.durationMinutes,
      questionCount: lesson.questions.length,
      isPublished: lesson.isPublished,
      updatedAt: lesson.updatedAt,
      contentVersion: this.contentVersion(lesson),
      locked,
      progress: progress?.progress ?? 0,
    };
  }

  private seedLessons(): Partial<Lesson>[] {
    const questions = (topic: string) => [
      {
        question: `Điều nào quan trọng nhất khi áp dụng ${topic}?`,
        options: [
          { text: 'Có bối cảnh và quản trị rủi ro' },
          { text: 'Vào lệnh ngay' },
          { text: 'Bỏ điểm dừng lỗ' },
        ],
        correctIndex: 0,
        explanation:
          'Bối cảnh và giới hạn rủi ro luôn phải được xác định trước.',
      },
    ];
    const items: [string, string, LessonTier][] = [
      ['market-structure', 'Cấu trúc thị trường', LessonTier.BASIC],
      ['supply-demand', 'Supply & Demand', LessonTier.BASIC],
      ['risk-management', 'Quản trị rủi ro', LessonTier.BASIC],
      ['trading-psychology', 'Tâm lý giao dịch', LessonTier.BASIC],
      ['liquidity', 'Thanh khoản nâng cao', LessonTier.ADVANCED],
      ['order-flow', 'Order Flow thực chiến', LessonTier.ADVANCED],
      ['execution-model', 'Mô hình thực thi lệnh', LessonTier.ADVANCED],
      ['swing-model', 'Chiến lược Swing', LessonTier.ADVANCED],
    ];
    return items.map(([slug, title, tier], index) => ({
      slug,
      title,
      tier,
      description: `Lộ trình thực hành ${title}.`,
      position: index,
      durationMinutes: 18 + index * 2,
      // Seed records are drafts until the admin uploads at least one lesson image.
      isPublished: false,
      knowledgeCards: [],
      questions: questions(title),
    }));
  }
}
