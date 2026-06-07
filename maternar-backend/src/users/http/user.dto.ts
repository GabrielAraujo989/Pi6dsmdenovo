import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
  MinLength,
} from 'class-validator';

export class UserDto {
  @IsOptional()
  @IsString()
  id?: string;

  @IsNotEmpty()
  @IsString()
  name: string;

  @IsNotEmpty()
  @IsEmail()
  email: string;

  @IsNotEmpty()
  @IsString()
  @MinLength(6)
  password: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsNumber()
  height?: number;

  @IsOptional()
  @IsNumber()
  preGestationalWeight?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  previousPregnancies?: number;

  @IsOptional()
  @IsBoolean()
  hadPreviousComplication?: boolean;

  @IsNotEmpty()
  @IsString()
  zipCode: string;

  @IsNotEmpty()
  @IsDateString()
  birthDate: Date;

  @IsNotEmpty()
  @Min(1)
  @Max(5)
  raceColor: number;

  @IsNotEmpty()
  @Min(1)
  @Max(5)
  educationLevel: number;
}

export class UpdateUserProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(3)
  name?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsNumber()
  @Min(1.0)
  @Max(2.5)
  height?: number;

  @IsOptional()
  @IsNumber()
  @Min(30)
  @Max(250)
  preGestationalWeight?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  previousPregnancies?: number;

  @IsOptional()
  @IsBoolean()
  hadPreviousComplication?: boolean;
}

export interface UserProfileDto {
  id: string;
  name: string;
  email: string;
  zipCode: string;
  phone?: string | null;
  height?: number | null;
  preGestationalWeight?: number | null;
  previousPregnancies?: number | null;
  hadPreviousComplication?: boolean | null;
  educationLevel: number;
  raceColor: number;
  birthDate: Date;
}
