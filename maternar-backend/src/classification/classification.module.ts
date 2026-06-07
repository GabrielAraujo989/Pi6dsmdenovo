import { Module } from '@nestjs/common';
import { ClassificationController } from './classification.controller';
import { ClassificationService } from './classification.service';
import { DatabaseModule } from '../database/database.module';
import { RabbitmqModule } from '../integrations/rabbitmq/rabbitmq.module';

@Module({
  imports: [DatabaseModule, RabbitmqModule],
  controllers: [ClassificationController],
  providers: [ClassificationService],
})
export class ClassificationModule {}
