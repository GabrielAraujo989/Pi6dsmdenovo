# Maternar Frontend

Aplicativo Flutter do projeto Maternar, com foco em acompanhamento gestacional preventivo e jornada de cuidado para gestantes.

## Visao geral

O app foi construido com Flutter e Material 3, com interface mobile-first, identidade visual personalizada e navegacao por rotas para fluxos principais de onboarding, cadastro e acompanhamento. Integrado com backend NestJS para autenticacao, registro de usuarios e sincronizacao de perfil.

## Funcionalidades atuais

- Tela de boas-vindas com entrada para criacao de conta e acesso de usuaria ja cadastrada.
- Fluxo de cadastro com validacoes de formulario completo.
- Regras de senha com medidor de forca (minimo 8 caracteres, caractere especial, numero, maiusculas/minusculas).
- Mascara de telefone em tempo real.
- Consulta ViaCEP com autocomplete de endereco (logradouro, bairro, cidade/UF).
- Toggle para preenchimento automatico ou manual por CEP.
- Integracao com backend NestJS para registro, autenticacao JWT e perfil de usuario.
- Navegacao para telas de questionario, resultados, registro diario e conteudo educativo.
- Dashboard com dados sincronizados da API apos autenticacao.

## Stack

- Flutter SDK 3.8+
- Dart 3.8+
- Material 3
- google_fonts
- http (cliente HTTP para chamadas API)
- shared_preferences (persistencia local de sessao e token)

## Estrutura principal

- `lib/main.dart`: ponto de entrada, composicao principal da interface e fluxos de UI.
- `lib/backend_api.dart`: cliente HTTP para registro, autenticacao e consumo de `/users/profile`.
- `lib/viacep_service.dart`: servico para consultar API publica ViaCEP e obter dados de endereco.
- `lib/app_session.dart`: gerencia sessao autenticada, token JWT e dados de perfil local.
- `lib/home_dashboard_data_source.dart`: fonte de dados para dashboard (API + fallback local).
- `assets/images/`: imagens utilizadas no app.
- `src/images/`: imagens complementares do projeto.
- `test/widget_test.dart`: testes iniciais de widget.

## Requisitos

- Flutter instalado e configurado no PATH (Flutter 3.8+).
- Um dispositivo/emulador Android, iOS, Web ou Desktop disponivel.
- Backend Maternar rodando em `http://localhost:3000` (ou configurar `API_BASE_URL`).
- Docker instalado (para banco de dados PostgreSQL do backend).

Para validar o ambiente Flutter:

```bash
flutter doctor
```

## Como executar localmente

### 1. Preparar o Backend

Clone e configure o repositorio backend:

```bash
git clone https://github.com/guuisouza/maternar-backend.git
cd maternar-backend
git checkout dev
npm install
```

Suba o banco de dados e aplique migrations:

```bash
docker-compose up -d
npx prisma migrate dev
npx prisma generate
```

Inicie o servidor NestJS em modo desenvolvimento:

```bash
npm run start:dev
```

A API estara disponivel em `http://localhost:3000`.

### 2. Preparar o Frontend

Na pasta do projeto, instale dependencias:

```bash
flutter pub get
```

(Opcional) Se a API nao estiver em `localhost:3000`, atualize `API_BASE_URL` em `lib/backend_api.dart`.

Liste os dispositivos disponiveis:

```bash
flutter devices
```

Rode o app no dispositivo desejado:

```bash
flutter run -d <device_id>
```

Exemplo (emulador Android):

```bash
flutter run -d emulator-5554
```

## Comandos uteis

```bash
flutter analyze        # Validacao estatica de codigo
flutter test           # Testes unitarios
flutter clean          # Limpar build cache
```

## Rotas principais da aplicacao

- `/`: tela inicial (boas-vindas).
- `/signup`: cadastro de usuaria com integracao ViaCEP.
- `/login`: autenticacao com email e senha.
- `/home`: area principal do app com dashboard sincronizado.
- `/questionnaire`: questionario de triagem de saude.
- `/processing`: processamento de perfil de risco.
- `/safe-path`: resultado de risco controlado.
- `/high-alert`: resultado de alerta elevado.
- `/daily-log`: registro diario de sintomas.
- `/education`: artigos educativos.
- `/baby-week`: planejamento por semana de gestacao.
- `/nutrition`: dicas nutricionais.
- `/notifications`: central de notificacoes.

## Fluxo de autenticacao

### Registro de usuario

**Endpoint:** `POST /users/register`

**Campos obrigatorios:**
- `name` (string, minimo 3 caracteres)
- `email` (string, email valido)
- `password` (string, minimo 8 caracteres com: caractere especial, numero, maiusculas e minusculas)
- `birthDate` (ISO 8601, ex: `2026-09-20`)

