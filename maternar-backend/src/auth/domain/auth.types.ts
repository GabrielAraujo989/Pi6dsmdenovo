import { Request } from 'express';
import { User } from '@prisma/client';

export type SafeUser = Omit<User, 'password'>;

export interface AuthenticatedUserPayload {
  sub: string;
  email: string;
  name: string;
  iat: number;
  exp: number;
}

export interface AuthenticatedRequest extends Request {
  user: AuthenticatedUserPayload;
}
