import { AccountTier, LearningTier, UserRole } from '../users/user.entity';

export interface JwtPayload {
  sub: string;
  role: UserRole;
  accountTier: AccountTier;
  learningTier: LearningTier;
  deviceId: string;
  tokenVersion: number;
  type: 'access' | 'refresh';
}

export interface AuthRequestUser extends JwtPayload {
  email: string;
  name: string;
}
