import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import { ApiException } from '../../common/api-exception';
import {
  IViaCepAdressProvider,
  ViaCepResponse,
} from './interfaces/IViaCepAdressProvider';

@Injectable()
export class ViaCepService implements IViaCepAdressProvider {
  private readonly logger = new Logger(ViaCepService.name);

  async getAddressByZipCode(zipCode: string): Promise<ViaCepResponse> {
    const cleanZipCode = zipCode.replace(/\D/g, '');
    if (cleanZipCode.length !== 8) {
      throw new ApiException(
        HttpStatus.BAD_REQUEST,
        'INVALID_ZIP_CODE',
        'O CEP informado possui tamanho inválido.',
      );
    }

    const timeoutTimeInMs = 5000;
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeoutTimeInMs);

    let response: Response;
    try {
      response = await fetch(`https://viacep.com.br/ws/${cleanZipCode}/json/`, {
        method: 'GET',
        headers: {
          Accept: 'application/json',
        },
        signal: controller.signal,
      });
    } catch (error) {
      clearTimeout(timeoutId);
      this.logger.error(
        `Falha de rede/timeout ao buscar CEP ${zipCode} no ViaCEP`,
        error,
      );
      throw new ApiException(
        HttpStatus.SERVICE_UNAVAILABLE,
        'VIACEP_UNAVAILABLE',
        'Serviço de CEP indisponível no momento.',
      );
    }

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new ApiException(
        HttpStatus.SERVICE_UNAVAILABLE,
        'VIACEP_UNAVAILABLE',
        'Erro no serviço do ViaCEP.',
      );
    }

    const data = (await response.json()) as ViaCepResponse;
    if (data.erro) {
      throw new ApiException(
        HttpStatus.BAD_REQUEST,
        'INVALID_ZIP_CODE',
        'O CEP informado não foi encontrado ou não existe.',
      );
    }

    return data;
  }
}
