import { IsString, MinLength } from 'class-validator';

export class RefreshDto {
  @IsString()
  refreshToken!: string;

  @IsString()
  @MinLength(6)
  deviceId!: string;
}
