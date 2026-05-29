# Maternar — Backend

API REST do projeto Maternar, responsável por autenticação, cadastro de gestantes e persistência de dados.

Desenvolvido com **NestJS 11**, **Prisma 7** e **PostgreSQL** como parte do Projeto Interdisciplinar do 6º semestre do curso de Desenvolvimento de Software Multiplataforma.

---

## Funcionalidades Implementadas

- Cadastro de gestantes com validação de formulário e enriquecimento geográfico via ViaCEP
- Autenticação com JWT (login local com bcrypt)
- Proteção de rotas com guard JWT e tratamento de token expirado
- Endpoint de perfil autenticado
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
| PostgreSQL | 15 | Banco de dados relacional |
| bcrypt | ^6.0.0 | Hash de senhas |
| passport-jwt | ^4.0.1 | Autenticação JWT |
| class-validator | ^0.15.1 | Validação de DTOs |
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
DATABASE_URL="postgresql://admin:SUA_SENHA_AQUI@localhost:5432/gestasus_db?schema=public"
JWT_SECRET="sua_chave_secreta_minimo_32_caracteres"
```

> **Atenção de segurança:** nunca use a senha do `.env.example` em produção. Gere um secret JWT com `openssl rand -base64 32`.

### 4. Suba o banco de dados

```bash
docker-compose up -d
```

O PostgreSQL estará disponível na porta `5432`.

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
| GET | `/users/profile` | Retorna perfil da usuária autenticada | Bearer JWT |

**Exemplo de cadastro:**
```bash
curl -X POST http://localhost:3000/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Maria Silva",
    "email": "maria@exemplo.com",
    "password": "Abc!2345",
    "birthDate": "2026-09-20",
    "zipCode": "01001000"
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
├── app.module.ts           # Módulo raiz
├── main.ts                 # Bootstrap (ValidationPipe, ExceptionFilter)
├── auth/                   # Autenticação JWT
├── users/                  # Cadastro e perfil de gestantes
├── integrations/viacep/    # Integração com API ViaCEP
├── database/               # Módulo Prisma
└── common/                 # Exceções e filtros globais

prisma/
├── schema/
│   ├── schema.prisma        # Configuração do datasource
│   ├── user.prisma          # Model User
│   └── location.prisma      # Model UserLocation
└── migrations/              # Histórico de migrations
```

---

## Testes

```bash
npm test              # Testes unitários
npm run test:cov      # Cobertura de código
npm run test:e2e      # Testes end-to-end
npm run test:watch    # Modo watch
```

Cobertura atual: módulos `auth`, `users`, `viacep`, `common`.

---

## Documentação Complementar

| Documento | Descrição |
|-----------|-----------|
| [Arquitetura Backend](../Document/14-Arquitetura_Backend_NestJS.md) | Módulos, endpoints, fluxo detalhado |
| [Segurança](../Document/13-Especificacoes_de_Seguranca.md) | Vulnerabilidades identificadas e melhorias |
| [Modelagem de Banco](../Document/11-Modelagem_de_Banco_de_Dados.md) | Schemas e relacionamentos |
| [Integração ViaCEP](docs/12-Integracao_ViaCEP.md) | Comportamento da integração |
| [Abordagem de Testes](docs/13-Abordagem_de_Testes.md) | Estratégia de testes |

---

## Equipe

- Gabriel Araujo de Pádua
- Guilherme Dilio de Souza
- Sheila Alves de Araujo
