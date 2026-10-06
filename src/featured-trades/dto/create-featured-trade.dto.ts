import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateFeaturedTradeDto {
  @IsDateString() weekStart!: string;
  @IsArray() @IsString({ each: true }) imageUrls!: string[];
  @IsOptional() @IsBoolean() isActive?: boolean;
}
