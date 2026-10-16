import {
  IsDateString,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateRedNewsDto {
  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  currency?: string;

  @IsOptional()
  @IsIn(['LOW', 'MEDIUM', 'HIGH'])
  impact?: 'LOW' | 'MEDIUM' | 'HIGH';

  @IsDateString()
  releaseAt!: string;
}
