import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import type { Response } from 'express';
import { FileInterceptor } from '@nestjs/platform-express';
import { IsEnum, IsOptional, IsString } from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthRequestUser } from '../auth/auth.types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MediaContextType } from './media-context';
import { MediaService } from './media.service';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UserRole } from '../users/user.entity';
import { MediaQueryDto } from './media-query.dto';

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

  @Get('admin/all')
  @UseGuards(RolesGuard)
  @Roles(UserRole.ADMIN)
  adminList(
    @CurrentUser() user: AuthRequestUser,
    @Query() query: MediaQueryDto,
  ) {
    return this.service.adminList(user, query);
  }

  @Get('drive-images/:fileId')
  async image(
    @CurrentUser() user: AuthRequestUser,
    @Param('fileId') fileId: string,
    @Res() response: Response,
  ) {
    const image = await this.service.downloadOwnedImage(user, fileId);
    response.setHeader('Content-Type', image.mimeType);
    response.setHeader('Cache-Control', 'private, no-store');
    response.send(image.buffer);
  }

  @Post('register')
  register(@CurrentUser() user: AuthRequestUser, @Body() dto: MediaDto) {
    return this.service.register(user, dto);
  }

  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }),
  )
  upload(
    @CurrentUser() user: AuthRequestUser,
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: UploadMediaDto,
  ) {
    if (!file?.buffer)
      throw new BadRequestException('Vui lòng chọn một tệp hình ảnh');
    return this.service.upload(
      user,
      { ...dto, contextType: dto.contextType ?? MediaContextType.GENERAL },
      file.buffer,
    );
  }

  @Get('provider')
  provider() {
    return this.service.driveConfig();
  }
}
