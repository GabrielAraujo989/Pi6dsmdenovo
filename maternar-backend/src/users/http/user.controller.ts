import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { UpdateUserProfileDto, UserDto } from './user.dto';
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

  @Patch('profile')
  @UseGuards(JwtAuthGuard)
  async updateProfile(
    @CurrentUser('sub') userId: string,
    @Body() body: UpdateUserProfileDto,
  ) {
    return await this.userService.updateProfile(userId, body);
  }
}
