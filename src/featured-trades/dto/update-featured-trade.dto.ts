import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

class FeaturedTradeBlockDto {
  @IsIn(['text', 'image']) type!: 'text' | 'image';
  @IsOptional() @IsString() text?: string;
  @IsOptional() @IsString() imageUrl?: string;
}

export class UpdateFeaturedTradeDto {
  @IsOptional() @IsDateString() weekStart?: string;
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() summary?: string;
  @IsOptional() @IsString() coverImageUrl?: string;
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => FeaturedTradeBlockDto)
  contentBlocks?: FeaturedTradeBlockDto[];
  @IsOptional() @IsArray() @IsString({ each: true }) imageUrls?: string[];
  @IsOptional() @IsBoolean() isActive?: boolean;
}
