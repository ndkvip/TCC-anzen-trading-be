import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  IsArray,
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  IsUUID,
  ArrayMaxSize,
  MinLength,
} from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthRequestUser } from '../auth/auth.types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UserRole } from '../users/user.entity';
import { JournalMode, TradeDirection } from './trade-journal.entity';
import { JournalService } from './journal.service';
export class JournalDto {
  @IsOptional() @IsEnum(JournalMode) mode?: JournalMode;
  @IsOptional() @IsDateString() tradeDate?: string;
  @IsOptional() @IsString() @MinLength(1) @MaxLength(30) symbol?: string;
  @IsOptional() @IsEnum(TradeDirection) direction?: TradeDirection;
  @IsOptional() @IsDateString() entryAt?: string;
  @IsOptional() @IsNumber() @Min(0) holdingHours?: number;
  @IsOptional() @IsString() @MaxLength(100) management?: string;
  @IsOptional() @IsNumber() riskReward?: number;
  @IsOptional() @IsNumber() pnl?: number | null;
  @IsOptional() @IsString() @MaxLength(50) timeframePair?: string;
  @IsOptional() @IsString() @MaxLength(100) priceMovement?: string;
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  processImageUrls?: string[];
  @IsOptional() @IsString() @MaxLength(20000) idea?: string;
  @IsOptional() @IsString() @MaxLength(20000) execution?: string;
  @IsOptional() @IsString() @MaxLength(20000) result?: string;
}
export class CreateJournalDto extends JournalDto {
  @IsOptional() @IsUUID('4') id?: string;
}
@Controller('journal')
@UseGuards(JwtAuthGuard)
export class JournalController {
  constructor(private readonly service: JournalService) {}
  @Get() list(
    @CurrentUser() user: AuthRequestUser,
    @Query('mode') mode = JournalMode.INTRA_DAY,
    @Query('date') date?: string,
  ) {
    return this.service.list(user.sub, mode, date);
  }
  @Get('summary') summary(
    @CurrentUser() user: AuthRequestUser,
    @Query('mode') mode = JournalMode.INTRA_DAY,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.service.summary(user.sub, mode, from, to);
  }
  @Post() create(
    @CurrentUser() user: AuthRequestUser,
    @Body() dto: CreateJournalDto,
  ) {
    return this.service.create(user.sub, dto);
  }
  @Patch(':id') update(
    @CurrentUser() user: AuthRequestUser,
    @Param('id') id: string,
    @Body() dto: JournalDto,
  ) {
    return this.service.update(user.sub, id, dto);
  }
  @Delete(':id') remove(
    @CurrentUser() user: AuthRequestUser,
    @Param('id') id: string,
  ) {
    return this.service.remove(user.sub, id);
  }
  @Get('admin/all') @UseGuards(RolesGuard) @Roles(UserRole.ADMIN) admin(
    @Query('userId') userId?: string,
  ) {
    return this.service.adminList(userId);
  }
}
