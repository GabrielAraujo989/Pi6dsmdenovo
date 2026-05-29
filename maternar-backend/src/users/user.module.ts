import { Module } from '@nestjs/common';
import { UserController } from './http/user.controller';
import { UserService } from './application/user.service';
import { DatabaseModule } from '../database/database.module';
import { ViacepModule } from '../integrations/viacep/viacep.module';

@Module({
  imports: [DatabaseModule, ViacepModule],
  controllers: [UserController],
  providers: [UserService],
  exports: [UserService],
})
export class UserModule {}
