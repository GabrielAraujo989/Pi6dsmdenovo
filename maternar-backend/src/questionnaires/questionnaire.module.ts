import { Module } from '@nestjs/common';
import { PregnancyModule } from '../pregnancies/pregnancy.module';
import { DatabaseModule } from '../database/database.module';
import { QuestionnaireService } from './application/questionnaire.service';
import { QuestionnaireController } from './http/questionnaire.controller';

@Module({
  imports: [PregnancyModule, DatabaseModule],
  controllers: [QuestionnaireController],
  providers: [QuestionnaireService],
})
export class QuestionnaireModule {}
