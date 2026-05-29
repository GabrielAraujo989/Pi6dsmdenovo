import { HttpException, HttpStatus } from '@nestjs/common';

export interface ApiErrorEnvelope {
  error: {
    code: string;
    message: string;
  };
}

export class ApiException extends HttpException {
  private readonly errorEnvelope: ApiErrorEnvelope;
  constructor(status: HttpStatus, code: string, message: string) {
    const errorEnvelope: ApiErrorEnvelope = {
      error: {
        code,
        message,
      },
    };

    super(errorEnvelope, status);
    this.errorEnvelope = errorEnvelope;
  }

  getErrorEnvelope(): ApiErrorEnvelope {
    return this.errorEnvelope;
  }
}
