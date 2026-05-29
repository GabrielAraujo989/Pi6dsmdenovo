import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsNumber,
  Max,
  Min,
} from 'class-validator';

export class CreateQuestionnaireDto {
  @IsNotEmpty()
  @IsNumber()
  @Min(30)
  @Max(250)
  currentWeight: number;

  @IsNotEmpty()
  @IsInt()
  @Min(0)
  currentAppointments: number;

  @IsNotEmpty()
  @IsBoolean()
  hadNewComplications: boolean;

  @IsNotEmpty()
  @IsInt()
  @Min(0)
  @Max(1)
  antiHivFlag: number;
}
