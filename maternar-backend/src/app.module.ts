import { Module } from '@nestjs/common';

import { ConfigModule } from '@nestjs/config';
import { DatabaseModule } from './database/database.module';
import { UserModule } from './users/user.module';
import { AuthModule } from './auth/auth.module';
import { ViacepModule } from './integrations/viacep/viacep.module';
import { PregnancyModule } from './pregnancies/pregnancy.module';
import { QuestionnaireModule } from './questionnaires/questionnaire.module';
import { RabbitmqModule } from './integrations/rabbitmq/rabbitmq.module';
import { ClassificationModule } from './classification/classification.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    ViacepModule,
    UserModule,
    AuthModule,
    PregnancyModule,
    QuestionnaireModule,
    RabbitmqModule,
    ClassificationModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}
