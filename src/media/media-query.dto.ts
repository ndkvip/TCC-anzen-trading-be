import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { MediaContextType } from './media-context';

export class MediaQueryDto {
  @IsOptional() @IsUUID() ownerId?: string;
  @IsOptional() @IsEnum(MediaContextType) contextType?: MediaContextType;
  @IsOptional() @IsString() @MaxLength(200) search?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page = 1;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize = 24;
}
