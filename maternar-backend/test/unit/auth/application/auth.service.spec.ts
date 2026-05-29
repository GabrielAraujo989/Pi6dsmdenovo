import { DeepMockProxy, mockDeep } from 'jest-mock-extended';
import { AuthService } from '../../../../src/auth/application/auth.service';
import { UserService } from '../../../../src/users/application/user.service';
import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import { ApiException } from '../../../../src/common/api-exception';
import { HttpStatus } from '@nestjs/common';
import { LoginLocalDto } from '../../../../src/auth/http/auth.dto';
import { User } from '@prisma/client';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
  let service: AuthService;
  let userServiceMock: DeepMockProxy<UserService>;
  let jwtServiceMock: DeepMockProxy<JwtService>;

  beforeEach(async () => {
    userServiceMock = mockDeep<UserService>();
    jwtServiceMock = mockDeep<JwtService>();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UserService, useValue: userServiceMock },
        { provide: JwtService, useValue: jwtServiceMock },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('signIn()', () => {
    const signInUserDto: LoginLocalDto = {
      email: 'test@example.com',
      password: 'password12',
    };

    it('should throw ApiException with UNAUTHORIZED if user is not found', async () => {
      // Arrange
      userServiceMock.findUserByEmail.mockResolvedValue(null);

      // Act & Assert
      await expect(service.signIn(signInUserDto)).rejects.toThrow(
        new ApiException(
          HttpStatus.UNAUTHORIZED,
          'INVALID_CREDENTIALS',
          'Credenciais inválidas.',
        ),
      );
      expect(userServiceMock.findUserByEmail).toHaveBeenCalledWith(
        signInUserDto.email,
      );
      expect(jwtServiceMock.signAsync).not.toHaveBeenCalled();
    });

    it('should throw ApiException with UNAUTHORIZED if password is incorrect', async () => {
      // Arrange
      const mockUser = {
        id: 'user-id-123',
        email: 'test@example.com',
        password: 'hashedPassword',
      } as User;

      userServiceMock.findUserByEmail.mockResolvedValue(mockUser);

      const bcryptCompareSpy = jest
        .spyOn(bcrypt, 'compare')
        .mockResolvedValue(false as never);

      // Act & Assert
      await expect(service.signIn(signInUserDto)).rejects.toThrow(
        new ApiException(
          HttpStatus.UNAUTHORIZED,
          'INVALID_CREDENTIALS',
          'Credenciais inválidas.',
        ),
      );

      expect(userServiceMock.findUserByEmail).toHaveBeenCalledWith(
        signInUserDto.email,
      );
      expect(bcryptCompareSpy).toHaveBeenCalledWith(
        'password12',
        'hashedPassword',
      );
      expect(jwtServiceMock.signAsync).not.toHaveBeenCalled();

      bcryptCompareSpy.mockRestore();
    });

    it('should return the access token and expiration time if credentials are valid (Happy Path)', async () => {
      // Arrange
      const mockUser = {
        id: 'user-id-123',
        email: 'test@example.com',
        name: 'Maria',
        password: 'hashedPassword',
      } as User;

      userServiceMock.findUserByEmail.mockResolvedValue(mockUser);

      const bcryptCompareSpy = jest
        .spyOn(bcrypt, 'compare')
        .mockResolvedValue(true as never);

      jwtServiceMock.signAsync.mockResolvedValue('mocked-jwt-token');

      // Act
      const result = await service.signIn(signInUserDto);

      // Assert
      expect(bcryptCompareSpy).toHaveBeenCalledWith(
        'password12',
        'hashedPassword',
      );
      expect(jwtServiceMock.signAsync).toHaveBeenCalledWith(
        { sub: 'user-id-123', email: 'test@example.com', name: 'Maria' },
        { expiresIn: 60 },
      );
      expect(result).toEqual({
        access_token: 'mocked-jwt-token',
        expiresIn: 60,
      });

      bcryptCompareSpy.mockRestore();
    });
  });
});
