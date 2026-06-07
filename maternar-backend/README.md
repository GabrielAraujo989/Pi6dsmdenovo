# Maternar — Backend

API REST do projeto Maternar, responsável por autenticação, cadastro de gestantes, gestão de gestações, check-ins com classificação gestacional por IA e integração com o Worker Flask via RabbitMQ.

Desenvolvido com **NestJS 11**, **Prisma 7** e **PostgreSQL** como parte do Projeto Interdisciplinar do 6º semestre do curso de Desenvolvimento de Software Multiplataforma.

---

## Funcionalidades Implementadas

- Cadastro de gestantes com validação de formulário e enriquecimento geográfico via ViaCEP
- Autenticação com JWT (login local com bcrypt, token de 7 dias)
- Proteção de rotas com guard JWT e tratamento de token expirado
- Perfil autenticado com leitura e atualização parcial (PATCH)
- Gestão de ciclos gestacionais (criação, listagem, cálculo automático de DPP)
- Check-ins periódicos com classificação gestacional em tempo real via RabbitMQ
- Endpoint de classificação direta de perfil gestacional (`POST /classification`)
- Integração RabbitMQ (padrão RPC com correlation_id, timeout 10s)
- Integração tolerante a falhas com API pública ViaCEP
- Tratamento de erros padronizado com envelope `{ error: { code, message } }`
- Validação global de DTOs com `ValidationPipe` (whitelist + forbidNonWhitelisted)

---

## Stack

| Tecnologia | Versão | Uso |
|-----------|--------|-----|
| NestJS | ^11.0.1 | Framework REST |
| TypeScript | ^5.7.3 | Linguagem |
| Prisma ORM | ^7.6.0 | Acesso ao banco de dados |
| PostgreSQL | 16 | Banco de dados relacional |
| bcrypt | ^6.0.0 | Hash de senhas |
| passport-jwt | ^4.0.1 | Autenticação JWT |
| class-validator | ^0.15.1 | Validação de DTOs |
| amqplib | ^2.0.1 | Integração RabbitMQ (Worker IA) |
| Docker Compose | — | Banco de dados em desenvolvimento |

---

## Pré-requisitos

