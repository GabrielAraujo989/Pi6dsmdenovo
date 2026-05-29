# 13 - Abordagem de Testes Unitários no Maternar

Este documento descreve a arquitetura, as ferramentas e a filosofia adotada para a implementação de testes unitários no backend do Maternar, garantindo a confiabilidade, manutenibilidade e a prevenção de regressões no código.

---

## Filosofia e Trade-offs Arquiteturais

No desenvolvimento de software, buscar o "Santo Graal" do isolamento completo (como prega a Clean Architecture ou a Hexagonal) muitas vezes exige a criação de diversas camadas de abstração, como o _Repository Pattern_ para isolar o ORM e _Ports/Adapters_ para bibliotecas de criptografia.

Para o contexto atual do **Maternar**, optamos por uma **abordagem pragmática**. O foco principal foi garantir a entrega de valor de forma ágil e segura, construindo uma suíte de testes robusta que cobre 100% das regras de negócio, mesmo que isso implique em um leve acoplamento com as ferramentas (como Prisma e bcrypt).

É importante termos a consciência de dois trade-offs assumidos nesta arquitetura e nos nossos testes atuais:

- **Acoplamento à Implementação do Prisma (Mocks Rígidos):** Nossos testes atualmente validam a estrutura exata exigida pelo Prisma (ex: uso de _Nested Writes_ para salvar Usuário e Localização). Se no futuro refatorarmos o código para usar o `$transaction` com operações separadas, o teste poderá quebrar, mesmo que o comportamento final esteja correto.
- **Acoplamento à Biblioteca de Criptografia:** Os testes atuais monitoram o fluxo específico do `bcrypt` (chamando o salt e depois o hash). Uma futura troca para outra biblioteca (como Argon2) ou uma mudança na forma de invocar a função exigiria a atualização do teste.

**Estratégia de Evolução (Relaxamento de Asserções):**
Apesar desse engessamento, a nossa suíte atual atende de forma espetacular ao propósito de barrar regressões. Caso as refatorações se tornem frequentes, adotaremos a estratégia de **relaxar as asserções**. Utilizaremos recursos do Jest como o `expect.objectContaining()` para focar apenas em verificar se os **dados importantes** (como e-mail, nome e senha "hasheada") estão contidos no payload, ignorando o "como" eles foram estruturados pela ferramenta subjacente.

---

## 1. Configuração do Ambiente de Testes

Para manter o projeto organizado e otimizado, a configuração de testes foi desacoplada do `package.json` e movida para um arquivo dedicado, além da adição de bibliotecas específicas.

### 1.1. Arquivo de Configuração Dedicado

Toda a configuração do Jest para testes unitários foi centralizada no arquivo `test/jest-unit.json`. Isso permite:

- **Isolamento:** Separar as configurações de testes unitários das de testes End-to-End (E2E).
- **Clareza:** Manter o `package.json` focado apenas nos scripts principais do projeto.
- **Flexibilidade:** Facilitar a adição de configurações específicas (como `coverageThreshold`) sem poluir o `package.json`.

### 1.2. Biblioteca `jest-mock-extended`

Foi adicionada a dependência de desenvolvimento `jest-mock-extended`. O objetivo principal desta biblioteca é criar "dublês" (Mocks) de dependências com tipagem forte, o que é especialmente útil para simular o `PrismaClient` (`DatabaseService`).

**Vantagem:** Ao usar `mockDeep<DatabaseService>()`, o TypeScript nos avisa se tentarmos simular um método que não existe no Prisma (como `prisma.user.findUnique`), prevenindo erros de digitação e garantindo que os testes reflitam a realidade da dependência.

---

## 2. Estrutura e Filosofia de Testes por Camada

Os testes foram organizados na pasta `test/unit`, espelhando a estrutura da pasta `src` para facilitar a localização. A filosofia é testar cada classe de forma completamente isolada, simulando suas dependências diretas.

### 2.1. Camada de Aplicação (`/application`)

#### `user.service.spec.ts`

- **Objetivo:** Testar a principal lógica de negócio do cadastro de usuárias.
- **Dependências Mockadas:** `DatabaseService` e `ViaCepService`.
- **Cenários Cobertos:**
  - **Sucesso (Happy Path):** Criação de usuária com dados de localização quando o ViaCEP responde corretamente.
  - **Falha de Duplicidade:** Tentativa de criar uma usuária com um e-mail que já existe.
  - **Falha de CEP Inválido:** Repasse da exceção quando o `ViaCepService` informa que o CEP não existe.
  - **Resiliência (Fallback):** Criação da usuária sem dados de localização quando o `ViaCepService` informa que a API externa está indisponível (ex: timeout).
  - **Busca e Recuperação:** Testes para `findUserByEmail` e `retrieveUserProfile`, garantindo que a senha nunca seja exposta.

