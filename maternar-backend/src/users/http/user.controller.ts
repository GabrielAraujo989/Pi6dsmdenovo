import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { UserDto } from './user.dto';
import { UserService } from '../application/user.service';
import { CurrentUser } from '../../auth/http/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../auth/http/guards/jwt-auth.guard';

@Controller('users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post('register')
  async register(@Body() body: UserDto) {
    return await this.userService.create(body);
  }

  @Get('profile')
  @UseGuards(JwtAuthGuard)
  async profile(@CurrentUser('sub') userId: string) {
    return await this.userService.retrieveUserProfile(userId);
  }
}
