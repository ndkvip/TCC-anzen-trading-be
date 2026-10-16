import {
  IsBoolean,
  IsEnum,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';
import { AccountTier } from '../user.entity';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  name?: string;

  @IsOptional()
  @IsEnum(AccountTier)
  accountTier?: AccountTier;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
