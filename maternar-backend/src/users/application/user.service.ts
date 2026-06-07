import { ConflictException, HttpStatus, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { UpdateUserProfileDto, UserDto, UserProfileDto } from '../http/user.dto';
import * as bcrypt from 'bcrypt';
import { User } from '@prisma/client';
import { ApiException } from '../../common/api-exception';
import { ViaCepService } from '../../integrations/viacep/viacep.service';
import { ViaCepResponse } from '../../integrations/viacep/interfaces/IViaCepAdressProvider';

@Injectable()
export class UserService {
  constructor(
    private readonly prisma: DatabaseService,
    private readonly viaCepService: ViaCepService,
  ) {}

  async create(newUser: UserDto) {
    const userEmailAlreadyExists = await this.prisma.user.findFirst({
      where: {
        email: newUser.email,
      },
    });

    if (userEmailAlreadyExists) {
      throw new ConflictException('Email already registered');
    }

    const cleanZipCode = newUser.zipCode.replace(/\D/g, '');

    let viaCepData: ViaCepResponse | null = null;
    try {
      viaCepData = await this.viaCepService.getAddressByZipCode(cleanZipCode);
    } catch (error) {
      // Se o erro for BAD_REQUEST (CEP inválido/inexistente), repassa o erro e bloqueia o cadastro.
      // Se for SERVICE_UNAVAILABLE (API fora do ar ou timeout), engole o erro e deixa o cadastro seguir.
      if (
        error instanceof ApiException &&
        // eslint-disable-next-line @typescript-eslint/no-unsafe-enum-comparison
        error.getStatus() === HttpStatus.BAD_REQUEST
      ) {
        throw error;
      }
    }

    const salt = await bcrypt.genSalt();
    const hashedPassword = await bcrypt.hash(newUser.password, salt);

    await this.prisma.user.create({
      data: {
        name: newUser.name,
        email: newUser.email,
        password: hashedPassword,
        zipCode: cleanZipCode,
        birthDate: new Date(newUser.birthDate),
        educationLevel: newUser.educationLevel,
        raceColor: newUser.raceColor,
        phone: newUser.phone,
        height: newUser.height,
        preGestationalWeight: newUser.preGestationalWeight,
        previousPregnancies: newUser.previousPregnancies,
        hadPreviousComplication: newUser.hadPreviousComplication,
        // Prisma Nested Write: O Prisma cria a localização e o usuário na MESMA transação no banco de dados.
        // Feito exclusivamente para não ocorrer falhas parciais.
        ...(viaCepData && {
          location: {
            create: {
              city: viaCepData.localidade,
              uf: viaCepData.uf,
              region: viaCepData.regiao,
              ibgeCode: viaCepData.ibge,
            },
          },
        }),
      },
    });

    return { message: 'User created successfully' };
  }

  async findUserByEmail(email: string): Promise<User | null> {
    return await this.prisma.user.findUnique({
      where: {
        email,
      },
    });
  }

  async updateProfile(userId: string, dto: UpdateUserProfileDto): Promise<UserProfileDto> {
    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.phone !== undefined && { phone: dto.phone }),
        ...(dto.height !== undefined && { height: dto.height }),
        ...(dto.preGestationalWeight !== undefined && {
          preGestationalWeight: dto.preGestationalWeight,
        }),
        ...(dto.previousPregnancies !== undefined && {
          previousPregnancies: dto.previousPregnancies,
        }),
        ...(dto.hadPreviousComplication !== undefined && {
          hadPreviousComplication: dto.hadPreviousComplication,
        }),
      },
    });

    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { password: _, ...user } = updated;
    return {
      ...user,
      height: user.height ? Number(user.height) : null,
      preGestationalWeight: user.preGestationalWeight
        ? Number(user.preGestationalWeight)
        : null,
    };
  }

  async retrieveUserProfile(userId: string): Promise<UserProfileDto> {
    const foundUser = await this.prisma.user.findUnique({
      where: {
        id: userId,
      },
    });

    if (!foundUser) {
      throw new ApiException(
        HttpStatus.UNAUTHORIZED,
        'UNAUTHORIZED',
        'Autenticação inválida ou ausente.',
      );
    }

    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { password: _, ...user } = foundUser;

    return {
      ...user,
      height: user.height ? Number(user.height) : null,
      preGestationalWeight: user.preGestationalWeight
        ? Number(user.preGestationalWeight)
        : null,
    };
  }
}
