import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { UsersService } from '../../users/users.service';
import type { AuthRequestUser, JwtPayload } from '../auth.types';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly users: UsersService,
  ) {}

  async canActivate(context: ExecutionContext) {
    const request = context
      .switchToHttp()
      .getRequest<Request & { user?: AuthRequestUser }>();
    const [scheme, token] = request.headers.authorization?.split(' ') ?? [];
    if (scheme !== 'Bearer' || !token)
      throw new UnauthorizedException('Authentication required');

    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync<JwtPayload>(token, {
        secret: this.config.getOrThrow('JWT_ACCESS_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Session expired');
    }
    if (payload.type !== 'access')
      throw new UnauthorizedException('Invalid token');

    const user = await this.users.findById(payload.sub);
    if (
      !user ||
      !user.isActive ||
      !user.emailVerified ||
      user.tokenVersion !== payload.tokenVersion ||
      user.currentDeviceId !== payload.deviceId
    ) {
      throw new UnauthorizedException('Session is no longer valid');
    }
    request.user = { ...payload, email: user.email, name: user.name };
    return true;
  }
}
