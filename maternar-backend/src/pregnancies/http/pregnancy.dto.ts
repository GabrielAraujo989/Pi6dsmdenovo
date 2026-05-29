import { PregnancyStatus } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class CreatePregnancyDto {
  @IsOptional()
  @IsDateString()
  dumStartDate?: string;
}

export class UpdatePregnancyDto {
  @IsOptional()
  @IsEnum(PregnancyStatus)
  status?: PregnancyStatus;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(2)
  clusterId?: number;

  @IsOptional()
  @IsString()
  clusterName?: string;
}
