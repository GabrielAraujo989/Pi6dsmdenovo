import { Test, TestingModule } from '@nestjs/testing';
import { HttpStatus, Logger } from '@nestjs/common';

import { ViaCepService } from '../../../../src/integrations/viacep/viacep.service';
import { ApiException } from '../../../../src/common/api-exception';
import { ViaCepResponse } from '../../../../src/integrations/viacep/interfaces/IViaCepAdressProvider';

describe('ViaCepService', () => {
  let service: ViaCepService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [ViaCepService],
    }).compile();

    service = module.get<ViaCepService>(ViaCepService);

    global.fetch = jest.fn();

    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('getAddressByZipCode()', () => {
    it('should throw an ApiException with BAD_REQUEST if the zip code does not have exactly 8 digits', async () => {
      // Arrange
      const invalidZipCode = '123-45';

      // Act & Assert
      await expect(service.getAddressByZipCode(invalidZipCode)).rejects.toThrow(
        new ApiException(
          HttpStatus.BAD_REQUEST,
          'INVALID_ZIP_CODE',
          'O CEP informado possui tamanho inválido.',
        ),
      );

      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('should throw an ApiException with SERVICE_UNAVAILABLE if fetch fails (e.g., network error or timeout)', async () => {
      // Arrange
      const validZipCode = '12345678';
      (global.fetch as jest.Mock).mockRejectedValue(new Error('Network error'));

      // Act & Assert
      await expect(service.getAddressByZipCode(validZipCode)).rejects.toThrow(
        new ApiException(
          HttpStatus.SERVICE_UNAVAILABLE,
          'VIACEP_UNAVAILABLE',
          'Serviço de CEP indisponível no momento.',
        ),
      );
      expect(global.fetch).toHaveBeenCalledWith(
        `https://viacep.com.br/ws/${validZipCode}/json/`,
        expect.any(Object),
      );
      expect(Logger.prototype.error).toHaveBeenCalled();
    });

    it('should throw an ApiException with SERVICE_UNAVAILABLE if the response status is not OK (e.g., 500 Internal Server Error)', async () => {
      // Arrange
      const validZipCode = '12345678';
      (global.fetch as jest.Mock).mockResolvedValue({
        ok: false,
      });

      // Act & Assert
      await expect(service.getAddressByZipCode(validZipCode)).rejects.toThrow(
        new ApiException(
          HttpStatus.SERVICE_UNAVAILABLE,
          'VIACEP_UNAVAILABLE',
          'Erro no serviço do ViaCEP.',
        ),
      );
    });

    it('should throw an ApiException with BAD_REQUEST if the ViaCEP API returns an error indicating the zip code was not found', async () => {
      // Arrange
      const validZipCode = '00000000';
      (global.fetch as jest.Mock).mockResolvedValue({
        ok: true,
        json: () => Promise.resolve({ erro: true }),
      });

      // Act & Assert
      await expect(service.getAddressByZipCode(validZipCode)).rejects.toThrow(
        new ApiException(
          HttpStatus.BAD_REQUEST,
          'INVALID_ZIP_CODE',
          'O CEP informado não foi encontrado ou não existe.',
        ),
      );
    });

    it('should return the address data successfully when a valid zip code is provided (Happy Path)', async () => {
      // Arrange
      const dirtyZipCode = '14400-000';
      const cleanZipCode = '14400000';
      const mockResponse: ViaCepResponse = {
        cep: '14400-000',
        logradouro: 'Rua Fictícia',
        complemento: '',
        bairro: 'Centro',
        localidade: 'Franca',
        uf: 'SP',
        estado: 'São Paulo',
        regiao: 'Sudeste',
        ibge: '3516200',
        gia: '1234',
        ddd: '16',
        siafi: '1234',
      };

      (global.fetch as jest.Mock).mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(mockResponse),
      });

      // Act
      const result = await service.getAddressByZipCode(dirtyZipCode);

      // Assert
      expect(global.fetch).toHaveBeenCalledWith(
        `https://viacep.com.br/ws/${cleanZipCode}/json/`,
        expect.any(Object),
      );
      expect(result).toEqual(mockResponse);
    });
  });
});
