import { Body, Controller, Post } from '@nestjs/common';
import { LoginLocalDto } from './auth.dto';
import { AuthService } from '../application/auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  async signIn(@Body() loginDto: LoginLocalDto) {
    return this.authService.signIn(loginDto);
  }
}
