import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UserRole } from '../users/user.entity';
import { CreateRedNewsDto } from './dto/create-red-news.dto';
import { UpdateRedNewsDto } from './dto/update-red-news.dto';
import { RedNewsService } from './red-news.service';

@Controller('red-news')
export class RedNewsController {
  constructor(private readonly redNews: RedNewsService) {}

  @Get()
  listPublic() {
    return this.redNews.listPublic();
  }

  @Get('admin')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  listAdmin() {
    return this.redNews.listAdmin();
  }

  @Post('sync')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  sync() {
    return this.redNews.syncFromCalendar();
  }

  @Post()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  create(@Body() dto: CreateRedNewsDto) {
    return this.redNews.create(dto);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  update(@Param('id') id: string, @Body() dto: UpdateRedNewsDto) {
    return this.redNews.update(id, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  remove(@Param('id') id: string) {
    return this.redNews.remove(id);
  }
}
