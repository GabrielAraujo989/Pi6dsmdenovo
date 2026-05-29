import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';
import { ApiErrorEnvelope, ApiException } from './api-exception';

interface HttpExceptionResponseWithMessage {
  message?: string | string[];
}

function getDefaultErrorCode(status: number): string {
  const errorCodesByStatus = new Map<number, string>([
    [HttpStatus.BAD_REQUEST, 'BAD_REQUEST'],
    [HttpStatus.UNAUTHORIZED, 'UNAUTHORIZED'],
    [HttpStatus.FORBIDDEN, 'FORBIDDEN'],
    [HttpStatus.NOT_FOUND, 'NOT_FOUND'],
    [HttpStatus.CONFLICT, 'CONFLICT'],
    [HttpStatus.UNPROCESSABLE_ENTITY, 'UNPROCESSABLE_ENTITY'],
    [HttpStatus.TOO_MANY_REQUESTS, 'TOO_MANY_REQUESTS'],
  ]);

  return errorCodesByStatus.get(status) ?? 'INTERNAL_SERVER_ERROR';
}

function hasHttpExceptionMessage(
  exceptionResponse: object,
): exceptionResponse is HttpExceptionResponseWithMessage {
  return 'message' in exceptionResponse;
}

function getHttpExceptionMessage(exceptionResponse: string | object): string {
  if (typeof exceptionResponse === 'string') {
    return exceptionResponse;
  }

  if (hasHttpExceptionMessage(exceptionResponse)) {
    const { message } = exceptionResponse;

    if (typeof message === 'string') {
      return message;
    }

    if (Array.isArray(message)) {
      return message.map((item) => String(item)).join(', ');
    }
  }

  return 'Unexpected error';
}

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  catch(
    exception: ApiException | HttpException | Error,
    host: ArgumentsHost,
  ): void {
    const response = host.switchToHttp().getResponse<Response>();

    if (exception instanceof ApiException) {
      response.status(exception.getStatus()).json(exception.getErrorEnvelope());
      return;
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      const message = getHttpExceptionMessage(exceptionResponse);

      response.status(status).json({
        error: {
          code: getDefaultErrorCode(status),
          message,
        },
      } satisfies ApiErrorEnvelope);
      return;
    }

    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Unexpected error',
      },
    } satisfies ApiErrorEnvelope);
  }
}
