import { IsInt, IsNumber, IsOptional, Max, Min } from 'class-validator';

export class ClassificationDto {
  @IsNumber()
  @Min(30)
  @Max(250)
  nu_peso: number;

  @IsNumber()
  @Min(0.5)
  @Max(2.5)
  nu_altura: number;

  @IsNumber()
  @Min(10)
  @Max(60)
  nu_imc_pre_gestacional: number;

  @IsInt()
  @Min(1)
  @Max(5)
  raca_cor: number;

  @IsInt()
  @Min(1)
  @Max(5)
  escolaridade: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(1)
  flag_anti_hiv?: number;
}
