import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';
import {
  AccountTier,
  LearningTier,
  User,
  UserRole,
} from '../users/user.entity';

const publicUser = (user: User) => ({
  id: user.id,
  email: user.email,
  name: user.name,
  role: user.role,
  accountTier: user.accountTier,
  learningTier: user.learningTier,
  emailVerified: user.emailVerified,
  isActive: user.isActive,
});

async function makeUser(overrides: Partial<User> = {}): Promise<User> {
  return {
    id: 'student-1',
    email: 'student@example.com',
    name: 'Học viên',
    passwordHash: '',
    role: UserRole.STUDENT,
    accountTier: AccountTier.STANDARD,
    learningTier: LearningTier.BASIC,
    emailVerified: true,
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
    ...overrides,
  };
}

function makeService(user: User) {
  const repo = {
    save: jest.fn(async (value: User) => value),
  };
  const users = {
    findByEmail: jest.fn(async (email: string) =>
      email === user.email ? user : null,
    ),
    findById: jest.fn(async (id: string) => (id === user.id ? user : null)),
    toPublic: publicUser,
  };
  const jwt = {
    verifyAsync: jest.fn(),
    signAsync: jest.fn(
      async (payload: { type: string }) => `${payload.type}-token`,
    ),
  };
  const config = {
    get: jest.fn((key: string) => (key === 'JWT_ACCESS_TTL' ? '15m' : '30d')),
    getOrThrow: jest.fn((key: string) => `${key}-secret`),
  };
  const service = new AuthService(
    repo as never,
    users as never,
    jwt as never,
    config as never,
    {} as never,
  );
  return { service, repo, users, jwt };
}

describe('AuthService session and account controls', () => {
  it('rejects login when email is not verified or account is locked', async () => {
    const passwordHash = await bcrypt.hash('password123', 4);
    const unverified = await makeUser({ passwordHash, emailVerified: false });
    await expect(
      makeService(unverified).service.login({
        email: unverified.email,
        password: 'password123',
        deviceId: 'iphone-a',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);

    const locked = await makeUser({ passwordHash, isActive: false });
    await expect(
      makeService(locked).service.login({
        email: locked.email,
        password: 'password123',
        deviceId: 'iphone-a',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('makes the previous device session stale when a second device logs in', async () => {
    const user = await makeUser({
      passwordHash: await bcrypt.hash('password123', 4),
    });
    const { service } = makeService(user);

    const first = await service.login({
      email: user.email,
      password: 'password123',
      deviceId: 'iphone-a',
    });
    const firstVersion = user.tokenVersion;
    const second = await service.login({
      email: user.email,
      password: 'password123',
      deviceId: 'iphone-b',
    });

    expect(first.user).toEqual(publicUser(user));
    expect(second.user).toEqual(publicUser(user));
    expect(user.currentDeviceId).toBe('iphone-b');
    expect(user.tokenVersion).toBe(firstVersion + 1);
    expect(first.accessToken).toBe('access-token');
  });

  it('accepts refresh only for the current device and token version', async () => {
    const user = await makeUser({
      currentDeviceId: 'iphone-a',
      tokenVersion: 4,
    });
    const { service, jwt } = makeService(user);
    jwt.verifyAsync.mockResolvedValue({
      sub: user.id,
      type: 'refresh',
      deviceId: 'iphone-a',
      tokenVersion: 4,
    });

    const session = await service.refresh({
      refreshToken: 'refresh-token',
      deviceId: 'iphone-a',
    });
    expect(session.refreshToken).toBe('refresh-token');

    await expect(
      service.refresh({ refreshToken: 'refresh-token', deviceId: 'iphone-b' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);

    user.tokenVersion = 5;
    await expect(
      service.refresh({ refreshToken: 'refresh-token', deviceId: 'iphone-a' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('requires the current password and returns a fresh session after changing it', async () => {
    const user = await makeUser({
      passwordHash: await bcrypt.hash('OldPassword1', 4),
      currentDeviceId: 'iphone-a',
      tokenVersion: 2,
    });
    const { service } = makeService(user);

    await expect(
      service.changePassword(user.id, {
        currentPassword: 'wrong-password',
        newPassword: 'NewPassword2',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    const oldVersion = user.tokenVersion;
    const session = await service.changePassword(user.id, {
      currentPassword: 'OldPassword1',
      newPassword: 'NewPassword2',
    });
    expect(user.tokenVersion).toBe(oldVersion + 1);
    expect(await bcrypt.compare('NewPassword2', user.passwordHash)).toBe(true);
    expect(session.accessToken).toBe('access-token');
    expect(session.user.email).toBe(user.email);
  });
});
