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
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthRequestUser } from '../auth/auth.types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UserRole } from '../users/user.entity';
import {
  AdminPlanQueryDto,
  PlanDto,
  PlanListQueryDto,
  PlanResolveQueryDto,
} from './plan.dto';
import { PlansService } from './plans.service';
@Controller('plans')
@UseGuards(JwtAuthGuard)
export class PlansController {
  constructor(private readonly service: PlansService) {}
  @Get() list(
    @CurrentUser() u: AuthRequestUser,
    @Query() query: PlanListQueryDto,
  ) {
    return this.service.list(u.sub, query.scope, query.symbol);
  }
  @Get('resolve') get(
    @CurrentUser() u: AuthRequestUser,
    @Query() query: PlanResolveQueryDto,
  ) {
    return this.service.get(u.sub, query.scope, query.periodKey, query.symbol);
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
    @Query() query: AdminPlanQueryDto,
  ) {
    return this.service.adminList(query.userId, query.symbol);
  }
}
