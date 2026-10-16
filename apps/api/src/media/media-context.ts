import { BadRequestException } from '@nestjs/common';

export enum MediaContextType {
  LEARNING_LESSON = 'LEARNING_LESSON',
  LEARNING_QUESTION = 'LEARNING_QUESTION',
  LEARNING_ANSWER = 'LEARNING_ANSWER',
  JOURNAL = 'JOURNAL',
  PLAN = 'PLAN',
  FEATURED_TRADE = 'FEATURED_TRADE',
  GENERAL = 'GENERAL',
}

export type MediaFolderTarget = {
  contextType: MediaContextType;
  contextId: string | null;
  folderPath: string;
};

const segment = (value: string) =>
  value.trim().replace(/[\\/]/g, '-').replace(/\s+/g, ' ');

export function resolveMediaFolder(
  ownerId: string,
  contextType: MediaContextType,
  lessonId?: string,
): MediaFolderTarget {
  const userFolder = segment(ownerId);
  const lessonFolder = lessonId?.trim() ? segment(lessonId) : null;

  switch (contextType) {
    case MediaContextType.LEARNING_LESSON:
      if (!lessonFolder)
        throw new BadRequestException(
          'Ảnh kiến thức phải có lessonId của bài học',
        );
      return {
        contextType,
        contextId: lessonFolder,
        folderPath: `Kiến thức/${lessonFolder}/Bài học`,
      };
    case MediaContextType.LEARNING_QUESTION:
      if (!lessonFolder)
        throw new BadRequestException(
          'Ảnh câu hỏi phải có lessonId của bài học',
        );
      return {
        contextType,
        contextId: lessonFolder,
        folderPath: `Kiến thức/${lessonFolder}/Bài tập/Câu hỏi`,
      };
    case MediaContextType.LEARNING_ANSWER:
      if (!lessonFolder)
        throw new BadRequestException(
          'Ảnh câu trả lời phải có lessonId của bài học',
        );
      return {
        contextType,
        contextId: lessonFolder,
        folderPath: `Kiến thức/${lessonFolder}/Bài tập/Câu trả lời`,
      };
    case MediaContextType.JOURNAL:
      return {
        contextType,
        contextId: ownerId,
        folderPath: `Nhật ký giao dịch/${userFolder}`,
      };
    case MediaContextType.PLAN:
      return {
        contextType,
        contextId: ownerId,
        folderPath: `Plan giao dịch/${userFolder}`,
      };
    case MediaContextType.FEATURED_TRADE:
      return {
        contextType,
        contextId: null,
        folderPath: 'Tin quan trọng trong tuần',
      };
    default:
      return {
        contextType: MediaContextType.GENERAL,
        contextId: ownerId,
        folderPath: `Khác/${userFolder}`,
      };
  }
}

export const driveFolderLayout = {
  learning: {
    lesson: 'Kiến thức/{lessonId}/Bài học',
    question: 'Kiến thức/{lessonId}/Bài tập/Câu hỏi',
    answer: 'Kiến thức/{lessonId}/Bài tập/Câu trả lời',
  },
  journal: 'Nhật ký giao dịch/{userId}',
  plan: 'Plan giao dịch/{userId}',
  featuredTrade: 'Tin quan trọng trong tuần',
} as const;
