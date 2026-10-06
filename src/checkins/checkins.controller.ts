import { Body, Controller, Get, Put, Query, UseGuards } from '@nestjs/common';
import { IsArray, IsDateString } from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthRequestUser } from '../auth/auth.types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UserRole } from '../users/user.entity';
import { CheckinsService } from './checkins.service';
class CheckinDto {
  @IsDateString() date!: string;
  @IsArray() scores!: number[];
}
@Controller('checkins')
@UseGuards(JwtAuthGuard)
export class CheckinsController {
  constructor(private readonly service: CheckinsService) {}
  @Get() list(@CurrentUser() u: AuthRequestUser) {
    return this.service.list(u.sub);
  }
  @Put('today') upsert(
    @CurrentUser() u: AuthRequestUser,
    @Body() dto: CheckinDto,
  ) {
    return this.service.upsert(u.sub, dto.date, dto.scores);
  }
  @Get('admin/all') @UseGuards(RolesGuard) @Roles(UserRole.ADMIN) admin(
    @Query('userId') userId?: string,
  ) {
    return this.service.adminList(userId);
  }
}
