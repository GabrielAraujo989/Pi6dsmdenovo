import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { ClassificationService } from './classification.service';
import { ClassificationDto } from './classification.dto';
import { JwtAuthGuard } from '../auth/http/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/http/decorators/current-user.decorator';

@Controller('classification')
export class ClassificationController {
  constructor(private readonly classificationService: ClassificationService) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  async classify(
    @CurrentUser('sub') userId: string,
    @Body() dto: ClassificationDto,
  ) {
    return this.classificationService.classify(userId, dto);
  }
}
