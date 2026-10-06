import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { IsArray, IsEnum, IsOptional, IsString } from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthRequestUser } from '../auth/auth.types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UserRole } from '../users/user.entity';
import { PlanScope } from './plan.entity';
import { PlansService } from './plans.service';
class PlanDto {
  @IsOptional() @IsEnum(PlanScope) scope?: PlanScope;
  @IsOptional() @IsString() periodKey?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsArray() contentDelta?: Record<string, unknown>[];
  @IsOptional() @IsArray() timeframePairs?: string[];
  @IsOptional() @IsArray() imageUrls?: string[];
}
@Controller('plans')
@UseGuards(JwtAuthGuard)
export class PlansController {
  constructor(private readonly service: PlansService) {}
  @Get() list(
    @CurrentUser() u: AuthRequestUser,
    @Query('scope') scope?: PlanScope,
  ) {
    return this.service.list(u.sub, scope);
  }
  @Get('resolve') get(
    @CurrentUser() u: AuthRequestUser,
    @Query('scope') scope: PlanScope,
    @Query('periodKey') key: string,
  ) {
    return this.service.get(u.sub, scope, key);
  }
  @Put() upsert(@CurrentUser() u: AuthRequestUser, @Body() dto: PlanDto) {
    return this.service.upsert(u.sub, dto);
  }
  @Delete(':id') remove(
    @CurrentUser() u: AuthRequestUser,
    @Param('id') id: string,
  ) {
    return this.service.remove(u.sub, id);
  }
  @Get('admin/all') @UseGuards(RolesGuard) @Roles(UserRole.ADMIN) admin(
    @Query('userId') userId?: string,
  ) {
    return this.service.adminList(userId);
  }
}