**Exemplo de requisicao:**

```json
{
  "name": "Maria Silva",
  "email": "maria.silva@example.com",
  "password": "Abc!2345",
  "birthDate": "2026-09-20"
}
```

**Resposta de sucesso (201):**

```json
{
  "message": "User created successfully"
}
```

### Login

**Endpoint:** `POST /auth/login`

**Parametros:**
- `email` (string)
- `password` (string)

**Exemplo:**

```json
{
  "email": "maria.silva@example.com",
  "password": "Abc!2345"
}
```

**Resposta de sucesso (200):**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 60
}
```

### Perfil de usuario

**Endpoint:** `GET /users/profile`

**Headers:**

```
Authorization: Bearer <access_token>
```

**Resposta de sucesso (200):**

```json
{
  "id": "187a903a-2256-4b71-b76a-1d92d4c15b03",
  "name": "Maria Silva",
  "email": "maria.silva@example.com",
  "birthDate": "2026-09-20T00:00:00.000Z",
  "createdAt": "2026-04-29T01:50:48.740Z"
}
```

## Integracao ViaCEP

O app consulta a API publica ViaCEP para autocomplete de endereco:

### Modo de uso

1. **Preenchimento automatico (padrao):**
   - Digite 8 digitos no campo CEP.
   - A consulta eh feita automaticamente.
   - Campos de logradouro, bairro e cidade sao preenchidos.

2. **Modo manual:**
   - Desative o toggle "Preenchimento automatico".
   - Use o botao de busca (icone de lupa) para consultar manualmente.

### Campos retornados

- `logradouro`: rua, avenida, etc
- `bairro`: bairro
- `localidade`: cidade
- `uf`: unidade federativa (UF)

### Tratamento de erros

- CEP invalido (nao 8 digitos) → validacao local
- CEP nao encontrado → mensagem "CEP nao encontrado"
- Timeout na consulta ViaCEP → mensagem "Tempo esgotado na consulta do ViaCEP"
- Redes indisponiveis → fallback para entrada manual

## Testes

### Validacao de codigo

```bash
flutter analyze
```

### Testes de widget

```bash
flutter test
```

### Teste de registro end-to-end (PowerShell)

Com o backend rodando em `localhost:3000`:

```powershell
$body = @{
  name = 'Teste Usuario'
  email = 'teste@example.com'
  password = 'Teste@123'
  birthDate = '2026-10-15'
} | ConvertTo-Json

Invoke-RestMethod -Uri 'http://localhost:3000/users/register' `
  -Method Post -Body $body -ContentType 'application/json'
```

### Teste de login e autenticacao

```powershell
# 1. Login
$loginBody = @{ 
  email = 'teste@example.com'
  password = 'Teste@123'
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Uri 'http://localhost:3000/auth/login' `
  -Method Post -Body $loginBody -ContentType 'application/json'

$token = $loginResponse.access_token

# 2. Acessar perfil com token
$headers = @{ 'Authorization' = "Bearer $token" }
$profile = Invoke-RestMethod -Uri 'http://localhost:3000/users/profile' `
  -Method Get -Headers $headers

Write-Host ($profile | ConvertTo-Json)
```

## Persistencia local

Os dados abaixo sao armazenados localmente via `SharedPreferences`:

- `auth_token`: JWT token da sessao autenticada
- `profile_name`: nome do usuario
- `profile_email`: email do usuario
- `profile_due_date`: data prevista do parto (para calculo de semana de gestacao)

Esses dados sao carregados na inicializacao do app (`AppSession.init()`) e sincronizados com o backend quando o token estiver valido.

## Status do projeto

Frontend em desenvolvimento ativo com:
- ✅ Integracao completa com backend NestJS
- ✅ Autenticacao JWT com tokens seguros
- ✅ Consumo de API ViaCEP para endereco
- ✅ Fluxos de registro, login e dashboard implementados e testados
- ✅ Persistencia local de sessao

Proximos passos:
- Implementacao de questionarios de triagem com submissao para backend
- Integracoes com servicos de IA para classificacao de risco
- Sincronizacao de registros diarios

## Contribuicao

1. Crie uma branch a partir da `main` ou `dev` conforme o padrao do projeto.
2. Faca commits pequenos e descritivos.
3. Certifique-se de que `flutter analyze` passa sem erros.
4. Mantenha o contrato com o backend (endpoints e DTOs) sincronizado com a branch `dev` do repositorio `maternar-backend`.
5. Abra Pull Request com resumo claro das alteracoes.

## Licenca

Definir conforme a estrategia do projeto.
