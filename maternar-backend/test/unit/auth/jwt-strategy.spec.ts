import { ConfigService } from '@nestjs/config';
import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import { JwtStrategy } from '../../../src/auth/http/strategies/jwt-strategy';
import { AuthenticatedUserPayload } from '../../../src/auth/domain/auth.types';

describe('JwtStrategy', () => {
  let strategy: JwtStrategy;
  let configServiceMock: DeepMockProxy<ConfigService>;

  beforeEach(() => {
    configServiceMock = mockDeep<ConfigService>();
    configServiceMock.getOrThrow.mockReturnValue('test-secret-key');
    strategy = new JwtStrategy(configServiceMock);
  });

  describe('validate()', () => {
    it('should return the user payload exactly as provided', () => {
      // Arrange
      const mockPayload: AuthenticatedUserPayload = {
        sub: 'user-123',
        email: 'test@example.com',
        name: 'Maria',
        iat: 123456789,
        exp: 987654321,
      };

      // Act
      const result = strategy.validate(mockPayload);

      // Assert
      expect(result).toEqual(mockPayload);
    });
  });
});
