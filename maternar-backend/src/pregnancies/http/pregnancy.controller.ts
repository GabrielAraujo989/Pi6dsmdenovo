import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { PregnancyService } from '../application/pregnancy.service';
import { CreatePregnancyDto } from './pregnancy.dto';
import { CurrentUser } from '../../auth/http/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../auth/http/guards/jwt-auth.guard';

@Controller('pregnancy')
export class PregnancyController {
  constructor(private readonly pregnancyService: PregnancyService) {}

  @Post('create')
  @UseGuards(JwtAuthGuard)
  async create(
    @CurrentUser('sub') userId: string,
    @Body() body: CreatePregnancyDto,
  ) {
    return this.pregnancyService.create(userId, body);
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  async findAll(@CurrentUser('sub') userId: string) {
    return this.pregnancyService.findAllByUser(userId);
  }
}
