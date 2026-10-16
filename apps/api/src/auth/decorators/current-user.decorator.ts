import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { Request } from 'express';
import type { AuthRequestUser } from '../auth.types';

export const CurrentUser = createParamDecorator(
  (_: unknown, context: ExecutionContext) => {
    return (
      context.switchToHttp().getRequest<Request>() as Request & {
        user: AuthRequestUser;
      }
    ).user;
  },
);
