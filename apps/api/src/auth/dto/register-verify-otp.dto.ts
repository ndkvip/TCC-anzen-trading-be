import { Transform, type TransformFnParams } from 'class-transformer';
import { IsEmail, IsString, Matches, MinLength } from 'class-validator';

export class RegisterVerifyOtpDto {
  @IsEmail()
  @Transform(({ value }: TransformFnParams) => {
    const raw: unknown = value;
    return typeof raw === 'string' ? raw.trim().toLowerCase() : raw;
  })
  email!: string;

  @IsString()
  @Transform(({ value }: TransformFnParams) => {
    const raw: unknown = value;
    return typeof raw === 'string' ? raw.replace(/\s/g, '') : raw;
  })
  @Matches(/^\d{6}$/, { message: 'OTP phải gồm 6 chữ số' })
  otp!: string;

  @IsString()
  @MinLength(6)
  deviceId!: string;
}
