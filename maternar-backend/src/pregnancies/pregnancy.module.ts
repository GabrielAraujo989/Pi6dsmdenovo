import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { PregnancyService } from './application/pregnancy.service';
import { PregnancyController } from './http/pregnancy.controller';

@Module({
  imports: [DatabaseModule],
  controllers: [PregnancyController],
  providers: [PregnancyService],
  exports: [PregnancyService],
})
export class PregnancyModule {}
