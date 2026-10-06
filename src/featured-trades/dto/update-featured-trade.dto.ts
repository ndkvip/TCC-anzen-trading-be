import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsOptional,
  IsString,
} from 'class-validator';

export class UpdateFeaturedTradeDto {
  @IsOptional() @IsDateString() weekStart?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) imageUrls?: string[];
  @IsOptional() @IsBoolean() isActive?: boolean;
}
