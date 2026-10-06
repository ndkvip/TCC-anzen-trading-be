import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Res,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UserRole } from '../users/user.entity';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthRequestUser } from '../auth/auth.types';
import { CreateFeaturedTradeDto } from './dto/create-featured-trade.dto';
import { UpdateFeaturedTradeDto } from './dto/update-featured-trade.dto';
import { FeaturedTradeService } from './featured-trade.service';
import { FeaturedTradeImagesService } from './featured-trade-images.service';

@Controller('featured-trades')
export class FeaturedTradeController {
  constructor(
    private readonly service: FeaturedTradeService,
    private readonly images: FeaturedTradeImagesService,
  ) {}
  @Get() public(@Query('week') weekStart?: string) {
    return this.service.publicForWeek(weekStart);
  }
  @Get('admin')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  adminList() {
    return this.service.adminList();
  }
  @Post('uploads')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @UseInterceptors(
    FilesInterceptor('files', 12, {
      limits: { fileSize: 10 * 1024 * 1024, files: 12 },
    }),
  )
  uploadImages(
    @UploadedFiles() files: Express.Multer.File[],
    @CurrentUser() user: AuthRequestUser,
  ) {
    return this.images.upload(files, user);
  }
  @Get('images/:name')
  async image(@Param('name') name: string, @Res() response: Response) {
    response.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    response.sendFile(await this.images.path(name));
  }
  @Post() @UseGuards(JwtAuthGuard, RolesGuard) @Roles(UserRole.ADMIN) create(
    @Body() dto: CreateFeaturedTradeDto,
  ) {
    return this.service.create(dto);
  }
  @Patch(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  update(@Param('id') id: string, @Body() dto: UpdateFeaturedTradeDto) {
    return this.service.update(id, dto);
  }
  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  remove(@Param('id') id: string) {
    return this.service.remove(id);
  }
}
