import { Injectable, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { CreateQuestionnaireDto } from '../http/questionnaire.dto';
import { PregnancyService } from '../../pregnancies/application/pregnancy.service';

@Injectable()
export class QuestionnaireService {
  constructor(
    private readonly prisma: DatabaseService,
    private readonly pregnancyService: PregnancyService,
  ) {}

  /**
   * Registra a resposta parcial do questionário no banco de dados.
   * Esta etapa ocorre ANTES do envio dos dados para a mensageria/IA.
   */
  async createPartialResponse(
    userId: string,
    pregnancyId: string,
    dto: CreateQuestionnaireDto,
  ) {
    const pregnancy =
      await this.pregnancyService.findPregnancyById(pregnancyId);

    if (!pregnancy || pregnancy.userId !== userId) {
      throw new NotFoundException(
        'Gestação não encontrada ou não pertence a este usuário.',
      );
    }

    const response = await this.prisma.questionnaireResponse.create({
      data: {
        pregnancyId: pregnancyId,
        currentWeight: dto.currentWeight,
        currentAppointments: dto.currentAppointments,
        hadNewComplications: dto.hadNewComplications,
        antiHivFlag: dto.antiHivFlag,
      },
    });

    return {
      id: response.id,
      message: 'Questionário salvo com sucesso. Aguardando análise da IA.',
      responseDate: response.responseDate,
    };
  }

  async findAllByPregnancy(userId: string, pregnancyId: string) {
    const pregnancy =
      await this.pregnancyService.findPregnancyById(pregnancyId);

    if (!pregnancy || pregnancy.userId !== userId) {
      throw new NotFoundException(
        'Gestação não encontrada ou não pertence a este usuário.',
      );
    }

    const responses = await this.prisma.questionnaireResponse.findMany({
      where: { pregnancyId },
      orderBy: { responseDate: 'desc' },
    });

    return responses.map((res) => ({
      ...res,
      currentWeight: Number(res.currentWeight),
      calculatedImc: res.calculatedImc ? Number(res.calculatedImc) : null,
    }));
  }
}
