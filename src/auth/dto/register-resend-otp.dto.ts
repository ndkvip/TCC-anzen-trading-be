import { IsEmail } from 'class-validator';

export class RegisterResendOtpDto {
  @IsEmail()
  email!: string;
}
