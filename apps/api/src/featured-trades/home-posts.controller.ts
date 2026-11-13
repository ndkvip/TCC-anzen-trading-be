import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import type { AuthRequestUser } from '../auth/auth.types';
import { MediaContextType } from '../media/media-context';
import { UserRole } from '../users/user.entity';
import { CreateArticleDto, UpdateArticleDto } from './dto/article.dto';
import { FeaturedTradeImagesService } from './featured-trade-images.service';
import { FeaturedTradeService } from './featured-trade.service';

@Controller('home-posts')
export class HomePostsController {
  constructor(
    private readonly articles: FeaturedTradeService,
    private readonly images: FeaturedTradeImagesService,
  ) {}

  @Get()
  publicList() {
    return this.articles.publicHomePosts();
  }

  @Get('admin')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminList() {
    return this.articles.adminList('HOME_POST');
  }

  @Post('uploads')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @UseInterceptors(
    FilesInterceptor('files', 12, {
      limits: { fileSize: 10 * 1024 * 1024, files: 12 },
    }),
  )
  upload(
    @UploadedFiles() files: Express.Multer.File[],
    @CurrentUser() user: AuthRequestUser,
  ) {
    return this.images.upload(files, user, MediaContextType.HOME_POST);
  }

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  create(@Body() dto: CreateArticleDto) {
    return this.articles.createHomePost(dto);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  update(@Param('id') id: string, @Body() dto: UpdateArticleDto) {
    return this.articles.update(id, dto, 'HOME_POST');
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  remove(@Param('id') id: string) {
    return this.articles.remove(id, 'HOME_POST');
  }
}
