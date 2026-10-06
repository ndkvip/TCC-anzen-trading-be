import {
  ConflictException,
  Injectable,
  NotFoundException,
  OnApplicationBootstrap,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import * as bcrypt from 'bcryptjs';
import { Repository } from 'typeorm';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { AccountTier, LearningTier, User, UserRole } from './user.entity';

@Injectable()
export class UsersService implements OnApplicationBootstrap {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    private readonly config: ConfigService,
  ) {}

  async onApplicationBootstrap() {
    const email = this.config.get<string>('ADMIN_EMAIL')?.trim().toLowerCase();
    const password = this.config.get<string>('ADMIN_PASSWORD');
    if (!email || !password) return;
    const existing = await this.findByEmail(email);
    if (existing) {
      let changed = false;
      if (!existing.emailVerified) {
        existing.emailVerified = true;
        changed = true;
      }
      if (!existing.accountTier) {
        existing.accountTier = AccountTier.VIP2;
        changed = true;
      }
      if (
        existing.role === UserRole.ADMIN &&
        existing.learningTier !== LearningTier.ADVANCED
      ) {
        existing.learningTier = LearningTier.ADVANCED;
        changed = true;
      }
      if (changed) await this.users.save(existing);
      return;
    }

    await this.users.save(
      this.users.create({
        email,
        name: this.config.get<string>('ADMIN_NAME') || 'ANZEN TRADING Admin',
        passwordHash: await bcrypt.hash(password, 12),
        role: UserRole.ADMIN,
        accountTier: AccountTier.VIP2,
        learningTier: LearningTier.ADVANCED,
        emailVerified: true,
      }),
    );
  }

  findByEmail(email: string) {
    return this.users.findOne({ where: { email: email.trim().toLowerCase() } });
  }

  findById(id: string) {
    return this.users.findOne({ where: { id } });
  }

  async list() {
    const rows = await this.users.find({ order: { createdAt: 'DESC' } });
    return rows.map((user) => this.toPublic(user));
  }

  async create(dto: CreateUserDto) {
    const email = dto.email.trim().toLowerCase();
    if (await this.findByEmail(email))
      throw new ConflictException('Email đã được sử dụng');
    const user = await this.users.save(
      this.users.create({
        email,
        name: dto.name.trim(),
        passwordHash: await bcrypt.hash(dto.password, 12),
        // The admin panel creates learners only; admin accounts are provisioned
        // from the server environment and cannot be created through this API.
        role: UserRole.STUDENT,
        accountTier: dto.accountTier ?? AccountTier.STANDARD,
        learningTier:
          dto.accountTier === AccountTier.VIP2
            ? LearningTier.ADVANCED
            : LearningTier.BASIC,
        emailVerified: true,
      }),
    );
    return this.toPublic(user);
  }

  async update(id: string, dto: UpdateUserDto) {
    const user = await this.findById(id);
    if (!user) throw new NotFoundException('Không tìm thấy tài khoản');
    if (dto.name !== undefined) user.name = dto.name.trim();
    if (dto.accountTier !== undefined) {
      user.accountTier = dto.accountTier;
      user.learningTier =
        dto.accountTier === AccountTier.VIP2
          ? LearningTier.ADVANCED
          : LearningTier.BASIC;
    }
    if (dto.isActive !== undefined) {
      user.isActive = dto.isActive;
      if (!dto.isActive) user.tokenVersion += 1;
    }
    return this.toPublic(await this.users.save(user));
  }

  toPublic(user: User) {
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      accountTier: user.accountTier,
      learningTier: user.learningTier,
      emailVerified: user.emailVerified,
      isActive: user.isActive,
      createdAt: user.createdAt,
    };
  }
}
