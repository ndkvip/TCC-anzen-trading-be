import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum UserRole {
  ADMIN = 'ADMIN',
  STUDENT = 'STUDENT',
}

export enum LearningTier {
  BASIC = 'BASIC',
  ADVANCED = 'ADVANCED',
}

export enum AccountTier {
  STANDARD = 'STANDARD',
  VIP1 = 'VIP1',
  VIP2 = 'VIP2',
}

@Entity({ name: 'users' })
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ unique: true })
  email!: string;

  @Column({ name: 'password_hash' })
  passwordHash!: string;

  @Column()
  name!: string;

  @Column({ type: 'enum', enum: UserRole, default: UserRole.STUDENT })
  role!: UserRole;

  @Column({
    name: 'account_tier',
    type: 'enum',
    enum: AccountTier,
    default: AccountTier.STANDARD,
  })
  accountTier!: AccountTier;

  /** Legacy field kept while existing learning-content permissions migrate. */
  @Column({
    name: 'learning_tier',
    type: 'enum',
    enum: LearningTier,
    default: LearningTier.BASIC,
  })
  learningTier!: LearningTier;

  @Column({ name: 'email_verified', default: false })
  emailVerified!: boolean;

  @Column({ name: 'verification_otp_hash', type: 'varchar', nullable: true })
  verificationOtpHash!: string | null;

  @Column({
    name: 'verification_otp_expires_at',
    type: 'timestamptz',
    nullable: true,
  })
  verificationOtpExpiresAt!: Date | null;

  @Column({
    name: 'verification_otp_last_sent_at',
    type: 'timestamptz',
    nullable: true,
  })
  verificationOtpLastSentAt!: Date | null;

  @Column({ name: 'verification_otp_attempts', default: 0 })
  verificationOtpAttempts!: number;

  @Column({ name: 'is_active', default: true })
  isActive!: boolean;

  @Column({ name: 'current_device_id', type: 'varchar', nullable: true })
  currentDeviceId!: string | null;

  @Column({ name: 'token_version', default: 0 })
  tokenVersion!: number;

  @Column({ name: 'reset_token_hash', type: 'varchar', nullable: true })
  resetTokenHash!: string | null;

  @Column({
    name: 'reset_token_expires_at',
    type: 'timestamptz',
    nullable: true,
  })
  resetTokenExpiresAt!: Date | null;

  @Column({ name: 'reset_otp_hash', type: 'varchar', nullable: true })
  resetOtpHash!: string | null;

  @Column({ name: 'reset_otp_expires_at', type: 'timestamptz', nullable: true })
  resetOtpExpiresAt!: Date | null;

  @Column({
    name: 'reset_otp_last_sent_at',
    type: 'timestamptz',
    nullable: true,
  })
  resetOtpLastSentAt!: Date | null;

  @Column({ name: 'reset_otp_attempts', default: 0 })
  resetOtpAttempts!: number;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}
