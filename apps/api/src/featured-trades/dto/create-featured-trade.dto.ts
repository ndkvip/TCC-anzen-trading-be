import { IsDateString } from 'class-validator';
import { CreateArticleDto } from './article.dto';

export class CreateFeaturedTradeDto extends CreateArticleDto {
  @IsDateString() weekStart!: string;
}
