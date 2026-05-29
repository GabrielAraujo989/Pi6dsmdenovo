# 15 — Arquitetura do Frontend Flutter

**Data:** 2026-05-29  
**Versão:** 1.0  
**Stack:** Flutter 3.8+ · Dart 3.8+ · Material 3 · http · shared_preferences · google_fonts

---

## 1. Visão Geral

O frontend do Maternar é um aplicativo **Flutter** com suporte multiplataforma (Android, iOS, Web, Desktop). O app entrega a jornada de acompanhamento gestacional preventivo com interface acolhedora, identidade visual personalizada e integração completa com o backend NestJS.

**Pacote:** `gestcare_app` (nome interno, marca externa: **Maternar**)

---

## 2. Estrutura de Arquivos

```
maternar-frontend/
├── lib/
│   ├── main.dart                        # Ponto de entrada, todas as telas e widgets
│   ├── backend_api.dart                 # Cliente HTTP (BackendApi)
│   ├── app_session.dart                 # Sessão autenticada e dados de perfil local
│   ├── home_dashboard_data_source.dart  # Abstração de dados para o Dashboard
│   └── viacep_service.dart              # Consulta de CEP via API pública ViaCEP
│
├── assets/
│   └── images/                          # Imagens do app
├── src/
│   └── images/                          # Imagens complementares
│
├── test/
│   └── widget_test.dart                 # Testes de widget iniciais
│
├── android/                             # Configuração Android nativa
├── ios/                                 # Configuração iOS nativa
├── web/                                 # Configuração Web (PWA)
├── linux/ windows/ macos/               # Configuração Desktop
│
├── pubspec.yaml                         # Dependências e configuração do projeto
└── analysis_options.yaml               # Regras de lint (flutter_lints)
```

---

## 3. Camadas da Aplicação

### 3.1 Camada de Sessão (`app_session.dart`)

Gerencia o estado global de autenticação e dados de perfil da usuária usando **SharedPreferences** para persistência local.

**Responsabilidades:**
- Inicializar sessão ao abrir o app (`AppSession.init()`)
- Armazenar e recuperar JWT token
- Armazenar nome, e-mail e data de parto
- Calcular semana gestacional atual e dias restantes para o parto

**Cálculos implementados:**
```dart
// Semana gestacional: baseada nos 280 dias totais de gestação
static int _currentWeekFromDueDate(DateTime dueDate)

// Dias restantes até o parto
static int _daysToBirthFromDueDate(DateTime dueDate)
```

**Dados persistidos (SharedPreferences):**

| Chave | Tipo | Descrição |
|-------|------|-----------|
| `auth_token` | String | JWT de acesso |
| `profile_name` | String | Nome da gestante |
| `profile_email` | String | E-mail da gestante |
| `profile_due_date` | String (ISO) | Data prevista do parto |

---

### 3.2 Camada de API (`backend_api.dart`)

Cliente HTTP tipado para comunicação com o backend NestJS.

**Classe principal:** `BackendApi`  
**URL padrão:** `http://10.0.2.2:3000` (emulador Android) — configurável via `API_BASE_URL`  
**Timeout:** 12 segundos por requisição

**Métodos disponíveis:**

| Método | HTTP | Endpoint | Auth |
|--------|------|----------|------|
| `register()` | POST | `/users/register` | Não |
| `login()` | POST | `/auth/login` | Não |
| `profile()` | GET | `/users/profile` | Bearer JWT |

**Tratamento de erros:**
- `ApiClientException`: exceção tipada com mensagem em português
- `TimeoutException`: detectado e traduzido para mensagem amigável
- `SocketException`: detectado quando backend inacessível
- Resposta de erro do servidor: mensagem extraída do envelope `{ "error": { "message": "..." } }`

---

### 3.3 Integração ViaCEP (`viacep_service.dart`)

Consulta endereço a partir de CEP brasileiro via API pública `viacep.com.br`.

**Timeout:** 8 segundos  
**Retorno:** `Map<String, String>` com chaves `street`, `neighborhood`, `city`, `state`  
**Erros tratados:** CEP inválido, CEP não encontrado, timeout, falha de rede

