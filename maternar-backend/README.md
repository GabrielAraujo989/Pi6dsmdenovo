## Sobre o repositório

O **Maternar** é uma aplicação focada no cuidado integral com a gestante. Utilizando inteligência artificial (K-Means) alimentada por dados históricos do DATASUS para classificar o perfil de cuidado necessário de forma acolhedora. O app oferece dicas personalizadas, educação em saúde e monitoramento preventivo, transformando dados estatísticos em suporte real durante toda a gestação. Neste repositório se encontra o backend da aplicação, que irá lidar com a criação de conta, autenticação da gestante e será responsável por fazer a persistência de dados de formulários e todo o restante.

## Como rodar o projeto localmente

Siga os passos abaixo para configurar o ambiente de desenvolvimento, subir a infraestrutura do banco de dados e iniciar a API.

### Pré-requisitos

Certifique-se de ter instalado em sua máquina:

- [Node.js](https://nodejs.org/en/) (v22.12.0 ou superior)
- [Docker](https://www.docker.com/) e Docker Compose
- [Git](https://git-scm.com/)

### Passo a Passo

**1. Clone o repositório e acesse a pasta**

```bash
git clone <https://github.com/guuisouza/maternar-backend>
cd maternar-backend
```

**2. Mude para a branch de desenvolvimento (`dev`)**

```bash
git checkout dev
```

**3. Instale as dependências do projeto**

```bash
npm install
```

**4. Configure as Variáveis de Ambiente**
Crie um arquivo `.env` na raiz do projeto, pegue como base o arquivo .env.example na raiz do projeto e preencha com as chaves fundamentais para o banco e para a autenticação.

**5. Suba o Banco de Dados (Docker)**
Certifique-se de que o aplicativo do Docker está aberto e rodando em sua máquina, e execute:

```bash
docker-compose up -d
```

> _Nota: A flag `-d` roda o container em segundo plano. O banco de dados PostgreSQL estará disponível na porta 5432._

**6. Configure o Banco de Dados (Prisma)**
Como o container do Docker subiu "zerado", você precisa aplicar as tabelas (migrations) no banco e gerar o cliente do Prisma para o TypeScript reconhecer os tipos. Rode:

```bash
# Aplica as migrations existentes na pasta prisma/migrations no banco de dados
npx prisma migrate dev

# Gera os artefatos do Prisma Client (Necessário devido à arquitetura Prisma 7+)
npx prisma generate
```

**7. Inicie a Aplicação**
Com o banco rodando e o Prisma configurado, inicie o servidor NestJS em modo de desenvolvimento:

```bash
npm run start:dev
```

A API estará disponível e "escutando" as requisições (por padrão em `http://localhost:3000`).
