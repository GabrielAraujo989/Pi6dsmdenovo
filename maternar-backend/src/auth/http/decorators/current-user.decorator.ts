import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import {
  AuthenticatedRequest,
  AuthenticatedUserPayload,
} from '../../domain/auth.types';

type AuthenticatedUserProperty = keyof AuthenticatedUserPayload;

export const CurrentUser = createParamDecorator(
  (data: AuthenticatedUserProperty | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest<AuthenticatedRequest>();
    const user = request.user;

    return data ? user[data] : request.user;
  },
);