---

### 3.4 Fonte de Dados do Dashboard (`home_dashboard_data_source.dart`)

Abstração com padrão **Strategy** para o Dashboard da Home:

```
HomeDashboardDataSource (abstract)
├── MockHomeDashboardDataSource    # Dados estáticos para dev/testes
└── ApiHomeDashboardDataSource     # Combina API backend + fallback local
```

O `ApiHomeDashboardDataSource`:
1. Tenta buscar perfil via `GET /users/profile`
2. Atualiza `AppSession` com dados do servidor
3. Em caso de erro ou sem token: usa dados locais do `AppSession`
4. Última linha de fallback: `MockHomeDashboardDataSource`

---

## 4. Roteamento e Telas

```dart
routes: {
  '/':              WelcomeScreen,          // Boas-vindas (não autenticado)
  '/signup':        SignupScreen,           // Cadastro com validação completa
  '/login':         LoginScreen,            // Login
  '/home':          MainAppNavigation,      // Shell de navegação (4 abas)
  '/questionnaire': QuestionnaireScreen,    // Triagem de saúde
  '/processing':    ProfileProcessingScreen,// Processando perfil de risco
  '/safe-path':     SafePathResultScreen,   // Resultado: risco controlado
  '/high-alert':    HighAlertResultScreen,  // Resultado: alerta elevado
  '/daily-log':     DailyLogScreen,         // Diário de sintomas
  '/education':     EducationalArticlesScreen, // Artigos educativos
  '/baby-week':     BabyWeekPlannerScreen,  // Planejamento por semana
  '/nutrition':     NutritionTipsScreen,    // Dicas nutricionais
  '/notifications': NotificationCenterScreen, // Central de notificações
}
```

**Decisão de rota inicial:**
```dart
initialRoute: AppSession.isAuthenticated ? '/home' : '/',
```

---

## 5. Telas Implementadas

### 5.1 WelcomeScreen
Tela de entrada com identidade visual do Maternar. Oferece acesso a criação de conta e login.

### 5.2 SignupScreen
Formulário de cadastro completo com:
- Validação em tempo real de cada campo
- Medidor de força de senha (4 critérios visuais)
- Máscara de telefone automática
- Integração ViaCEP com autocomplete e toggle manual/automático
- Date picker para data prevista do parto
- Fluxo pós-cadastro: cadastrar → login automático → sincronizar perfil → ir para home

### 5.3 LoginScreen
Formulário simples de e-mail e senha com fluxo pós-login de sincronização de perfil.

### 5.4 MainAppNavigation
Shell de navegação com `BottomNavigationBar` de 4 abas:
- **Home** (`HomeDashboardScreen`)
- **Saúde** (`HealthMetricsScreen`)
- **Consultas** (`ConsultationHistoryScreen`)
- **Perfil** (`ProfileSettingsScreen`)

### 5.5 HomeDashboardScreen
Dashboard personalizado com:
- Saudação com nome e semana gestacional
- Card de perfil de saúde com acesso ao questionário
- Cards de status: semana atual + tamanho do bebê, dias para o parto
- Dicas diárias com ícones e navegação contextual
- Ações rápidas (Diário, Biblioteca)
- Artigo recomendado em destaque

### 5.6 HealthMetricsScreen
Métricas de saúde com cards visuais (pressão arterial, peso, glicemia, tamanho do bebê) e entrada manual via bottom sheet.

### 5.7 ConsultationHistoryScreen
Histórico e próximas consultas com status visual (realizada/agendada) e FAB para agendamento.

### 5.8 ProfileSettingsScreen
Perfil com edição inline de nome, e-mail e data de parto, preferências de notificação e botão de logout com confirmação.

### 5.9 DailyLogScreen
Diário de sintomas com:
- Slider de humor (1-5 escala)
- FilterChips para seleção de sintomas
- Campo de observação livre
- Lista dos últimos registros

### 5.10 EducationalArticlesScreen, NutritionTipsScreen, BabyWeekPlannerScreen, NotificationCenterScreen
Telas de conteúdo educativo e informativo. Dados estáticos no momento, prontos para integração com API de conteúdo.

