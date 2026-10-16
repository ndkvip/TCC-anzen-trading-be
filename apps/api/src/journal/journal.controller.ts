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
  ParseUUIDPipe,
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
  ValidateBy,
  ValidateIf,
} from 'class-validator';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import type { AuthRequestUser } from '../auth/auth.types';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UserRole } from '../users/user.entity';
import {
  JournalMode,
  TradeDirection,
  type JournalNoteOperation,
} from './trade-journal.entity';
import { JournalService } from './journal.service';
export class JournalDto {
  @ValidateIf((_object, value) => value !== undefined)
  @ValidateBy({
    name: 'journalNotes',
    validator: {
      validate: (value: unknown) =>
        Array.isArray(value) &&
        value.length <= 2000 &&
        JSON.stringify(value).length <= 100000 &&
        value.every((op: unknown) => {
          if (!op || typeof op !== 'object' || Array.isArray(op)) return false;
          const item = op as Record<string, unknown>;
          const insert = item.insert;
          const validInsert =
            typeof insert === 'string' ||
            (!!insert &&
              typeof insert === 'object' &&
              !Array.isArray(insert) &&
              Object.keys(insert).length === 1 &&
              typeof (insert as { image?: unknown }).image === 'string' &&
              (insert as { image: string }).image.length > 0);
          return (
            validInsert &&
            Object.keys(item).every(
              (key) => key === 'insert' || key === 'attributes',
            ) &&
            (item.attributes === undefined ||
              (!!item.attributes &&
                typeof item.attributes === 'object' &&
                !Array.isArray(item.attributes) &&
                Object.values(item.attributes).every((value) =>
                  ['string', 'number', 'boolean'].includes(typeof value),
                )))
          );
        }),
      defaultMessage: () => 'Nội dung ghi chú không hợp lệ hoặc quá dài',
    },
  })
  notesDelta?: JournalNoteOperation[];

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
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
    @Body() dto: JournalDto,
  ) {
    return this.service.update(user.sub, id, dto);
  }
  @Delete(':id') remove(
    @CurrentUser() user: AuthRequestUser,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ) {
    return this.service.remove(user.sub, id);
  }
  @Get('admin/all') @UseGuards(RolesGuard) @Roles(UserRole.ADMIN) admin(
    @Query('userId') userId?: string,
  ) {
    return this.service.adminList(userId);
  }
}
