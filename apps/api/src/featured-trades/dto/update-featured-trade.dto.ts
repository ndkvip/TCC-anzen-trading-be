import { IsDateString, IsOptional } from 'class-validator';
import { UpdateArticleDto } from './article.dto';

export class UpdateFeaturedTradeDto extends UpdateArticleDto {
  @IsOptional() @IsDateString() weekStart?: string;
}
