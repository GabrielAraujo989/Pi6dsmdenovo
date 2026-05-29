import { ArgumentsHost, HttpException, HttpStatus } from '@nestjs/common';
import { ApiExceptionFilter } from '../../../src/common/api-exception.filter';
import { ApiException } from '../../../src/common/api-exception';
import { Response } from 'express';

describe('ApiExceptionFilter', () => {
  let filter: ApiExceptionFilter;
  let mockResponse: jest.Mocked<Partial<Response>>;
  let mockArgumentsHost: jest.Mocked<Partial<ArgumentsHost>>;

  beforeEach(() => {
    filter = new ApiExceptionFilter();

    mockResponse = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };

    mockArgumentsHost = {
      switchToHttp: jest.fn().mockReturnValue({
        getResponse: jest.fn().mockReturnValue(mockResponse),
      }),
    } as unknown as jest.Mocked<Partial<ArgumentsHost>>;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('catch()', () => {
    it('should handle custom ApiException correctly', () => {
      // Arrange
      const exception = new ApiException(
        HttpStatus.BAD_REQUEST,
        'CUSTOM_CODE',
        'Custom error message',
      );

      // Act
      filter.catch(exception, mockArgumentsHost as ArgumentsHost);

      // Assert
      expect(mockResponse.status).toHaveBeenCalledWith(HttpStatus.BAD_REQUEST);
      expect(mockResponse.json).toHaveBeenCalledWith(
        exception.getErrorEnvelope(),
      );
    });

    it('should handle HttpException with string message', () => {
      // Arrange
      const exception = new HttpException(
        'Simple string error',
        HttpStatus.NOT_FOUND,
      );

      // Act
      filter.catch(exception, mockArgumentsHost as ArgumentsHost);

      // Assert
      expect(mockResponse.status).toHaveBeenCalledWith(HttpStatus.NOT_FOUND);
      expect(mockResponse.json).toHaveBeenCalledWith({
        error: { code: 'NOT_FOUND', message: 'Simple string error' },
      });
    });

    it('should handle HttpException with an object containing a string message', () => {
      // Arrange
      const exception = new HttpException(
        { message: 'Object string error' },
        HttpStatus.UNAUTHORIZED,
      );

      // Act
      filter.catch(exception, mockArgumentsHost as ArgumentsHost);

      // Assert
      expect(mockResponse.status).toHaveBeenCalledWith(HttpStatus.UNAUTHORIZED);
      expect(mockResponse.json).toHaveBeenCalledWith({
        error: { code: 'UNAUTHORIZED', message: 'Object string error' },
      });
    });

    it('should handle HttpException with an object containing an array of messages (e.g., ValidationPipe)', () => {
      // Arrange
      const exception = new HttpException(
        { message: ['Error 1', 2, 'Error 3'] },
        HttpStatus.BAD_REQUEST,
      );

      // Act
      filter.catch(exception, mockArgumentsHost as ArgumentsHost);

      // Assert
      expect(mockResponse.status).toHaveBeenCalledWith(HttpStatus.BAD_REQUEST);
      expect(mockResponse.json).toHaveBeenCalledWith({
        error: { code: 'BAD_REQUEST', message: 'Error 1, 2, Error 3' },
      });
    });

    it('should handle HttpException with an object without a message property', () => {
      // Arrange (Simulation of an http status code that is not mapped in getDefaultErrorCode)
      const exception = new HttpException(
        { otherProperty: 'value' },
        HttpStatus.I_AM_A_TEAPOT,
      );

      // Act
      filter.catch(exception, mockArgumentsHost as ArgumentsHost);

      // Assert
      expect(mockResponse.status).toHaveBeenCalledWith(
        HttpStatus.I_AM_A_TEAPOT,
      );
      expect(mockResponse.json).toHaveBeenCalledWith({
        error: { code: 'INTERNAL_SERVER_ERROR', message: 'Unexpected error' },
      });
    });

    it('should handle generic unhandled Errors', () => {
      // Arrange
      const exception = new Error('Some catastrophic failure');

      // Act
      filter.catch(exception, mockArgumentsHost as ArgumentsHost);

      // Assert
      expect(mockResponse.status).toHaveBeenCalledWith(
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
      expect(mockResponse.json).toHaveBeenCalledWith({
        error: { code: 'INTERNAL_SERVER_ERROR', message: 'Unexpected error' },
      });
    });
  });
});
