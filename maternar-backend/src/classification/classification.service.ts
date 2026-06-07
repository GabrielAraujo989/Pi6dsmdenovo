/* eslint-disable @typescript-eslint/no-unsafe-assignment */
import { HttpStatus, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { DatabaseService } from '../database/database.service';
import { RabbitmqService } from '../integrations/rabbitmq/rabbitmq.service';
import { IClassificationPayload } from '../integrations/rabbitmq/interfaces/classification-payload.interface';
import { ApiException } from '../common/api-exception';
import { ClassificationDto } from './classification.dto';

@Injectable()
export class ClassificationService {
  constructor(
    private readonly prisma: DatabaseService,
    private readonly rabbitmqService: RabbitmqService,
  ) {}

  async classify(userId: string, dto: ClassificationDto) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { location: true },
    });

    if (!user) {
      throw new NotFoundException('Usuário não encontrado.');
    }

    let pregnancy = await this.prisma.pregnancy.findFirst({
      where: { userId, status: 'ACTIVE' },
    });

    if (!pregnancy) {
      pregnancy = await this.prisma.pregnancy.create({
        data: { userId, status: 'ACTIVE' },
      });
    }

    const payload: IClassificationPayload = {
      nu_peso: dto.nu_peso,
      nu_altura: dto.nu_altura,
      nu_imc_pre_gestacional: dto.nu_imc_pre_gestacional,
      raca_cor: dto.raca_cor,
      escolaridade: dto.escolaridade,
      cod_municipio: user.location?.ibgeCode ?? '0000000',
      flag_anti_hiv: dto.flag_anti_hiv ?? 0,
    };

    try {
      const result = await this.rabbitmqService.classificarGestante(payload);

      await this.prisma.questionnaireResponse.create({
        data: {
          pregnancyId: pregnancy.id,
          currentWeight: dto.nu_peso,
          currentAppointments: 0,
          hadNewComplications: false,
          antiHivFlag: dto.flag_anti_hiv ?? 0,
          clusterId: result.cluster_id,
          clusterName: result.cluster_nome_app,
          calculatedImc: result.metricas.nu_imc_calculado,
          riskLevel: result.nivel_risco,
          hexColor: result.cor_hex,
          recommendations: result.recomendacoes as unknown as Prisma.InputJsonValue,
          metrics: result.metricas as unknown as Prisma.InputJsonValue,
        },
      });

      await this.prisma.pregnancy.update({
        where: { id: pregnancy.id },
        data: {
          currentClusterId: result.cluster_id,
          currentClusterName: result.cluster_nome_app,
          currentRiskLevel: result.nivel_risco,
          currentHexColor: result.cor_hex,
        },
      });

      return result;
    } catch (error) {
      if (error instanceof ApiException) throw error;
      throw new ApiException(
        HttpStatus.SERVICE_UNAVAILABLE,
        'CLASSIFICATION_TIMEOUT',
        'Classificação em processamento. Tente novamente em instantes.',
      );
    }
  }
}
