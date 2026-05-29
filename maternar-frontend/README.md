# Maternar — Frontend

Aplicativo Flutter do projeto Maternar. Acompanhamento gestacional preventivo com jornada de cuidado personalizada para gestantes, construído com Material 3 e integração completa com o backend NestJS.

Desenvolvido como parte do Projeto Interdisciplinar do 6º semestre do curso de Desenvolvimento de Software Multiplataforma.

---

## Funcionalidades Implementadas

- Tela de boas-vindas com identidade visual do Maternar
- Fluxo de cadastro com validações completas de formulário
- Medidor de força de senha em tempo real (4 critérios visuais)
- Máscara de telefone automática durante a digitação
- Integração com ViaCEP: autocomplete de endereço por CEP (toggle automático/manual)
- Autenticação JWT com persistência local de sessão
- Dashboard sincronizado com backend após autenticação
- Cálculo de semana gestacional e dias para o parto
- Histórico de consultas pré-natais
- Métricas de saúde (pressão, peso, glicemia)
- Diário de sintomas com escala de humor
- Artigos educativos categorizados
- Central de notificações
- Perfil editável com logout seguro

---

## Stack

| Tecnologia | Versão | Uso |
|-----------|--------|-----|
| Flutter | 3.8+ | Framework multiplataforma |
| Dart | 3.8+ | Linguagem |
| Material 3 | — | Design system |
| google_fonts | ^6.2.1 | Tipografia (DM Sans, Playfair Display) |
| http | ^1.2.2 | Requisições HTTP |
| shared_preferences | ^2.3.2 | Persistência local |
| flutter_lints | ^5.0.0 | Análise estática |

---

## Pré-requisitos

- Flutter SDK 3.8+ instalado e no PATH
- Dispositivo, emulador Android/iOS ou browser disponível
- Backend Maternar rodando (ver instruções abaixo)

```bash
# Verificar ambiente Flutter
flutter doctor
```

---

## Como Rodar Localmente

### 1. Preparar o Backend

Clone e configure o backend Maternar:

```bash
git clone https://github.com/guuisouza/maternar-backend.git
cd maternar-backend
git checkout dev
npm install
cp .env.example .env  # editar .env com credenciais reais
docker-compose up -d
npx prisma migrate dev
npx prisma generate
npm run start:dev
```

A API estará em `http://localhost:3000`.

### 2. Instalar dependências Flutter

```bash
flutter pub get
```

### 3. Executar o app

```bash
# Listar dispositivos disponíveis
flutter devices

# Executar no emulador Android (backend em 10.0.2.2:3000 por padrão)
flutter run -d emulator-5554

# Executar no browser
flutter run -d chrome

# Executar com URL de API personalizada
flutter run --dart-define=API_BASE_URL=http://SEU_IP:3000
```

---

## Estrutura de Arquivos

```
lib/
├── main.dart                       # Ponto de entrada e todas as telas
├── backend_api.dart                # Cliente HTTP tipado (registro, login, perfil)
├── app_session.dart                # Sessão JWT e dados de perfil local
├── home_dashboard_data_source.dart # Dados do Dashboard (Strategy Pattern)
└── viacep_service.dart             # Consulta de CEP via ViaCEP
```

---

## Rotas

| Rota | Tela | Auth |
|------|------|------|
| `/` | WelcomeScreen | Não |
| `/signup` | SignupScreen | Não |
| `/login` | LoginScreen | Não |
| `/home` | MainAppNavigation | Sim |
| `/questionnaire` | QuestionnaireScreen | Sim |
| `/processing` | ProfileProcessingScreen | Sim |
| `/safe-path` | SafePathResultScreen | Sim |
| `/high-alert` | HighAlertResultScreen | Sim |
| `/daily-log` | DailyLogScreen | Sim |
| `/education` | EducationalArticlesScreen | Sim |
| `/baby-week` | BabyWeekPlannerScreen | Sim |
| `/nutrition` | NutritionTipsScreen | Sim |
| `/notifications` | NotificationCenterScreen | Sim |

---

## Fluxo de Autenticação

```
Início do App → AppSession.init()
    │
    ├── Token salvo? ──► /home (dashboard sincronizado)
    │
    └── Sem token ────► /
                           │
                     ┌─────┴──────┐
                     │            │
                   /signup      /login
                     │            │
               POST /users    POST /auth/login
               /register          │
                     │        saveToken()
                  login auto       │
                     │        sync perfil
                  saveToken()      │
                     │            │
                     └─────┬──────┘
                           ▼
                      /home (sem volta)
```

---

## API do Backend

### Registro

```
POST /users/register
Content-Type: application/json

{
  "name": "Maria Silva",
  "email": "maria@exemplo.com",
  "password": "Abc!2345",
  "birthDate": "2026-09-20",
  "zipCode": "01001000"
}
```

### Login

```
POST /auth/login
Content-Type: application/json

{ "email": "maria@exemplo.com", "password": "Abc!2345" }

→ { "access_token": "eyJ...", "expiresIn": 60 }
```

### Perfil

```
GET /users/profile
Authorization: Bearer <access_token>

→ { "id": "uuid", "name": "...", "email": "...", "birthDate": "...", ... }
```

---

## Testes

```bash
flutter analyze        # Análise estática de código
flutter test           # Testes de widget
flutter test --coverage  # Com relatório de cobertura
```

---

## Build de Release

```bash
# Android APK (debug)
flutter build apk

# Android APK (release com obfuscação — recomendado)
flutter build apk --release --obfuscate --split-debug-info=build/symbols

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## Persistência Local

Dados armazenados via `SharedPreferences`:

| Chave | Conteúdo |
|-------|---------|
| `auth_token` | JWT de acesso |
| `profile_name` | Nome da gestante |
| `profile_email` | E-mail |
| `profile_due_date` | Data prevista do parto (ISO 8601) |

> **Nota de segurança:** Em versão futura, tokens serão migrados para `flutter_secure_storage` para armazenamento criptografado. Ver [Especificações de Segurança](../Document/13-Especificacoes_de_Seguranca.md).

---

## Documentação Complementar

| Documento | Descrição |
|-----------|-----------|
| [Arquitetura Frontend](../Document/15-Arquitetura_Frontend_Flutter.md) | Camadas, telas, fluxos detalhados |
| [Segurança](../Document/13-Especificacoes_de_Seguranca.md) | Vulnerabilidades e melhorias |
| [UX e Tom de Voz](../Document/04-Guia_de_UX_e_Tom_de_Voz.md) | Identidade visual e linguagem |
| [Fluxo de Telas](../Document/06-Fluxo_e_Telas_da_Aplicacao.md) | Jornadas e wireframes |

---

## Contribuição

1. Crie branch a partir de `dev`
2. Garanta que `flutter analyze` passa sem erros
3. Mantenha o contrato de API sincronizado com o repositório do backend
4. Abra Pull Request com descrição clara das alterações

---

## Equipe

- Gabriel Araujo de Pádua
- Guilherme Dilio de Souza
- Sheila Alves de Araujo
