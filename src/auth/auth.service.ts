import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes, randomInt } from 'crypto';
import { Repository } from 'typeorm';
import {
  AccountTier,
  LearningTier,
  User,
  UserRole,
} from '../users/user.entity';
import { UsersService } from '../users/users.service';
import { JwtPayload } from './auth.types';
import { ChangePasswordDto } from './dto/change-password.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { RegisterRequestOtpDto } from './dto/register-request-otp.dto';
import { RegisterResendOtpDto } from './dto/register-resend-otp.dto';
import { RegisterVerifyOtpDto } from './dto/register-verify-otp.dto';
import { ResetPasswordOtpDto } from './dto/reset-password-otp.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { MailService } from './mail.service';

const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_RESEND_COOLDOWN_MS = 60 * 1000;
const MAX_OTP_ATTEMPTS = 5;

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly mail: MailService,
  ) {}

  async login(dto: LoginDto) {
    const user = await this.users.findByEmail(dto.email);
    if (
      !user ||
      !user.isActive ||
      !user.emailVerified ||
      !(await bcrypt.compare(dto.password, user.passwordHash))
    ) {
      throw new UnauthorizedException('Email hoặc mật khẩu không đúng');
    }
    user.currentDeviceId = dto.deviceId;
    user.tokenVersion += 1;
    await this.userRepository.save(user);
    return this.createSession(user, dto.deviceId);
  }

  async requestRegistrationOtp(dto: RegisterRequestOtpDto) {
    const email = this.normalizeEmail(dto.email);
    const name = dto.name.trim();
    let user = await this.users.findByEmail(email);
    if (user?.emailVerified) {
      throw new ConflictException('Email này đã được đăng ký');
    }

    const now = new Date();
    if (
      user?.verificationOtpLastSentAt &&
      now.getTime() - user.verificationOtpLastSentAt.getTime() <
        OTP_RESEND_COOLDOWN_MS
    ) {
      throw new BadRequestException(
        'Vui lòng đợi 60 giây trước khi gửi lại OTP',
      );
    }

    if (!user) {
      user = this.userRepository.create({
        email,
        name,
        passwordHash: await bcrypt.hash(dto.password, 12),
        role: UserRole.STUDENT,
        accountTier: AccountTier.STANDARD,
        learningTier: LearningTier.BASIC,
        emailVerified: false,
        isActive: true,
        currentDeviceId: null,
        tokenVersion: 0,
        verificationOtpAttempts: 0,
      });
    } else {
      user.passwordHash = await bcrypt.hash(dto.password, 12);
      user.name = name;
      user.accountTier = AccountTier.STANDARD;
      user.learningTier = LearningTier.BASIC;
      user.verificationOtpAttempts = 0;
    }
    return this.issueRegistrationOtp(user, email);
  }

  async resendRegistrationOtp(dto: RegisterResendOtpDto) {
    const email = this.normalizeEmail(dto.email);
    const user = await this.users.findByEmail(email);
    if (!user || user.emailVerified) {
      throw new BadRequestException(
        'Không có yêu cầu đăng ký đang chờ xác thực',
      );
    }
    return this.issueRegistrationOtp(user, email);
  }

  private async issueRegistrationOtp(user: User, email: string) {
    const now = new Date();
    if (
      user.verificationOtpLastSentAt &&
      now.getTime() - user.verificationOtpLastSentAt.getTime() <
        OTP_RESEND_COOLDOWN_MS
    ) {
      throw new BadRequestException(
        'Vui lòng đợi 60 giây trước khi gửi lại OTP',
      );
    }
    const otp = this.generateOtp();
    user.verificationOtpHash = this.hash(otp);
    user.verificationOtpExpiresAt = new Date(now.getTime() + OTP_TTL_MS);
    user.verificationOtpLastSentAt = now;
    user.verificationOtpAttempts = 0;
    await this.userRepository.save(user);
    await this.mail.sendVerificationOtp(email, otp);

    return {
      success: true,
      message: `Mã OTP đã được gửi tới ${email}`,
      expiresInSeconds: OTP_TTL_MS / 1000,
      resendAfterSeconds: OTP_RESEND_COOLDOWN_MS / 1000,
      ...(this.config.get('AUTH_EXPOSE_OTP') === 'true'
        ? { debugOtp: otp }
        : {}),
    };
  }

  async verifyRegistrationOtp(dto: RegisterVerifyOtpDto) {
    const email = this.normalizeEmail(dto.email);
    const user = await this.users.findByEmail(email);
    if (!user || user.emailVerified) {
      throw new BadRequestException('Yêu cầu đăng ký không hợp lệ');
    }
    if (
      !user.verificationOtpHash ||
      !user.verificationOtpExpiresAt ||
      user.verificationOtpExpiresAt.getTime() < Date.now()
    ) {
      throw new BadRequestException('OTP đã hết hạn. Vui lòng gửi lại mã mới');
    }
    if (user.verificationOtpAttempts >= MAX_OTP_ATTEMPTS) {
      throw new BadRequestException(
        'Bạn đã nhập sai quá nhiều lần. Vui lòng gửi lại OTP',
      );
    }
    const normalizedOtp = dto.otp.replace(/\s/g, '');
    if (this.hash(normalizedOtp) !== user.verificationOtpHash) {
      user.verificationOtpAttempts += 1;
      await this.userRepository.save(user);
      throw new BadRequestException('OTP không đúng');
    }

    user.emailVerified = true;
    user.accountTier = AccountTier.STANDARD;
    user.learningTier = LearningTier.BASIC;
    user.verificationOtpHash = null;
    user.verificationOtpExpiresAt = null;
    user.verificationOtpLastSentAt = null;
    user.verificationOtpAttempts = 0;
    user.currentDeviceId = dto.deviceId;
    user.tokenVersion += 1;
    await this.userRepository.save(user);
    return this.createSession(user, dto.deviceId);
  }

  async refresh(dto: RefreshDto) {
    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync<JwtPayload>(dto.refreshToken, {
        secret: this.config.getOrThrow('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Refresh token không hợp lệ');
    }
    const user = await this.users.findById(payload.sub);
    if (
      !user ||
      !user.isActive ||
      !user.emailVerified ||
      payload.type !== 'refresh' ||
      payload.deviceId !== dto.deviceId ||
      user.currentDeviceId !== dto.deviceId ||
      user.tokenVersion !== payload.tokenVersion
    ) {
      throw new UnauthorizedException('Phiên đăng nhập đã hết hiệu lực');
    }
    return this.createSession(user, dto.deviceId);
  }

  async profile(userId: string) {
    const user = await this.users.findById(userId);
    if (!user || !user.isActive || !user.emailVerified) {
      throw new UnauthorizedException('Phiên đăng nhập không hợp lệ');
    }
    return this.users.toPublic(user);
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.users.findById(userId);
    if (!user || !user.isActive || !user.emailVerified) {
      throw new UnauthorizedException('Phiên đăng nhập không hợp lệ');
    }
    user.name = dto.name.trim();
    return this.users.toPublic(await this.userRepository.save(user));
  }

  async logout(userId: string) {
    const user = await this.users.findById(userId);
    if (user) {
      user.currentDeviceId = null;
      user.tokenVersion += 1;
      await this.userRepository.save(user);
    }
    return { success: true };
  }

  async forgotPassword(email: string) {
    const user = await this.users.findByEmail(email);
    if (user?.isActive && user.emailVerified) {
      const token = randomBytes(32).toString('hex');
      user.resetTokenHash = this.hash(token);
      user.resetTokenExpiresAt = new Date(Date.now() + 30 * 60 * 1000);
      await this.userRepository.save(user);
      await this.mail.sendResetPassword(user.email, token);
    }
    return {
      message: 'Nếu email tồn tại, hướng dẫn đặt lại mật khẩu đã được gửi.',
    };
  }

  async requestPasswordResetOtp(email: string) {
    const normalizedEmail = this.normalizeEmail(email);
    const user = await this.users.findByEmail(normalizedEmail);
    const now = new Date();
    if (
      user?.resetOtpLastSentAt &&
      now.getTime() - user.resetOtpLastSentAt.getTime() < OTP_RESEND_COOLDOWN_MS
    ) {
      throw new BadRequestException(
        'Vui lòng đợi 60 giây trước khi gửi lại OTP',
      );
    }
    if (user?.isActive && user.emailVerified) {
      const otp = this.generateOtp();
      user.resetOtpHash = this.hash(otp);
      user.resetOtpExpiresAt = new Date(now.getTime() + OTP_TTL_MS);
      user.resetOtpLastSentAt = now;
      user.resetOtpAttempts = 0;
      await this.userRepository.save(user);
      await this.mail.sendPasswordResetOtp(user.email, otp);
      return {
        message: 'Nếu email tồn tại, mã đặt lại mật khẩu đã được gửi.',
        expiresInSeconds: OTP_TTL_MS / 1000,
        ...(this.config.get('AUTH_EXPOSE_OTP') === 'true'
          ? { debugOtp: otp }
          : {}),
      };
    }
    return {
      message: 'Nếu email tồn tại, mã đặt lại mật khẩu đã được gửi.',
      expiresInSeconds: OTP_TTL_MS / 1000,
    };
  }

  async resetPasswordOtp(dto: ResetPasswordOtpDto) {
    const user = await this.users.findByEmail(this.normalizeEmail(dto.email));
    if (
      !user ||
      !user.isActive ||
      !user.emailVerified ||
      !user.resetOtpHash ||
      !user.resetOtpExpiresAt ||
      user.resetOtpExpiresAt.getTime() < Date.now()
    ) {
      throw new BadRequestException('OTP đã hết hạn hoặc không hợp lệ');
    }
    if (user.resetOtpAttempts >= MAX_OTP_ATTEMPTS) {
      throw new BadRequestException(
        'Bạn đã nhập sai quá nhiều lần. Vui lòng gửi mã mới',
      );
    }
    const normalizedOtp = dto.otp.replace(/\s/g, '');
    if (this.hash(normalizedOtp) !== user.resetOtpHash) {
      user.resetOtpAttempts += 1;
      await this.userRepository.save(user);
      throw new BadRequestException('OTP không đúng');
    }
    user.passwordHash = await bcrypt.hash(dto.newPassword, 12);
    user.resetOtpHash = null;
    user.resetOtpExpiresAt = null;
    user.resetOtpLastSentAt = null;
    user.resetOtpAttempts = 0;
    user.resetTokenHash = null;
    user.resetTokenExpiresAt = null;
    user.currentDeviceId = null;
    user.tokenVersion += 1;
    await this.userRepository.save(user);
    return { success: true };
  }

  async resetPassword(token: string, newPassword: string) {
    const user = await this.userRepository.findOne({
      where: { resetTokenHash: this.hash(token) },
    });
    if (
      !user ||
      !user.resetTokenExpiresAt ||
      user.resetTokenExpiresAt.getTime() < Date.now()
    ) {
      throw new BadRequestException(
        'Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn',
      );
    }
    user.passwordHash = await bcrypt.hash(newPassword, 12);
    user.resetTokenHash = null;
    user.resetTokenExpiresAt = null;
    user.resetOtpHash = null;
    user.resetOtpExpiresAt = null;
    user.resetOtpLastSentAt = null;
    user.resetOtpAttempts = 0;
    user.currentDeviceId = null;
    user.tokenVersion += 1;
    await this.userRepository.save(user);
    return { success: true };
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    const user = await this.users.findById(userId);
    if (
      !user ||
      !user.isActive ||
      !user.emailVerified ||
      !(await bcrypt.compare(dto.currentPassword, user.passwordHash))
    ) {
      throw new BadRequestException('Mật khẩu hiện tại không đúng');
    }
    user.passwordHash = await bcrypt.hash(dto.newPassword, 12);
    user.tokenVersion += 1;
    await this.userRepository.save(user);
    return this.createSession(user, user.currentDeviceId || 'password-change');
  }

  private async createSession(user: User, deviceId: string) {
    const base = {
      sub: user.id,
      role: user.role,
      accountTier: user.accountTier,
      learningTier: user.learningTier,
      deviceId,
      tokenVersion: user.tokenVersion,
    };
    const accessToken = await this.jwt.signAsync(
      { ...base, type: 'access' satisfies JwtPayload['type'] },
      {
        secret: this.config.getOrThrow('JWT_ACCESS_SECRET'),
        expiresIn: this.config.get('JWT_ACCESS_TTL') || '15m',
      },
    );
    const refreshToken = await this.jwt.signAsync(
      { ...base, type: 'refresh' satisfies JwtPayload['type'] },
      {
        secret: this.config.getOrThrow('JWT_REFRESH_SECRET'),
        expiresIn: this.config.get('JWT_REFRESH_TTL') || '30d',
      },
    );
    return { accessToken, refreshToken, user: this.users.toPublic(user) };
  }

  private normalizeEmail(email: string) {
    return email.trim().toLowerCase();
  }

  private generateOtp() {
    return randomInt(100000, 1000000).toString();
  }

  private hash(value: string) {
    return createHash('sha256').update(value).digest('hex');
  }
}
