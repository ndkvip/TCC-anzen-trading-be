import { BadRequestException, ConflictException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';
import {
  AccountTier,
  LearningTier,
  User,
  UserRole,
} from '../users/user.entity';

describe('AuthService registration OTP', () => {
  const user = (): User => ({
    id: 'user-1',
    email: 'trader@example.com',
    name: 'trader',
    passwordHash: '',
    role: UserRole.STUDENT,
    accountTier: AccountTier.STANDARD,
    learningTier: LearningTier.BASIC,
    emailVerified: false,
    verificationOtpHash: null,
    verificationOtpExpiresAt: null,
    verificationOtpLastSentAt: null,
    verificationOtpAttempts: 0,
    isActive: true,
    currentDeviceId: null,
    tokenVersion: 0,
    resetTokenHash: null,
    resetTokenExpiresAt: null,
    resetOtpHash: null,
    resetOtpExpiresAt: null,
    resetOtpLastSentAt: null,
    resetOtpAttempts: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
  });

  it('creates a standard account after a valid OTP and returns a session', async () => {
    const pending = user();
    const sent: string[] = [];
    let stored: User | null = null;
    const repo = {
      create: (value: Partial<User>) => ({ ...pending, ...value }),
      save: (value: User) => {
        stored = value;
        return Promise.resolve(value);
      },
    };
    const users = {
      findByEmail: () => Promise.resolve(stored),
      findById: () => Promise.resolve(stored),
      toPublic: (value: User) => ({
        id: value.id,
        email: value.email,
        name: value.name,
        role: value.role,
        accountTier: value.accountTier,
        learningTier: value.learningTier,
        emailVerified: value.emailVerified,
        isActive: value.isActive,
      }),
    };
    const jwt = {
      signAsync: (payload: unknown) =>
        Promise.resolve(`${(payload as { type: string }).type}-token`),
    };
    const config = {
      get: (key: string) => (key === 'AUTH_EXPOSE_OTP' ? 'true' : undefined),
      getOrThrow: (key: string) => `${key}-secret`,
    };
    const mail = {
      sendVerificationOtp: (_email: string, otp: string) => {
        sent.push(otp);
        return Promise.resolve();
      },
      sendResetPassword: () => Promise.resolve(),
    };
    const service = new AuthService(
      repo as never,
      users as never,
      jwt as never,
      config as never,
      mail as never,
    );

    const response = await service.requestRegistrationOtp({
      name: '  Nguyễn Duy Khánh  ',
      email: 'TRADER@example.com',
      password: 'password123',
    });
    expect(response.success).toBe(true);
    expect(response.debugOtp).toMatch(/^\d{6}$/);
    expect(sent).toEqual([response.debugOtp]);
    expect(stored?.name).toBe('Nguyễn Duy Khánh');

    Object.assign(pending, stored);
    pending.email = 'trader@example.com';
    pending.passwordHash = await bcrypt.hash('password123', 4);

    const session = await service.verifyRegistrationOtp({
      email: 'trader@example.com',
      otp: response.debugOtp!,
      deviceId: 'iphone-simulator-1',
    });
    expect(session.user.name).toBe('Nguyễn Duy Khánh');
    expect(session.user.accountTier).toBe(AccountTier.STANDARD);
    expect(session.user.emailVerified).toBe(true);
    expect(session.accessToken).toBe('access-token');
  });

  it('updates the authenticated profile name and returns public user data', async () => {
    const verified = user();
    verified.emailVerified = true;
    verified.name = 'Tên cũ';
    const repo = {
      save: (value: User) => Promise.resolve(value),
    };
    const users = {
      findById: (id: string) =>
        Promise.resolve(id === verified.id ? verified : null),
      toPublic: (value: User) => ({
        id: value.id,
        email: value.email,
        name: value.name,
        role: value.role,
        accountTier: value.accountTier,
        learningTier: value.learningTier,
        emailVerified: value.emailVerified,
        isActive: value.isActive,
      }),
    };
    const service = new AuthService(
      repo as never,
      users as never,
      {} as never,
      {} as never,
      {} as never,
    );

    const profile = await service.updateProfile(verified.id, {
      name: '  Nguyễn Duy Khánh  ',
    });

    expect(verified.name).toBe('Nguyễn Duy Khánh');
    expect(profile.name).toBe('Nguyễn Duy Khánh');
    expect(profile.email).toBe(verified.email);
  });

  it('rejects an already verified email', async () => {
    const verified = user();
    verified.emailVerified = true;
    const users = { findByEmail: () => Promise.resolve(verified) };
    const service = new AuthService(
      {
        create: () => verified,
        save: () => Promise.resolve(verified),
      } as never,
      users as never,
      {} as never,
      { get: () => undefined } as never,
      {} as never,
    );
    await expect(
      service.requestRegistrationOtp({
        name: 'Nguyễn Duy Khánh',
        email: verified.email,
        password: 'password123',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('increments failed OTP attempts and rejects the code', async () => {
    const pending = user();
    pending.verificationOtpHash = 'hash-of-real-code';
    pending.verificationOtpExpiresAt = new Date(Date.now() + 60_000);
    const users = { findByEmail: () => Promise.resolve(pending) };
    const service = new AuthService(
      { save: (value: User) => Promise.resolve(value) } as never,
      users as never,
      {} as never,
      {} as never,
      {} as never,
    );
    await expect(
      service.verifyRegistrationOtp({
        email: pending.email,
        otp: '000000',
        deviceId: 'iphone-1',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(pending.verificationOtpAttempts).toBe(1);
  });
});