- [Node.js](https://nodejs.org/) v22.12.0 ou superior
- [Docker](https://www.docker.com/) e Docker Compose
- [Git](https://git-scm.com/)

---

## Como Rodar Localmente

### 1. Clone o repositório

```bash
git clone https://github.com/guuisouza/maternar-backend
cd maternar-backend
git checkout dev
```

### 2. Instale as dependências

```bash
npm install
```

### 3. Configure as variáveis de ambiente

Crie o arquivo `.env` a partir do template:

```bash
cp .env.example .env
```

Edite `.env` e preencha os valores:

```env
DATABASE_URL="postgresql://admin:SUA_SENHA_AQUI@localhost:5490/gestasus_db?schema=public"
JWT_SECRET="sua_chave_secreta_minimo_32_caracteres"
RABBITMQ_HOST=seu.host
RABBITMQ_PORT=5672
RABBITMQ_USER=usuario
RABBITMQ_PASSWORD=senha
RABBITMQ_QUEUE=maternar.classificar
```

> **Atenção de segurança:** nunca use a senha do `.env.example` em produção. Gere um secret JWT com `openssl rand -base64 32`.

### 4. Suba o banco de dados

```bash
docker-compose up -d
```

O PostgreSQL estará disponível na porta `5490` (mapeada de `5432` no container).

### 5. Aplique as migrations e gere o cliente Prisma

```bash
# Aplica as migrations na pasta prisma/migrations/
npx prisma migrate dev

# Gera os tipos TypeScript do Prisma Client
npx prisma generate
```

### 6. Inicie o servidor

```bash
npm run start:dev
```

A API estará disponível em `http://localhost:3000`.

---

## Endpoints da API

### Autenticação

| Método | Endpoint | Descrição | Auth |
|--------|----------|-----------|------|
| POST | `/auth/login` | Autentica com e-mail e senha | Não |

**Exemplo de login:**
```bash
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"maria@exemplo.com","password":"Abc!2345"}'
```

### Usuários

| Método | Endpoint | Descrição | Auth |
|--------|----------|-----------|------|
| POST | `/users/register` | Cria nova conta de gestante | Não |
| GET | `/users/profile` | Retorna perfil completo da usuária | Bearer JWT |
| PATCH | `/users/profile` | Atualiza parcialmente o perfil | Bearer JWT |

### Gestações

| Método | Endpoint | Descrição | Auth |
|--------|----------|-----------|------|
| POST | `/pregnancy/create` | Cria ciclo gestacional (DPP calculada automaticamente) | Bearer JWT |
| GET | `/pregnancy` | Lista gestações da usuária (mais recente primeiro) | Bearer JWT |

### Questionários (Check-ins)

| Método | Endpoint | Descrição | Auth |
|--------|----------|-----------|------|
| POST | `/questionnaires/:pregnancyId/submit` | Check-in com classificação IA via RabbitMQ | Bearer JWT |
| GET | `/questionnaires/pregnancy/:pregnancyId` | Histórico de check-ins de uma gestação | Bearer JWT |

### Classificação Direta

| Método | Endpoint | Descrição | Auth |
|--------|----------|-----------|------|
| POST | `/classification` | Classificação de perfil gestacional via IA | Bearer JWT |

**Exemplo de cadastro:**
```bash
curl -X POST http://localhost:3000/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Maria Silva",
    "email": "maria@exemplo.com",
    "password": "Abc!2345",
    "birthDate": "1995-09-20",
    "zipCode": "01001000",
    "raceColor": 4,
    "educationLevel": 3
  }'
```

**Envelope de erro padrão:**
```json
{
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Credenciais inválidas."
  }
}
```

---

## Estrutura do Projeto

```
src/
├── app.module.ts                # Módulo raiz
├── main.ts                      # Bootstrap (CORS, ValidationPipe, ExceptionFilter)
├── auth/                        # Autenticação JWT (login, guard, strategy)
├── users/                       # Cadastro, perfil e atualização de gestantes
├── pregnancies/                 # Gestão de ciclos gestacionais
├── questionnaires/              # Check-ins com classificação IA (RabbitMQ)
├── classification/              # Endpoint de classificação direta
├── integrations/
│   ├── viacep/                  # Integração com API pública ViaCEP
│   └── rabbitmq/                # Integração RabbitMQ (padrão RPC)
├── database/                    # Módulo Prisma (global)
└── common/                      # ApiException e filtro global de erros

prisma/
├── schema/
│   ├── schema.prisma            # Configuração do datasource
│   ├── user.prisma              # Model User
│   ├── location.prisma          # Model UserLocation
│   ├── pregnancy.prisma         # Model Pregnancy + enum PregnancyStatus
│   └── questionnaire.prisma     # Model QuestionnaireResponse
└── migrations/                  # Histórico de migrations
```

---

## Testes

```bash
npm test              # Testes unitários
npm run test:cov      # Cobertura de código
npm run test:e2e      # Testes end-to-end
npm run test:watch    # Modo watch
```

Cobertura atual: módulos `auth`, `users`, `pregnancies`, `questionnaires`, `viacep`, `common`.

---

## Documentação Complementar

| Documento | Descrição |
|-----------|-----------|
| [Arquitetura Backend](../Document/14-Arquitetura_Backend_NestJS.md) | Módulos, endpoints, fluxo detalhado |
| [Segurança](../Document/13-Especificacoes_de_Seguranca.md) | Vulnerabilidades identificadas e melhorias |
| [Modelagem de Banco](../Document/17-Modelagem_de_Banco_de_DadosNOVO.md) | Schema Prisma, DDL e relacionamentos |
| [Guia de Integração](../Document/16-Guia_de_Integração.md) | Contratos de API para o Frontend |
| [Integração ViaCEP](docs/12-Integracao_ViaCEP.md) | Comportamento da integração |
| [Abordagem de Testes](docs/13-Abordagem_de_Testes.md) | Estratégia de testes |

---

## Equipe

- Gabriel Araujo de Pádua
- Guilherme Dilio de Souza
- Sheila Alves de Araujo
