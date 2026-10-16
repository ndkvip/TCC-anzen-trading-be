import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import type { AuthRequestUser } from './auth.types';
import { CurrentUser } from './decorators/current-user.decorator';
import { ChangePasswordDto } from './dto/change-password.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { RegisterRequestOtpDto } from './dto/register-request-otp.dto';
import { RegisterResendOtpDto } from './dto/register-resend-otp.dto';
import { RegisterVerifyOtpDto } from './dto/register-verify-otp.dto';
import { ResetPasswordOtpDto } from './dto/reset-password-otp.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Post('register/request-otp')
  requestRegistrationOtp(@Body() dto: RegisterRequestOtpDto) {
    return this.auth.requestRegistrationOtp(dto);
  }

  @Post('register/resend-otp')
  resendRegistrationOtp(@Body() dto: RegisterResendOtpDto) {
    return this.auth.resendRegistrationOtp(dto);
  }

  @Post('register/verify-otp')
  verifyRegistrationOtp(@Body() dto: RegisterVerifyOtpDto) {
    return this.auth.verifyRegistrationOtp(dto);
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshDto) {
    return this.auth.refresh(dto);
  }

  @Post('forgot-password')
  forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.auth.forgotPassword(dto.email);
  }

  @Post('forgot-password/request-otp')
  requestPasswordResetOtp(@Body() dto: ForgotPasswordDto) {
    return this.auth.requestPasswordResetOtp(dto.email);
  }

  @Post('forgot-password/reset-otp')
  resetPasswordOtp(@Body() dto: ResetPasswordOtpDto) {
    return this.auth.resetPasswordOtp(dto);
  }

  @Post('reset-password')
  resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto.token, dto.newPassword);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: AuthRequestUser) {
    return this.auth.profile(user.sub);
  }

  @Patch('profile')
  @UseGuards(JwtAuthGuard)
  updateProfile(
    @CurrentUser() user: AuthRequestUser,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.auth.updateProfile(user.sub, dto);
  }

  @Post('change-password')
  @UseGuards(JwtAuthGuard)
  changePassword(
    @CurrentUser() user: AuthRequestUser,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.auth.changePassword(user.sub, dto);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  logout(@CurrentUser() user: AuthRequestUser) {
    return this.auth.logout(user.sub);
  }
}
