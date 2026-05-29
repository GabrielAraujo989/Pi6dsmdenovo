import { ExecutionContext, HttpStatus } from '@nestjs/common';
import { TokenExpiredError } from 'jsonwebtoken';
import { JwtAuthGuard } from '../../../../src/auth/http/guards/jwt-auth.guard';
import { ApiException } from '../../../../src/common/api-exception';
import { AuthenticatedUserPayload } from '../../../../src/auth/domain/auth.types';

describe('JwtAuthGuard', () => {
  let guard: JwtAuthGuard;
  let mockExecutionContext: ExecutionContext;

  beforeEach(() => {
    guard = new JwtAuthGuard();
    mockExecutionContext = {} as ExecutionContext;
  });

  it('should be defined', () => {
    expect(guard).toBeDefined();
  });

  describe('handleRequest()', () => {
    it('should throw an ApiException with TOKEN_EXPIRED if info is a TokenExpiredError instance', () => {
      // Arrange
      const info = new TokenExpiredError('jwt expired', new Date());

      // Act & Assert
      expect(() =>
        guard.handleRequest(null, null, info, mockExecutionContext),
      ).toThrow(
        new ApiException(
          HttpStatus.UNAUTHORIZED,
          'TOKEN_EXPIRED',
          'Sua sessão expirou. Faça login novamente.',
        ),
      );
    });

    it('should throw an ApiException with TOKEN_EXPIRED if info is a generic Error named TokenExpiredError', () => {
      // Arrange
      const info = new Error('jwt expired');
      info.name = 'TokenExpiredError';

      // Act & Assert
      expect(() =>
        guard.handleRequest(null, null, info, mockExecutionContext),
      ).toThrow(
        new ApiException(
          HttpStatus.UNAUTHORIZED,
          'TOKEN_EXPIRED',
          'Sua sessão expirou. Faça login novamente.',
        ),
      );
    });

    it('should throw an ApiException with UNAUTHORIZED if an error (err) is passed', () => {
      // Arrange
      const err = new Error('Some internal passport error');

      // Act & Assert
      expect(() =>
        guard.handleRequest(err, null, null, mockExecutionContext),
      ).toThrow(
        new ApiException(
          HttpStatus.UNAUTHORIZED,
          'UNAUTHORIZED',
          'Autenticação inválida ou ausente.',
        ),
      );
    });

    it('should throw an ApiException with UNAUTHORIZED if no user is provided', () => {
      // Act & Assert
      expect(() =>
        guard.handleRequest(null, null, null, mockExecutionContext),
      ).toThrow(
        new ApiException(
          HttpStatus.UNAUTHORIZED,
          'UNAUTHORIZED',
          'Autenticação inválida ou ausente.',
        ),
      );
    });

    it('should return the user object if no errors occurred and the user is present (Happy Path)', () => {
      // Arrange
      const mockUser: AuthenticatedUserPayload = {
        sub: 'user-123',
        email: 'test@example.com',
        name: 'Maria',
        iat: 123456789,
        exp: 987654321,
      };

      // Act
      const result = guard.handleRequest(
        null,
        mockUser,
        null,
        mockExecutionContext,
      );

      // Assert
      expect(result).toEqual(mockUser);
    });
  });
});
