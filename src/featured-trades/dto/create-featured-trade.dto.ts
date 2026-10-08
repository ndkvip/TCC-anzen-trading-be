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

export class CreateFeaturedTradeDto {
  @IsDateString() weekStart!: string;
  @IsString() title!: string;
  @IsOptional() @IsString() summary?: string;
  @IsOptional() @IsString() coverImageUrl?: string;
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => FeaturedTradeBlockDto)
  contentBlocks!: FeaturedTradeBlockDto[];
  // Accepted so old admin clients can still save while being upgraded.
  @IsOptional() @IsArray() @IsString({ each: true }) imageUrls?: string[];
  @IsOptional() @IsBoolean() isActive?: boolean;
}
