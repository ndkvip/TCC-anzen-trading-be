import { BadRequestException, Body, Controller, Get, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { IsEnum, IsOptional, IsString } from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthRequestUser } from '../auth/auth.types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MediaContextType } from './media-context';
import { MediaService } from './media.service';

class MediaDto {
  @IsOptional() @IsString() driveFileId?: string;
  @IsOptional() @IsString() driveFolderId?: string;
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() mimeType?: string;
  @IsOptional() @IsString() remoteUrl?: string;
  @IsOptional() @IsString() thumbnailUrl?: string;
  @IsOptional() @IsString() localReference?: string;
  @IsOptional() @IsEnum(MediaContextType) contextType?: MediaContextType;
  @IsOptional() @IsString() lessonId?: string;
}
class UploadMediaDto extends MediaDto {}

@Controller('media')
@UseGuards(JwtAuthGuard)
export class MediaController {
  constructor(private readonly service: MediaService) {}

  @Get()
  list(@CurrentUser() user: AuthRequestUser) {
    return this.service.list(user.sub);
  }

  @Post('register')
  register(@CurrentUser() user: AuthRequestUser, @Body() dto: MediaDto) {
    return this.service.register(user, dto);
  }

  @Post('upload')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }))
  upload(@CurrentUser() user: AuthRequestUser, @UploadedFile() file: Express.Multer.File, @Body() dto: UploadMediaDto) {
    if (!file?.buffer) throw new BadRequestException('Vui lòng chọn một tệp hình ảnh');
    return this.service.upload(user, { ...dto, contextType: dto.contextType ?? MediaContextType.GENERAL }, file.buffer);
  }

  @Get('provider')
  provider() {
    return this.service.driveConfig();
  }
}
