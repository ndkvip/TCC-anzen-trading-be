import { ConflictException, NotFoundException } from '@nestjs/common';
import { UsersService } from './users.service';
import { AccountTier, LearningTier, User, UserRole } from './user.entity';

function makeUser(overrides: Partial<User> = {}): User {
  return {
    id: 'user-1',
    email: 'student@example.com',
    name: 'Học viên',
    passwordHash: 'hash',
    role: UserRole.STUDENT,
    accountTier: AccountTier.STANDARD,
    learningTier: LearningTier.BASIC,
    emailVerified: true,
    verificationOtpHash: null,
    verificationOtpExpiresAt: null,
    verificationOtpLastSentAt: null,
    verificationOtpAttempts: 0,
    isActive: true,
    currentDeviceId: 'iphone-a',
    tokenVersion: 3,
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

describe('UsersService account administration', () => {
  it('creates a verified student and maps VIP 2 to advanced learning access', async () => {
    const saved = makeUser({
      accountTier: AccountTier.VIP2,
      learningTier: LearningTier.ADVANCED,
    });
    const repository = {
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((value: Partial<User>) => ({ ...saved, ...value })),
      save: jest.fn().mockResolvedValue(saved),
    };
    const service = new UsersService(
      repository as never,
      {
        get: jest.fn(),
      } as never,
    );

    const result = await service.create({
      name: '  Người học  ',
      email: ' STUDENT@example.com ',
      password: 'password123',
      accountTier: AccountTier.VIP2,
    });

    expect(repository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        email: 'student@example.com',
        name: 'Người học',
        role: UserRole.STUDENT,
        accountTier: AccountTier.VIP2,
        learningTier: LearningTier.ADVANCED,
        emailVerified: true,
      }),
    );
    expect(result.role).toBe(UserRole.STUDENT);
    expect(result.accountTier).toBe(AccountTier.VIP2);
  });

  it('never accepts an admin role from the create-user payload', async () => {
    const saved = makeUser();
    const repository = {
      findOne: jest.fn().mockResolvedValue(null),
      create: jest.fn((value: Partial<User>) => ({ ...saved, ...value })),
      save: jest.fn().mockImplementation(async (value: User) => value),
    };
    const service = new UsersService(
      repository as never,
      {
        get: jest.fn(),
      } as never,
    );

    const result = await service.create({
      name: 'Người học',
      email: 'student@example.com',
      password: 'password123',
      role: UserRole.ADMIN,
    } as never);

    expect(result.role).toBe(UserRole.STUDENT);
    expect(repository.create).toHaveBeenCalledWith(
      expect.objectContaining({ role: UserRole.STUDENT }),
    );
  });

  it('updates account tier and invalidates tokens when locking a learner', async () => {
    const user = makeUser();
    const repository = {
      findOne: jest.fn().mockResolvedValue(user),
      save: jest.fn().mockImplementation(async (value: User) => value),
    };
    const service = new UsersService(
      repository as never,
      {
        get: jest.fn(),
      } as never,
    );

    const result = await service.update(user.id, {
      accountTier: AccountTier.VIP1,
      isActive: false,
    });

    expect(user.accountTier).toBe(AccountTier.VIP1);
    expect(user.learningTier).toBe(LearningTier.BASIC);
    expect(user.isActive).toBe(false);
    expect(user.tokenVersion).toBe(4);
    expect(result.isActive).toBe(false);
  });

  it('rejects duplicate emails and unknown users', async () => {
    const existing = makeUser();
    const repository = {
      findOne: jest.fn().mockResolvedValue(existing),
      create: jest.fn(),
      save: jest.fn(),
    };
    const service = new UsersService(
      repository as never,
      {
        get: jest.fn(),
      } as never,
    );

    await expect(
      service.create({
        name: 'Người học',
        email: existing.email,
        password: 'password123',
      }),
    ).rejects.toBeInstanceOf(ConflictException);

    repository.findOne.mockResolvedValue(null);
    await expect(service.update('missing', {})).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