#### `auth.service.spec.ts`

- **Objetivo:** Testar a lógica de autenticação.
- **Dependências Mockadas:** `UserService` e `JwtService`.
- **Cenários Cobertos:**
  - **Sucesso (Happy Path):** Login com credenciais válidas, garantindo a geração de um `access_token`.
  - **Falha de Usuário Inexistente:** Tentativa de login com um e-mail não cadastrado.
  - **Falha de Senha Incorreta:** Simulação do `bcrypt.compare` retornando `false`.
  - **Validação de Payload:** Verificação de que o payload do JWT contém os dados corretos (`sub`, `name`, `email`) e não inclui a senha.

### 2.2. Camada de Integrações (`/integrations`)

#### `viacep.service.spec.ts`

- **Objetivo:** Testar a comunicação e o tratamento de respostas da API externa do ViaCEP.
- **Dependências Mockadas:** API `fetch` global do Node.js.
- **Cenários Cobertos:**
  - **Sucesso (Happy Path):** Retorno dos dados de endereço quando a API responde com status 200.
  - **Falha de Conexão:** Simulação de erro de rede ou timeout no `fetch`.
  - **Falha de Servidor (5xx):** Simulação de uma resposta com `ok: false`.
  - **CEP Inexistente:** Simulação da resposta `{"erro": true}` do ViaCEP.
  - **Validação de Formato:** Teste de bloqueio para CEPs com formato inválido antes mesmo de fazer a chamada de rede.

### 2.3. Camada HTTP (`/http`)

#### `user.controller.spec.ts` e `auth.controller.spec.ts`

- **Objetivo:** Garantir que os controladores atuam como uma "cola", recebendo os dados da requisição e repassando-os corretamente para a camada de serviço.
- **Dependências Mockadas:** `UserService` e `AuthService`.
- **Cenários Cobertos:**
  - **Repasse de Dados:** Verificação de que o DTO (`UserDto`, `LoginLocalDto`) recebido no `@Body` é passado de forma idêntica para o método correspondente no serviço.
  - **Retorno de Resposta:** Garantia de que o retorno do método do serviço é o mesmo que o controlador devolve na resposta da API.

#### `jwt-auth.guard.spec.ts`

- **Objetivo:** Testar a lógica customizada de tratamento de erros de autenticação.
- **Dependências Mockadas:** Nenhuma (instanciado com `new`).
- **Cenários Cobertos:**
  - **Token Expirado:** Simulação do erro `TokenExpiredError` para garantir que a `ApiException` customizada é lançada.
  - **Erro Genérico/Usuário Ausente:** Simulação de falhas gerais do Passport.js.
  - **Sucesso:** Garantia de que o payload do usuário é retornado quando a validação passa.

#### `jwt-strategy.spec.ts`

- **Objetivo:** Testar a configuração e a lógica de validação da estratégia JWT.
- **Dependências Mockadas:** `ConfigService`.
- **Cenários Cobertos:**
  - **Configuração:** Verificação de que a `Strategy` é instanciada corretamente, lendo o `JWT_SECRET` do `ConfigService`.
  - **Validação:** Garantia de que o método `validate` simplesmente retorna o payload recebido, como esperado.

### 2.4. Camada Comum / Global (`/common`)

#### `api-exception.filter.spec.ts`

- **Objetivo:** Garantir que qualquer erro lançado na aplicação seja capturado e formatado no padrão seguro da nossa API (`ApiErrorEnvelope`).
- **Dependências Mockadas:** Contexto de execução do NestJS (`ArgumentsHost`) e o objeto de Resposta (`Response`) do Express.
- **Cenários Cobertos:**
  - **Exceções Customizadas:** Respostas perfeitamente formatadas quando recebem uma instância direta da nossa classe `ApiException`.
  - **Exceções do NestJS (`HttpException`):** Tratamento de diversas variações de mensagens nativas (strings simples, objetos e arrays - cenário muito comum quando o `ValidationPipe` barra um DTO inválido).
  - **Status HTTP não mapeados:** Validação de que códigos HTTP bizarros caem em um fallback seguro.
  - **Erros Inesperados (`Error`):** Interceptação de falhas catastróficas (ex: Null Pointer, falha de sintaxe) disfarçando-as como `500 INTERNAL_SERVER_ERROR` genéricos para não vazar o "stack trace" ou dados sensíveis em produção.
