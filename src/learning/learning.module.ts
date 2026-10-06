import { LessonImagesService } from './lesson-images.service';
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LearningController } from './learning.controller';
import { LessonProgress } from './lesson-progress.entity';
import { Lesson } from './lesson.entity';
import { LearningService } from './learning.service';
import { MediaModule } from '../media/media.module';
@Module({
  imports: [TypeOrmModule.forFeature([Lesson, LessonProgress]), MediaModule],
  controllers: [LearningController],
  providers: [LearningService, LessonImagesService],
  exports: [LearningService],
})
export class LearningModule {}
