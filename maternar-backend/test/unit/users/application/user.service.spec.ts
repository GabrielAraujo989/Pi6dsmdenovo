import { Test, TestingModule } from '@nestjs/testing';
import { ConflictException, HttpStatus } from '@nestjs/common';
import { mockDeep, DeepMockProxy } from 'jest-mock-extended';
import * as bcrypt from 'bcrypt';
import { User } from '@prisma/client';

import { UserService } from '../../../../src/users/application/user.service';
import { DatabaseService } from '../../../../src/database/database.service';
import { ViaCepService } from '../../../../src/integrations/viacep/viacep.service';
import { UserDto } from '../../../../src/users/http/user.dto';
import { ApiException } from '../../../../src/common/api-exception';

describe('UserService', () => {
  let service: UserService;
  let prismaMock: DeepMockProxy<DatabaseService>;
  let viaCepMock: DeepMockProxy<ViaCepService>;

  beforeEach(async () => {
    prismaMock = mockDeep<DatabaseService>();
    viaCepMock = mockDeep<ViaCepService>();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UserService,
        { provide: DatabaseService, useValue: prismaMock },
        { provide: ViaCepService, useValue: viaCepMock },
      ],
    }).compile();

    service = module.get<UserService>(UserService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    const mockUserDto: UserDto = {
      name: 'Maria Silva',
      email: 'maria@example.com',
      password: 'password123',
      zipCode: '12345-678',
      birthDate: new Date('1990-01-01'),
      raceColor: 4,
      educationLevel: 3,
    };

    it('should throw a ConflictException if the email is already registered', async () => {
      // Arrange
      prismaMock.user.findFirst.mockResolvedValue({ id: 'any-id' } as User);

      // Act & Assert
      await expect(service.create(mockUserDto)).rejects.toThrow(
        new ConflictException('Email already registered'),
      );
      expect(prismaMock.user.findFirst).toHaveBeenCalledWith({
        where: { email: mockUserDto.email },
      });
      expect(prismaMock.user.create).not.toHaveBeenCalled();
    });

    it('should rethrow an ApiException with BAD_REQUEST status if the zip code is invalid', async () => {
      // Arrange
      prismaMock.user.findFirst.mockResolvedValue(null);

      const apiException = new ApiException(
        HttpStatus.BAD_REQUEST,
        'BAD_REQUEST',
        'Invalid Zip Code',
      );
      viaCepMock.getAddressByZipCode.mockRejectedValue(apiException);

      // Act & Assert
      await expect(service.create(mockUserDto)).rejects.toThrow(apiException);
      expect(viaCepMock.getAddressByZipCode).toHaveBeenCalledWith('12345678');
      expect(prismaMock.user.create).not.toHaveBeenCalled();
    });

    it('should successfully create a user WITH location data if the ViaCEP API returns valid address data (Happy Path)', async () => {
      // Arrange
      prismaMock.user.findFirst.mockResolvedValue(null);
      viaCepMock.getAddressByZipCode.mockResolvedValue({
        cep: '12345-678',
        logradouro: 'Rua Falsa',
        complemento: '',
        bairro: 'Centro',
        localidade: 'São Paulo',
        uf: 'SP',
        estado: 'São Paulo',
        ibge: '3550308',
        gia: '1004',
        ddd: '11',
        siafi: '7107',
        regiao: 'Sudeste',
      });

      const genSaltSpy = jest
        .spyOn(bcrypt, 'genSalt')
        .mockResolvedValue('mockedSalt' as never);
      const hashSpy = jest
        .spyOn(bcrypt, 'hash')
        .mockResolvedValue('mockedHash' as never);

      // Act
      const result = await service.create(mockUserDto);

      // Assert
      expect(result).toEqual({ message: 'User created successfully' });
      expect(prismaMock.user.create).toHaveBeenCalledWith({
        data: {
          name: mockUserDto.name,
          email: mockUserDto.email,
          password: 'mockedHash',
          zipCode: '12345678',
          birthDate: new Date(mockUserDto.birthDate),
          educationLevel: 3,
          raceColor: 4,
          location: {
            create: {
              city: 'São Paulo',
              uf: 'SP',
              region: 'Sudeste',
              ibgeCode: '3550308',
            },
          },
        },
      });

      genSaltSpy.mockRestore();
      hashSpy.mockRestore();
    });

    it('should successfully create a user WITHOUT location data if the ViaCEP API is unavailable or times out', async () => {
      // Arrange
      prismaMock.user.findFirst.mockResolvedValue(null);

      // Simulating Scenario B from the business rules (503 Service Unavailable)
      const apiException = new ApiException(
        HttpStatus.SERVICE_UNAVAILABLE,
        'SERVICE_UNAVAILABLE',
        'ViaCEP API is offline',
      );
      viaCepMock.getAddressByZipCode.mockRejectedValue(apiException);

      const genSaltSpy = jest
        .spyOn(bcrypt, 'genSalt')
        .mockResolvedValue('mockedSalt' as never);
      const hashSpy = jest
        .spyOn(bcrypt, 'hash')
        .mockResolvedValue('mockedHash' as never);

      // Act
      const result = await service.create(mockUserDto);

      // Assert
      expect(result).toEqual({ message: 'User created successfully' });
      // Verify if create was called WITHOUT the location prop (Nested Write does not occur)
      expect(prismaMock.user.create).toHaveBeenCalledWith({
        data: {
          name: mockUserDto.name,
          email: mockUserDto.email,
          password: 'mockedHash',
          zipCode: '12345678',
          birthDate: new Date(mockUserDto.birthDate),
          educationLevel: 3,
          raceColor: 4,
        },
      });

      genSaltSpy.mockRestore();
      hashSpy.mockRestore();
    });
  });

  describe('findUserByEmail', () => {
    it('should return a user object if the provided email is found in the database', async () => {
      // Arrange
      const mockUser = {
        id: 'user-id-123',
        email: 'test@example.com',
      } as User;
      prismaMock.user.findUnique.mockResolvedValue(mockUser);

      // Act
      const result = await service.findUserByEmail('test@example.com');

      // Assert
      expect(prismaMock.user.findUnique).toHaveBeenCalledWith({
        where: { email: 'test@example.com' },
      });
      expect(result).toEqual(mockUser);
    });

    it('should return null if the provided email is not found in the database', async () => {
      // Arrange
      prismaMock.user.findUnique.mockResolvedValue(null);

      // Act
      const result = await service.findUserByEmail('notfound@example.com');

      // Assert
      expect(prismaMock.user.findUnique).toHaveBeenCalledWith({
        where: { email: 'notfound@example.com' },
      });
      expect(result).toBeNull();
    });
  });

  describe('retrieveUserProfile', () => {
    it('should throw an ApiException with UNAUTHORIZED status if the user is not found by ID', async () => {
      // Arrange
      prismaMock.user.findUnique.mockResolvedValue(null);

      // Act & Assert
      await expect(service.retrieveUserProfile('invalid-id')).rejects.toThrow(
        new ApiException(
          HttpStatus.UNAUTHORIZED,
          'UNAUTHORIZED',
          'Invalid or missing authentication.',
        ),
      );
      expect(prismaMock.user.findUnique).toHaveBeenCalledWith({
        where: { id: 'invalid-id' },
      });
    });

    it('should return the user profile without the password field if the user is found', async () => {
      // Arrange
      const mockDate = new Date('1990-01-01');
      const mockUser = {
        id: 'user-id-123',
        name: 'Ana Souza',
        email: 'ana@example.com',
        password: 'hashed-password-123',
        phone: null,
        height: null,
        preGestationalWeight: null,
        previousPregnancies: null,
        educationLevel: 3,
        raceColor: 4,
        zipCode: '12345678',
        hadPreviousComplication: null,
        birthDate: mockDate,
        createdAt: mockDate,
        updatedAt: mockDate,
      } as unknown as User;

      prismaMock.user.findUnique.mockResolvedValue(mockUser);

      // Act
      const result = await service.retrieveUserProfile('user-id-123');

      // Assert
      expect(prismaMock.user.findUnique).toHaveBeenCalledWith({
        where: { id: 'user-id-123' },
      });

      // Ensure the password is not being returned in the result
      expect(result).not.toHaveProperty('password');
      expect(result).toEqual({
        id: 'user-id-123',
        name: 'Ana Souza',
        email: 'ana@example.com',
        phone: null,
        height: null,
        preGestationalWeight: null,
        previousPregnancies: null,
        educationLevel: 3,
        raceColor: 4,
        zipCode: '12345678',
        hadPreviousComplication: null,
        birthDate: mockDate,
        createdAt: mockDate,
        updatedAt: mockDate,
      });
    });
  });
});
