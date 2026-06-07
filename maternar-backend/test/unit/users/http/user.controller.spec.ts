import { Test, TestingModule } from '@nestjs/testing';
import { DeepMockProxy, mockDeep } from 'jest-mock-extended';
import { UserController } from '../../../../src/users/http/user.controller';
import { UserService } from '../../../../src/users/application/user.service';
import { UserDto, UserProfileDto } from '../../../../src/users/http/user.dto';

describe('UserController', () => {
  let controller: UserController;
  let userServiceMock: DeepMockProxy<UserService>;

  beforeEach(async () => {
    userServiceMock = mockDeep<UserService>();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [UserController],
      providers: [{ provide: UserService, useValue: userServiceMock }],
    }).compile();

    controller = module.get<UserController>(UserController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('register()', () => {
    it('should call userService.create with the correct parameters and return the message', async () => {
      const mockDto: UserDto = {
        name: 'Carlos',
        email: 'carlos@teste.com',
        password: '123',
        zipCode: '14400-000',
        birthDate: new Date('1995-01-01'),
        raceColor: 4,
        educationLevel: 3,
      };

      userServiceMock.create.mockResolvedValue({
        message: 'User created successfully',
      });

      const result = await controller.register(mockDto);

      expect(userServiceMock.create).toHaveBeenCalledWith(mockDto);
      expect(userServiceMock.create).toHaveBeenCalledTimes(1);

      expect(result).toEqual({ message: 'User created successfully' });
    });
  });

  describe('profile()', () => {
    it('should pass the userId to userService.retrieveUserProfile and return the user profile', async () => {
      const mockUserId = 'b1b2b3-id-ficticio';

      const mockProfile = {
        id: mockUserId,
        name: 'Carlos',
        email: 'carlos@teste.com',
      } as UserProfileDto;

      userServiceMock.retrieveUserProfile.mockResolvedValue(mockProfile);

      // The @CurrentUser decorator is resolved automatically in runtime HTTP.
      // In the unit test, we simply pass the string as an argument to the function.
      const result = await controller.profile(mockUserId);

      expect(userServiceMock.retrieveUserProfile).toHaveBeenCalledWith(
        mockUserId,
      );
      expect(result).toEqual(mockProfile);
    });
  });
});
