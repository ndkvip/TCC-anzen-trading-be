import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsIn,
  IsString,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

export class ArticleBlockDto {
  @IsIn(['text', 'image']) type!: 'text' | 'image';
  @ValidateIf((_, value) => value !== undefined) @IsString() text?: string;
  @ValidateIf((_, value) => value !== undefined) @IsString() imageUrl?: string;
}

export class CreateArticleDto {
  @IsString() title!: string;
  @ValidateIf((_, value) => value !== undefined) @IsString() summary?: string;
  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  coverImageUrl?: string;
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ArticleBlockDto)
  contentBlocks!: ArticleBlockDto[];
  @ValidateIf((_, value) => value !== undefined)
  @IsArray()
  @IsString({ each: true })
  imageUrls?: string[];
  @ValidateIf((_, value) => value !== undefined)
  @IsBoolean()
  isActive?: boolean;
}

export class UpdateArticleDto {
  @ValidateIf((_, value) => value !== undefined) @IsString() title?: string;
  @ValidateIf((_, value) => value !== undefined) @IsString() summary?: string;
  @ValidateIf((_, value) => value !== undefined)
  @IsString()
  coverImageUrl?: string;
  @ValidateIf((_, value) => value !== undefined)
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ArticleBlockDto)
  contentBlocks?: ArticleBlockDto[];
  @ValidateIf((_, value) => value !== undefined)
  @IsArray()
  @IsString({ each: true })
  imageUrls?: string[];
  @ValidateIf((_, value) => value !== undefined)
  @IsBoolean()
  isActive?: boolean;
}
