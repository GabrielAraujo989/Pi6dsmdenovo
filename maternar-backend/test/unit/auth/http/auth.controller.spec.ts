import { Test, TestingModule } from '@nestjs/testing';
import { mockDeep, DeepMockProxy } from 'jest-mock-extended';

import { AuthController } from '../../../../src/auth/http/auth.controller';
import { AuthService } from '../../../../src/auth/application/auth.service';
import { LoginLocalDto } from '../../../../src/auth/http/auth.dto';

describe('AuthController', () => {
  let controller: AuthController;
  let authServiceMock: DeepMockProxy<AuthService>;

  beforeEach(async () => {
    authServiceMock = mockDeep<AuthService>();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthService, useValue: authServiceMock }],
    }).compile();

    controller = module.get<AuthController>(AuthController);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('signIn()', () => {
    it('should call authService.signIn with correct dto and return the access token (Happy Path)', async () => {
      // Arrange
      const mockLoginDto: LoginLocalDto = {
        email: 'test@example.com',
        password: 'password123',
      };
      const mockTokenResponse = { access_token: 'mocked-jwt', expiresIn: 60 };

      authServiceMock.signIn.mockResolvedValue(mockTokenResponse);

      // Act
      const result = await controller.signIn(mockLoginDto);

      // Assert
      expect(authServiceMock.signIn).toHaveBeenCalledWith(mockLoginDto);
      expect(authServiceMock.signIn).toHaveBeenCalledTimes(1);
      expect(result).toEqual(mockTokenResponse);
    });
  });
});
