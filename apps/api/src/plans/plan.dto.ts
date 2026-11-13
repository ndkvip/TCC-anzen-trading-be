import { Transform } from 'class-transformer';
import {
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  ValidateIf,
} from 'class-validator';
import { PlanScope, PlanStatus } from './plan.entity';
import { PLAN_SYMBOL_PATTERN } from './plan-symbol';

class PlanSymbolDto {
  @ValidateIf((_object, value) => value !== undefined)
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  @IsString()
  @Matches(PLAN_SYMBOL_PATTERN)
  symbol?: string;
}

export class PlanDto extends PlanSymbolDto {
  @IsOptional() @IsEnum(PlanScope) scope?: PlanScope;
  @IsOptional() @IsString() periodKey?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsEnum(PlanStatus) status?: PlanStatus;
  @IsOptional() @IsArray() contentDelta?: Record<string, unknown>[];
  @IsOptional() @IsArray() timeframePairs?: string[];
  @IsOptional() @IsArray() imageUrls?: string[];
}

export class PlanListQueryDto extends PlanSymbolDto {
  @IsOptional() @IsEnum(PlanScope) scope?: PlanScope;
}

export class PlanResolveQueryDto extends PlanSymbolDto {
  @IsEnum(PlanScope) scope!: PlanScope;
  @IsString() @IsNotEmpty() periodKey!: string;
}

export class AdminPlanQueryDto extends PlanSymbolDto {
  @IsOptional() @IsString() userId?: string;
}
