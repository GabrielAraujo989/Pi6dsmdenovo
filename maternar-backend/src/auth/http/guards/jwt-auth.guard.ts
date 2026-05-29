import { ExecutionContext, HttpStatus, Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { TokenExpiredError } from 'jsonwebtoken';
import { ApiException } from '../../../common/api-exception';
import { AuthenticatedUserPayload } from '../../domain/auth.types';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  handleRequest<TUser = AuthenticatedUserPayload>(
    err: any,
    user: any,
    info: any,
    _context: ExecutionContext,
    _status?: any,
  ): TUser {
    const isTokenExpired =
      info instanceof TokenExpiredError ||
      (info instanceof Error && info.name === 'TokenExpiredError');

    if (isTokenExpired) {
      throw new ApiException(
        HttpStatus.UNAUTHORIZED,
        'TOKEN_EXPIRED',
        'Sua sessão expirou. Faça login novamente.',
      );
    }

    if (err || !user) {
      throw new ApiException(
        HttpStatus.UNAUTHORIZED,
        'UNAUTHORIZED',
        'Autenticação inválida ou ausente.',
      );
    }

    return user as TUser;
  }
}
