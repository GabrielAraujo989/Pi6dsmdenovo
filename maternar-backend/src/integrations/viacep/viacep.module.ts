import { Module } from '@nestjs/common';
import { ViaCepService } from './viacep.service';

@Module({
  providers: [ViaCepService],
  exports: [ViaCepService],
})
export class ViacepModule {}