---

## 6. Identidade Visual (GestCareColors)

| Token | Cor Hex | Uso |
|-------|---------|-----|
| `deepTeal` | `#0C7A71` | Cor primária, botões, ícones ativos |
| `mint` | `#BEEDE1` | Backgrounds suaves, borders |
| `softMint` | `#D9EEE9` | Fundos de seções |
| `cream` | `#F6EFE5` | Backgrounds quentes |
| `peach` | `#F8C9AF` | Avatares, destaques quentes |
| `coral` | `#F6AA8C` | Alertas, botão de logout |
| `background` | `#F4F7F5` | Fundo global do app |
| `textPrimary` | `#173831` | Texto principal |
| `textMuted` | `#6B8A83` | Texto secundário |

**Tipografia:** Google Fonts — `DM Sans` (body) + `Playfair Display` (headings de boas-vindas)

---

## 7. Fluxo de Autenticação

```
Início do App
    │
    ▼
AppSession.init()
    │
    ├── isAuthenticated? ─── Sim ──► /home (MainAppNavigation)
    │
    └── Não ──► / (WelcomeScreen)
                    │
              ┌─────┴─────┐
              │           │
           /signup       /login
              │           │
              ▼           ▼
         cadastrar      login (POST /auth/login)
              │           │
         login auto      saveToken()
              │           │
         saveToken()   syncProfile (GET /users/profile)
              │           │
         syncProfile      │
              │           │
              └─────┬─────┘
                    ▼
             /home (remove histórico de rota)
```

---

## 8. Dependências

| Pacote | Versão | Finalidade |
|--------|--------|-----------|
| `google_fonts` | ^6.2.1 | Tipografia (DM Sans, Playfair Display) |
| `http` | ^1.2.2 | Cliente HTTP para API e ViaCEP |
| `shared_preferences` | ^2.3.2 | Persistência local (token, perfil) |
| `cupertino_icons` | ^1.0.8 | Ícones iOS |
| `flutter_lints` | ^5.0.0 | Análise estática de código |

---

## 9. Configuração por Plataforma

### Android
**Mínimo SDK:** Definido no `build.gradle.kts`  
**HTTP em debug:** `android/app/src/debug/AndroidManifest.xml` permite tráfego HTTP para emulador  
**Importante:** Em produção, configurar `network_security_config.xml` para bloquear HTTP

### iOS
Configuração padrão Flutter. Para produção, revisar `Info.plist` para `NSAppTransportSecurity`.

### Web
PWA configurado em `web/manifest.json` e `web/index.html`.

---

## 10. Testes

```bash
flutter analyze            # Análise estática (lint)
flutter test               # Testes de widget
flutter test --coverage    # Com cobertura
```

Testes atuais: `test/widget_test.dart` (smoke test inicial)

---

## 11. Execução Local

```bash
# Verificar ambiente
flutter doctor

# Instalar dependências
flutter pub get

# Listar dispositivos
flutter devices

# Executar (exemplo: emulador Android)
flutter run -d emulator-5554

# Build de release Android
flutter build apk --release

# Build de release com obfuscação (recomendado)
flutter build apk --obfuscate --split-debug-info=build/symbols
```

---

## 12. Pendências e Próximos Passos

- [ ] Migrar `SharedPreferences` para `flutter_secure_storage` (dados sensíveis)
- [ ] Implementar lógica de refresh de token JWT
- [ ] Implementar questionário de triagem com envio ao backend
- [ ] Conectar tela de resultados (`/safe-path`, `/high-alert`) com dados reais do cluster
- [ ] Implementar persistência do diário de sintomas no backend
- [ ] Adicionar testes de integração para fluxo de cadastro e login
- [ ] Configurar CI/CD com `flutter analyze` e `flutter test`
- [ ] Obfuscação e análise de segurança para build de release
- [ ] Internacionalização (i18n) com `flutter_localizations`
- [ ] Acessibilidade: revisar semântica de widgets para leitores de tela
