# 12 - Integração ViaCEP e Regras de Negócio

Este documento descreve a arquitetura, o fluxo de validação e as estratégias de resiliência implementadas no processo de cadastro de gestantes (**Usuárias**) em relação à coleta e validação de dados geográficos (CEP).

## 1. Objetivo da Integração

O CEP fornecido pela gestante no momento da criação da conta é utilizado para determinar sua localização geográfica (Cidade, Estado, Região e Código IBGE). Esses dados são salvos na tabela `user_locations` e são cruciais para:

- Cruzamento futuro com o **Dicionário de Dados do DATASUS** (ex: base CNES para proximidade de maternidades e SNIS para saneamento básico).
- Aprimoramento da assertividade do modelo de Inteligência Artificial (K-Means).

A integração é feita através da API pública e gratuita do ViaCEP.

---

## 2. Regras de Validação e Resiliência (Fallback)

A comunicação com APIs de terceiros está sujeita a instabilidades. Por isso, foram implementadas regras rigorosas no `UserService` e no `ViaCepService` para garantir que o **Maternar** não seja paralisado por falhas externas, mas que também não permita a entrada de dados propositalmente falsos.

### Cenário A: CEP Inválido ou Inexistente (Bloqueio)

- **Condição:** O CEP informado não possui 8 dígitos após a limpeza, ou a API do ViaCEP retorna o objeto `{"erro": "true"}` (CEP bem formatado, mas inexistente no Brasil).
- **Comportamento Técnico:** O serviço do ViaCEP lança uma exceção customizada `ApiException` com status `400 BAD REQUEST`.
- **Impacto no Negócio:** O `UserService` identifica o status `400` e **bloqueia o cadastro**, repassando o erro para o Front-end. A gestante é obrigada a informar um CEP válido para criar a conta.

### Cenário B: Instabilidade na API do ViaCEP (Aprovação Silenciosa)

- **Condição:** O ViaCEP demora mais de 5 segundos para responder (Timeout via `AbortController`) ou retorna um erro de servidor (ex: Status `500`).
- **Comportamento Técnico:** O serviço do ViaCEP lança uma `ApiException` com status `503 SERVICE UNAVAILABLE`.
- **Impacto no Negócio:** O `UserService` intercepta essa exceção no bloco `catch` e a **ignora** de forma controlada. O fluxo de criação de conta prossegue normalmente sem popular os dados do ViaCEP. Isso garante que a gestante consiga criar sua conta e acessar o app mesmo se a API do Governo/ViaCEP estiver fora do ar.

### Cenário C: Sucesso (Fluxo Feliz)

- **Condição:** A API responde rapidamente com os dados da localidade.
- **Impacto no Negócio:** O cadastro prossegue e os dados completos (Cidade, UF, Região e Código IBGE) ficam disponíveis na memória para a etapa de persistência.

---

## 3. Persistência de Dados e Transações (Tudo ou Nada)

A separação das tabelas `users` e `user_locations` (Relação 1:1) exige que a gravação no banco de dados seja atômica. Se salvarmos o usuário e o banco cair logo em seguida antes de salvar a localização, teremos uma _falha parcial_ (dados zumbis e inconsistentes).

Para mitigar isso sem onerar o código com rollbacks manuais, foi utilizado o recurso de **Nested Writes** (Escritas Aninhadas) do Prisma ORM.

### Como funciona:

No momento de criar o registro, é utilizado um condicional via _spread operator_ no objeto de configuração do Prisma:

```typescript
await this.prisma.user.create({
  data: {
    // ...dados da gestante,
    ...(viaCepData && {
      location: {
        create: {
          city: viaCepData.localidade,
          uf: viaCepData.uf,
          region: viaCepData.regiao,
          ibgeCode: viaCepData.ibge,
        },
      },
    }),
  },
});
```

Desta forma, a engine do banco de dados (PostgreSQL) abre uma **única transação**. Se `viaCepData` for nulo (devido a instabilidade vista no Cenário B), apenas o usuário é salvo. Se os dados existirem, ambos são salvos. Caso ocorra uma queda no banco de dados no momento da gravação da localização, o próprio banco realiza um `ROLLBACK` seguro, não deixando rastros na tabela de usuários.
