import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { LessonImagesService } from './lesson-images.service';
import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Param,
  Patch,
  Post,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  Res,
} from '@nestjs/common';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import type { AuthRequestUser } from '../auth/auth.types';
import { UserRole } from '../users/user.entity';
import { LearningService } from './learning.service';
import { LessonTier } from './lesson.entity';
import { MediaContextType } from '../media/media-context';

class ProgressDto {
  @IsNumber() @Min(0) @Max(1) progress!: number;
  @IsOptional() @IsInt() @Min(0) answeredCount?: number;
  @IsOptional() @IsInt() @Min(0) correctCount?: number;
}
class LessonDto {
  @IsOptional() @IsString() slug?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsEnum(LessonTier) tier?: LessonTier;
  @IsOptional() @IsInt() @Min(0) position?: number;
  @IsOptional() @IsInt() @Min(1) durationMinutes?: number;
  @IsOptional() @IsBoolean() isPublished?: boolean;
  @IsOptional() @IsArray() knowledgeCards?: Record<string, unknown>[];
  @IsOptional() @IsArray() questions?: Record<string, unknown>[];
}

@Controller('learning')
@UseGuards(JwtAuthGuard)
export class LearningController {
  constructor(
    private readonly learning: LearningService,
    private readonly images: LessonImagesService,
  ) {}
  @Post('admin/lessons/:id/images')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 10 * 1024 * 1024, files: 1 },
    }),
  )
  async uploadImage(
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: AuthRequestUser,
  ) {
    await this.learning.imageAccess(id);
    return this.images.upload(
      id,
      file,
      'Bài học',
      user,
      MediaContextType.LEARNING_LESSON,
    );
  }

  @Post('admin/lessons/:id/exercise-images')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 10 * 1024 * 1024, files: 1 },
    }),
  )
  async uploadExerciseImage(
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
    @CurrentUser() user: AuthRequestUser,
    @Body('mediaContext') mediaContext?: MediaContextType,
  ) {
    await this.learning.imageAccess(id);
    const context =
      mediaContext === MediaContextType.LEARNING_ANSWER
        ? MediaContextType.LEARNING_ANSWER
        : MediaContextType.LEARNING_QUESTION;
    const uploaded = await this.images.upload(
      id,
      file,
      'Bài tập',
      user,
      context,
    );
    return { imageUrl: uploaded.imageUrl };
  }

  @Get('lessons/:id/drive-images/:fileId')
  async driveImage(
    @Param('id') id: string,
    @Param('fileId') fileId: string,
    @CurrentUser() user: AuthRequestUser,
    @Res() response: Response,
  ) {
    await this.learning.imageAccess(id, user);
    const image = await this.images.driveImage(id, fileId);
    response.setHeader('Content-Type', image.mimeType);
    response.setHeader('Cache-Control', 'private, no-store');
    response.send(image.buffer);
  }

  @Get('lessons/:id/images/:name')
  async image(
    @Param('id') id: string,
    @Param('name') name: string,
    @CurrentUser() user: AuthRequestUser,
    @Res() response: Response,
  ) {
    await this.learning.imageAccess(id, user);
    response.setHeader('Cache-Control', 'private, no-store');
    response.sendFile(await this.images.path(id, name));
  }

  @Get('lessons/:id/exercise-images/:name')
  async exerciseImage(
    @Param('id') id: string,
    @Param('name') name: string,
    @CurrentUser() user: AuthRequestUser,
    @Res() response: Response,
  ) {
    await this.learning.imageAccess(id, user);
    response.setHeader('Cache-Control', 'private, no-store');
    response.sendFile(await this.images.path(id, name, 'Bài tập'));
  }

  @Get('lessons')
  @Header('Cache-Control', 'private, no-store')
  list(@CurrentUser() user: AuthRequestUser) {
    return this.learning.list(user);
  }
  @Get('lessons/:id')
  @Header('Cache-Control', 'private, no-store')
  detail(@Param('id') id: string, @CurrentUser() user: AuthRequestUser) {
    return this.learning.detail(id, user);
  }
  @Post('lessons/:id/progress') progress(
    @Param('id') id: string,
    @CurrentUser() user: AuthRequestUser,
    @Body() dto: ProgressDto,
  ) {
    return this.learning.saveProgress(id, user, dto);
  }
  @Get('admin/lessons')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  adminList() {
    return this.learning.adminList();
  }
  @Post('admin/lessons') @UseGuards(RolesGuard) @Roles(UserRole.ADMIN) create(
    @Body() dto: LessonDto,
  ) {
    return this.learning.create(dto);
  }
  @Patch('admin/lessons/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  update(@Param('id') id: string, @Body() dto: LessonDto) {
    return this.learning.update(id, dto);
  }
  @Delete('admin/lessons/:id')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  async remove(@Param('id') id: string) {
    // Validate before deleting media so an invalid lesson ID cannot remove orphaned assets.
    await this.learning.imageAccess(id);
    await this.images.removeLesson(id);
    return this.learning.remove(id);
  }
}
