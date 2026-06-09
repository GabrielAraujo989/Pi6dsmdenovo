# Maternar — Pitch de Apresentação

> **Roteiro com três apresentadores · ~15 minutos no total (5 min cada)**
> Cada seção contém o texto sugerido, gráficos e tabelas de apoio visual.

---

## ABERTURA — todos juntos (~1 min)

> *Falar em uníssono ou revezar frases curtas*

O Brasil perde mais de **1.700 mães por ano** em mortes consideradas evitáveis.
O problema não é falta de dado — o Ministério da Saúde coleta tudo isso há décadas.
O problema é que esse dado **nunca chegou até a gestante**.

O **Maternar** muda isso.
Cruzamos cinco bases públicas do SUS, treinamos um modelo em cima de **378.969 gestações reais**
e devolvemos para cada gestante, no celular, em linguagem humana, o que ela precisa saber.

---
---

## GABRIEL — ApiDatasus: de onde vem a inteligência (~5 min)

> *"Vou explicar de onde vem a inteligência do sistema — do dado bruto ao modelo que roda em produção."*

---

### 1. O ponto de partida: os dados do SUS

Não partimos do zero.
Partimos de **cinco bases públicas do DATASUS** — o repositório de saúde pública do Ministério da Saúde:

| Base | O que contém | Granularidade | Registros no banco |
|------|-------------|---------------|--------------------|
| **SISVAN** | Peso, altura, IMC e estado nutricional de gestantes | Individual | 1.201.675 |
| **SINAN** | Notificações de sífilis gestacional por município | Município/ano | 1.322.606 |
| **SIM** | Óbitos maternos por CID-10 (O00–O99) | Município/ano | 15.711.535 |
| **SIA** | Produção ambulatorial — consultas de pré-natal | Município/ano | 20.477.352 |
| **CNES** | Hospitais e leitos por município | Município/ano | 8.528.568 |
| **TOTAL** | — | — | **47.241.736** |

```
VOLUME BRUTO DE DADOS (47 milhões de registros)
─────────────────────────────────────────────────
SIA   ████████████████████████  20,4 mi  (43%)
SIM   ████████████████████      15,7 mi  (33%)
CNES  ██████████                 8,5 mi  (18%)
SINAN ██                         1,3 mi  (3%)
SISVAN██                         1,2 mi  (3%)
─────────────────────────────────────────────────
```

> O SISVAN é a base individual — só ele tem os dados de cada gestante.
> As outras quatro são **contexto do município** — cruzamos tudo pela chave `(cod_municipio_ibge, ano)`.

---

### 2. Do dado bruto ao dataset de treinamento

Nem todo registro serve para treinar o modelo.
O SISVAN tem **1.201.675 registros**, mas passamos por um funil rigoroso de qualidade:

```
FUNIL DE LIMPEZA E FILTRAGEM
══════════════════════════════════════════════════════

 SISVAN bruto (total no banco)
 ┌──────────────────────────────────────────────────┐
 │              1.201.675 registros                 │
 └───────────────────────┬──────────────────────────┘
                         │  Filtro temporal (2014–2016)
                         ▼
 ┌──────────────────────────────────────────────────┐
 │         ~384.795 registros no período            │
 └───────────────────────┬──────────────────────────┘
                         │  Limpeza biológica:
                         │  • IMC < 10 ou > 80  → removido
                         │  • Altura < 1,30 m   → removido
                         │  • Altura > 2,15 m   → removido
                         │  5.826 registros removidos
                         ▼
 ┌──────────────────────────────────────────────────┐
 │  Linkage com SINAN + SIM + SIA + CNES            │
 │  por (cod_municipio_ibge, ano)                   │
 └───────────────────────┬──────────────────────────┘
                         │
                         ▼
 ╔══════════════════════════════════════════════════╗
 ║       378.969 gestantes — dataset final          ║
 ║       2.573 municípios cobertos                  ║
 ╚══════════════════════════════════════════════════╝
```

**Por que essa diferença?**

- O filtro temporal restringe ao período **2014–2016** — única janela onde todos os cinco sistemas têm cobertura nacional completa.
- A limpeza biológica remove **5.826 registros** com valores impossíveis (IMC de 80 seria fatal; altura de 1 metro adulta não existe).
- O linkage descarta gestantes de municípios sem ao menos uma base municipal mapeada — sem esse dado, o vetor de features estaria incompleto.

---

### 3. As 20 features do modelo

Para cada gestante, montamos um vetor com **20 dimensões**:

```
COMPOSIÇÃO DO VETOR DE 20 FEATURES
─────────────────────────────────────────────────────────
CONTÍNUAS (9)          NUTRIÇÃO (4)          RAÇA/COR (5)
───────────────────    ──────────────────    ─────────────
• IMC atual            • Baixo peso          • Branca
• IMC pré-gestacional  • Adequado            • Preta
• Ganho de IMC         • Sobrepeso           • Amarela
• Peso (kg)            • Obesidade           • Parda
• Altura (m)                                 • Indígena
• log(taxa sífilis)    FLAGS (2)
• Hospitais/município  ──────────────────
• log(cobertura        • flag_anti_hiv
  pré-natal)           • tem_dado_sia
• Escolaridade
─────────────────────────────────────────────────────────
```

> As variáveis municipais — sífilis, hospitais, cobertura pré-natal — **não são coletadas no app**.
> O backend injeta automaticamente a partir do código IBGE do CEP da gestante.

---

### 4. Pré-processamento: por que não usamos StandardScaler

Antes do K-Means, os dados passam por **duas etapas**:

**Etapa 1 — RobustScaler**

```
StandardScaler    ←  usa média + desvio padrão  →  1 gestante com IMC 80
                                                    distorce o modelo inteiro

RobustScaler      ←  usa mediana + IQR          →  outliers extremos têm
                                                    peso reduzido ✓
```

Dados epidemiológicos têm outliers mesmo após capping. O RobustScaler foi a escolha correta.

**Etapa 2 — PCA com 8 componentes**

```
20 features  →  PCA (90% variância)  →  8 componentes

PC1: 29% da variância  ───────────────────────
PC2: 14% da variância  ──────────
PC3–PC8: restante      (complementar)
Acumulado: 90,0%       ✓
```

Reduzir de 20 para 8 dimensões torna o modelo mais rápido e evita que variáveis correlacionadas (como peso e IMC) contem duas vezes.

---

### 5. Escolha do K: por que três grupos?

Testamos **K=3 vs K=4** em quatro algoritmos diferentes:

| Algoritmo | Silhouette K=3 | Silhouette K=4 | Vencedor |
|-----------|---------------|---------------|----------|
| **K-Means** | **0,2873** | 0,2139 | K=3 |
| Agglomerative Ward | **0,2692** | 0,1930 | K=3 |
| GMM (full covariance) | **0,2718** | 0,1995 | K=3 |
| Mini-Batch K-Means | **0,2001** | 0,2142 | K=3 |

```
CRITÉRIOS DE SELEÇÃO — K=3 vence em 3/3
──────────────────────────────────────────────
Silhouette   (maior = melhor):  K=3 ✓   K=4 ✗
Calinski-H.  (maior = melhor):  K=3 ✓   K=4 ✗
Davies-Bouldin (menor = melhor): K=3 ✓  K=4 ✗
──────────────────────────────────────────────
```

Além da métrica, K=3 tem vantagem clínica: **3 alertas são acionáveis**. 4 ou mais criam confusão para a gestante e para o sistema de saúde.

---

### 6. Os três perfis resultantes

```
DISTRIBUIÇÃO DOS CLUSTERS — 378.969 gestantes
═══════════════════════════════════════════════════════════
C1 — Caminho Seguro      ██████████████████████████  71,2%
     (Eutrofia/Baixo Peso)       269.787 gestantes
     IMC atual: 24,6 | IMC pré: 22,7 | Hospitais: 2,0

C0 — Cuidado Integral    ████████                    27,3%
     (Obesidade Gestacional)     103.418 gestantes
     IMC atual: 34,0 | IMC pré: 31,0 | Hospitais: 2,0

C2 — Atenção Redobrada   ▌                            1,5%
     (Acesso Diferenciado)         5.764 gestantes
     IMC atual: 26,7 | IMC pré: 24,9 | Hospitais: 8,6 ← referência
═══════════════════════════════════════════════════════════
```

> **C2 é o mais crítico:** gestantes em municípios com 8,6 hospitais por município (vs. 2,0 da média nacional) — são gestações de alto risco encaminhadas para centros de referência, com taxa de sífilis gestacional levemente superior.

---

### 7. Métricas de validação

| Métrica | Valor | Interpretação |
|---------|-------|--------------|
| **Silhouette Score** | **0,2873** | Bom para dados epidemiológicos (>0,2) |
| **Calinski-Harabász** | **102.169** | Clusters bem separados |
| **Davies-Bouldin** | **1,188** | Baixa sobreposição entre grupos |
| **ARI hold-out 10%** | **0,999** | Quase idêntico ao modelo completo |
| **IC 95% Bootstrap (30 amostras)** | **[0,285 – 0,290]** | Alta estabilidade |
| **Desvio padrão (20 seeds)** | **< 0,0001** | Determinístico na prática |

```
ESTABILIDADE BOOTSTRAP (30 amostras × 90% dos dados)
──────────────────────────────────────────────────────
0.285  0.286  0.287  0.288  0.289  0.290
  ├──────────[══════════════]──────────┤
             IC 95% do Silhouette
             σ < 0,001  →  muito estável
──────────────────────────────────────────────────────
```

---

### 8. O Worker de inferência

Todo o pipeline treina offline e resulta em **três arquivos `.pkl`**:
`kmeans_k3.pkl` · `scaler_maternar.pkl` · `pca_maternar.pkl`

Em produção, um **Worker Python com Flask e scikit-learn** carrega esses artefatos uma única vez na memória. Para classificar uma nova gestante:

```
FLUXO DE INFERÊNCIA (< 200 ms)
────────────────────────────────────────────────────────
  Payload da gestante
  {peso, altura, imc_pré, raça, escolaridade}
              │
              ▼
  Backend injeta cod_municipio (via CEP → IBGE)
  + busca {sifilis, hospitais, pré-natal} no banco
              │
              ▼
  Monta vetor de 20 features
              │
    ┌─────────▼─────────┐
    │   RobustScaler    │  normaliza 9 contínuas
    └─────────┬─────────┘
              │
    ┌─────────▼─────────┐
    │    PCA (8 comp.)  │  reduz de 20 para 8 dim.
    └─────────┬─────────┘
              │
    ┌─────────▼─────────┐
    │  KMeans.predict() │  → cluster 0, 1 ou 2
    └─────────┬─────────┘
              │
              ▼
  {cluster_id, nome_app, nivel_risco, cor, recomendações}
────────────────────────────────────────────────────────
```

---
---

## GUILHERME — Backend e Banco de Dados: a espinha dorsal (~5 min)

> *"Vou mostrar como tudo isso é organizado e servido com segurança para o app."*

---

### 1. A stack e por que escolhemos cada peça

```
STACK DO BACKEND
─────────────────────────────────────────────────────
NestJS 11      → Framework TypeScript estruturado
               → Injeção de dependência nativa
               → Guards, Interceptors, Pipes prontos

Prisma 7       → ORM com schema tipado
               → Migrations controladas
               → Auto-complete nas queries

PostgreSQL 16  → Banco relacional robusto
               → Suporte a múltiplos schemas
               → ACID: sem inconsistência de dados

JWT + bcrypt   → Autenticação stateless
               → Hash seguro de senhas

RabbitMQ 3.13  → Fila de mensagens (AMQP)
               → Desacopla backend do Worker ML
─────────────────────────────────────────────────────
```

Escolhemos **NestJS** porque ele força uma arquitetura limpa desde o início — não é possível misturar responsabilidades como acontece em Express puro.
Escolhemos **Prisma** porque o schema é versionado junto com o código — nenhuma mudança de banco passa desapercebida.

---

### 2. Arquitetura em três camadas (Clean Architecture)

```
MÓDULO NESTJS — EXEMPLO: users/
══════════════════════════════════════════════════════
  HTTP Layer              Application Layer      Infra Layer
  ─────────────────────   ──────────────────     ────────────
  UserController          UserService            DatabaseService
  • Valida DTO            • Lógica de negócio    • PrismaClient
  • Extrai @CurrentUser   • Chama integrations   • Queries SQL
  • Retorna HTTP code     • Lança ApiException   • Schemas

  UserDto                 ViaCepService
  • class-validator       • Consulta CEP externo
  • Mensagens PT-BR       • Timeout: 5s
  • Tipagem estrita       • Tolerante a falha
══════════════════════════════════════════════════════
```

---

### 3. Módulos e o que cada um faz

| Módulo | Responsabilidade | Detalhe técnico |
|--------|-----------------|-----------------|
| **`auth/`** | Login com JWT | Token expira em **7 dias** — gestante do SUS não pode perder acesso toda semana |
| **`users/`** | Cadastro e perfil | Consulta **ViaCEP** no registro; extrai código IBGE do município para o modelo de ML |
| **`pregnancies/`** | Ciclo gestacional | Recebe a DUM, calcula **DPP = DUM + 280 dias** automaticamente |
| **`questionnaires/`** | Histórico de avaliações | Persiste cada check-in com cluster, risco e recomendações |
| **`classification/`** | Aciona o Worker ML | Monta payload + envia para RabbitMQ + persiste resultado |
| **`integrations/`** | Serviços externos | ViaCEP (timeout 5s) e RabbitMQ RPC (timeout 10s) |

---

### 4. Os endpoints da API

```
API REST — MATERNAR BACKEND
════════════════════════════════════════════════════════════

  AUTENTICAÇÃO
  POST  /auth/login              → JWT (7 dias)

  USUÁRIOS
  POST  /users/register          → Cria conta + lookup CEP automático
  GET   /users/profile           → Retorna perfil completo
  PATCH /users/profile           → Atualiza dados parcialmente

  GESTAÇÕES
  POST  /pregnancy/create        → Inicia ciclo gestacional (DUM → DPP)
  GET   /pregnancy               → Lista todas as gestações

  QUESTIONÁRIOS
  POST  /questionnaires/:id/submit → Envia check-in → ML → persiste
  GET   /questionnaires/pregnancy/:id → Histórico de avaliações

  CLASSIFICAÇÃO DIRETA
  POST  /classification          → Classifica perfil via RabbitMQ

════════════════════════════════════════════════════════════
```

---

### 5. O banco de dados: schema e relacionamentos

O banco usa **PostgreSQL 16** com **dois schemas separados**:
- **`app`** — dados da aplicação (usuários, gestações, check-ins)
- **`ml_maternar`** — features municipais para inferência em tempo real

```
SCHEMA DO BANCO (schema: app)
══════════════════════════════════════════════════════════
  users                        user_locations
  ─────────────────────        ──────────────────────────
  id (UUID)                    id (UUID)
  name                         userId ──────────── users.id
  email (unique)               city
  password (bcrypt)            state
  weight                       ibgeCode  ← chave para ML
  height                       zipCode
  phone
  education_level (1–5)             ▼ usado em classificação
  race_color (1–5)         ml_maternar.municipio_features
  created_at               cod_municipio ← ibgeCode
                           log_taxa_sifilis_gest
         │                 cnes_hospitais
         │                 cobertura_prenatal_log
  pregnancies
  ─────────────────────
  id (UUID)
  userId ──────────────── users.id
  dum (Data Última Mens.)
  dpp (= dum + 280 dias)
  status (ACTIVE | COMPLETED | INTERRUPTED)
         │
  questionnaire_responses
  ─────────────────────────────────────────────
  id (UUID)
  pregnancyId ──────────── pregnancies.id
  nu_peso, nu_imc_pre, flag_anti_hiv
  cluster_id (0/1/2)
  cluster_nome_app
  nivel_risco
  cor_hex
  recomendacoes (JSON array)
  created_at
══════════════════════════════════════════════════════════
```

O schema Prisma está dividido em **4 arquivos separados**:
`user.prisma` · `pregnancy.prisma` · `questionnaire.prisma` · `location.prisma`

Isso torna cada mudança de banco **cirúrgica e auditável** no git — em vez de um arquivo monolítico de 300 linhas.

---

### 6. Envelope de erro padronizado

Toda mensagem de erro da API segue o mesmo contrato:

```json
{
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "E-mail ou senha incorretos."
  }
}
```

**Códigos implementados:**
`INVALID_CREDENTIALS` · `TOKEN_EXPIRED` · `TOKEN_MISSING` · `USER_NOT_FOUND`
`EMAIL_ALREADY_EXISTS` · `INVALID_ZIP_CODE` · `CLASSIFICATION_TIMEOUT` · `PREGNANCY_NOT_FOUND`

O frontend **nunca recebe um erro sem estrutura**. Isso eliminou uma classe inteira de bugs de UI durante o desenvolvimento.

---

### 7. Infraestrutura: tudo em container

```
DOCKER COMPOSE — subir com um único comando
══════════════════════════════════════════════════════════

  $ docker compose up

  ┌──────────────────────────────────────────────────┐
  │  postgres (maternar_postgres)                    │
  │  image: postgres:16                              │
  │  porta: 5490 → banco: gestasus_db                │
  │  healthcheck: pg_isready (5 tentativas)          │
  ├──────────────────────────────────────────────────┤
  │  rabbitmq (maternar_rabbitmq)                    │
  │  image: rabbitmq:3.13-management-alpine          │
  │  porta 5672 (AMQP) + 15672 (UI de gerenciamento) │
  ├──────────────────────────────────────────────────┤
  │  worker (maternar_worker)                        │
  │  build: ./ApiDatasus/flask_api/                  │
  │  depende de: postgres ✓ + rabbitmq ✓             │
  └──────────────────────────────────────────────────┘

  Em produção: HTTPS via túnel Cloudflare
  Sem configurar certificado SSL manualmente.
══════════════════════════════════════════════════════════
```

---
---

## SHEILA — Frontend e Mensageria: o que a gestante vê (~5 min)

> *"Vou falar sobre a experiência da gestante no app e sobre a decisão técnica mais importante do sistema."*

---

### 1. Por que Flutter

```
FLUTTER → um código, dois alvos
─────────────────────────────────────────────────────
  código único em Dart
       │
       ├──→  APK Android   ← instala direto, sem Play Store
       └──→  Web (PWA)     ← acessível em qualquer navegador
─────────────────────────────────────────────────────
```

Para o público do SUS isso é decisivo: a gestante não precisa de iPhone, não precisa de plano com dados ilimitados, não precisa de Google Play. O APK instala direto.

---

### 2. A jornada completa da gestante

```
FLUXO DE TELAS
══════════════════════════════════════════════════════════════
  /welcome         Tela inicial com logo e CTA
       │
       ├──→ /signup   Cadastro completo
       │             • Nome, e-mail, senha
       │             • CEP → preenche cidade/estado automaticamente (ViaCEP)
       │             • Data prevista do parto, raça/cor, escolaridade
       │             • Medidor de força de senha em tempo real
       │
       └──→ /login    Login com e-mail + senha

  /home  (4 abas)
  ┌─────────┬──────────────┬─────────────────┬──────────────┐
  │  Home   │   Saúde      │   Consultas      │   Perfil     │
  │Dashboard│  Métricas    │   Histórico      │  Configurações│
  └─────────┴──────────────┴─────────────────┴──────────────┘
      │
      ├── Semana atual da gestação
      ├── Dias restantes para o parto
      ├── Tamanho do bebê na semana
      ├── Dicas organizadas por categoria
      └── Atalho para questionário

  /questionnaire  → Coleta: peso, altura, IMC pré, raça, escolaridade
       │
  /processing     → Tela de espera enquanto o ML processa
       │
       ├──→ /safe-path    Cluster 1 "Caminho Seguro"
       │                  Orientações de rotina em linguagem acolhedora
       │
       └──→ /high-alert   Cluster 0 "Cuidado Integral"
                          Cluster 2 "Atenção Redobrada"
                          Alertas + encaminhamentos específicos
══════════════════════════════════════════════════════════════
```

---

### 3. Funcionalidades por tela

**Dashboard Principal** (`/home`)
- Semana gestacional calculada automaticamente pela DUM
- Tamanho estimado do bebê na semana atual
- Dicas do dia organizadas por categoria
- Acesso rápido ao diário e à biblioteca de conteúdo

**Métricas de Saúde** (`/health`)
- Cards de pressão arterial, peso, glicemia, tamanho fetal
- Entrada manual de medições via bottom sheet
- Histórico visual por período

**Histórico de Consultas** (`/consultations`)
- Linha do tempo de todas as classificações anteriores
- Data, cluster, nível de risco, cor e primeira recomendação de cada avaliação

**Perfil e Configurações** (`/profile`)
- Editar nome, e-mail e data prevista do parto
- Preferências de notificação
- Confirmação de logout (evita saída acidental)

**Conteúdo Educacional** (acessível do dashboard)
- `/education` — Artigos por categoria
- `/baby-week` — Planner semanal do bebê
- `/nutrition` — Dicas nutricionais
- `/notifications` — Central de notificações

---

### 4. Design: seriedade sem parecer clínico

```
PALETA DE CORES — GestCareColors
─────────────────────────────────────────────────────
  Primary    #0C7A71  deepTeal   ← seriedade + acolhimento
  Mint       #BEEDE1             ← fundo de cards suaves
  Cream      #F6EFE5             ← background principal
  Peach      #F8C9AF             ← destaques quentes
  TextPrimary #173831            ← texto escuro legível
─────────────────────────────────────────────────────
  Tipografia:
  Corpo →    DM Sans        (moderna, legível em telas pequenas)
  Títulos →  Playfair Display (transmite cuidado, não frieza)
─────────────────────────────────────────────────────
```

Cada detalhe foi escolhido para a gestante do SUS: fonte grande, cores que não assustam, linguagem que orienta sem alarmar.

---

### 5. Integração com o backend

```
COMUNICAÇÃO FLUTTER → NESTJS
══════════════════════════════════════════════════════════
  BackendApi (backend_api.dart)
  • Timeout: 12 segundos
  • Base URL via variável de ambiente
  • Token JWT no header: Authorization: Bearer <token>

  AppSession (app_session.dart)
  • SharedPreferences: auth_token, profile_name,
    profile_email, profile_due_date
  • Estado global da sessão (sem BLoC / sem Provider)

  ViaCepService (viacep_service.dart)
  • Timeout: 8 segundos
  • Fallback tolerante: não bloqueia o cadastro
══════════════════════════════════════════════════════════
```

---

### 6. Por que usamos RabbitMQ — a decisão técnica mais importante

Quando a gestante envia o questionário, o backend precisa acionar o Worker Python para rodar o modelo.
A opção simples seria uma **chamada HTTP direta**. Escolhemos não fazer isso.

```
OPÇÃO A: HTTP DIRETO (descartada)
────────────────────────────────────────────────────────
  Flutter → NestJS → HTTP → Worker Python
                      │
                    thread do NestJS BLOQUEADO
                    se Worker demorar 15s → timeout
                    se Worker cair → requisição perdida
────────────────────────────────────────────────────────

OPÇÃO B: RABBITMQ (implementado)
────────────────────────────────────────────────────────
  Flutter → NestJS ──publica──→ [ fila maternar.classificar ]
               │                         │
          libera thread         Worker consome
          imediatamente         processa ML
               │                         │
               └──←──resposta via reply_to←──┘
────────────────────────────────────────────────────────
```

**Três razões concretas para a fila:**

```
1. DESEMPENHO
   RabbitMQ libera o thread do NestJS imediatamente.
   O Worker processa em background.
   O app não trava esperando o modelo carregar.

2. RESILIÊNCIA
   Worker caiu? A mensagem permanece no broker.
   Quando o Worker voltar, processa normalmente.
   Dead Letter Queue (maternar.classificar.dlq)
   captura mensagens que expiraram — nenhuma classificação é perdida.

3. DESACOPLAMENTO
   NestJS não sabe o que acontece do outro lado da fila.
   Amanhã trocamos K-Means por Gradient Boosting,
   ou rodamos dois Workers em paralelo,
   sem tocar uma linha do backend.
```

---

### 7. O padrão RPC sobre AMQP

```
FLUXO RPC DETALHADO
══════════════════════════════════════════════════════════

  NestJS ClassificationService:
  ┌─────────────────────────────────────────────────────┐
  │  1. Gera correlation_id (UUID único)                │
  │  2. Cria fila de resposta temporária                │
  │  3. Publica em "maternar.classificar":              │
  │     { payload, reply_to: fila_temp, correlation_id }│
  │  4. Aguarda resposta (timeout: 10 segundos)         │
  └─────────────────────────────────────────────────────┘
              │                       ▲
              ▼                       │
  Worker Python:                      │
  ┌─────────────────────────────────────────────────────┐
  │  1. Consome mensagem da fila                        │
  │  2. Extrai payload + correlation_id                 │
  │  3. Executa: Scaler → PCA → KMeans.predict()        │
  │  4. Publica resultado em reply_to                   │
  │     com o mesmo correlation_id                      │
  └─────────────────────────────────────────────────────┘

  TTL da mensagem: 30 segundos
  Timeout NestJS: 10 segundos → HTTP 503 CLASSIFICATION_TIMEOUT
  DLQ: maternar.classificar.dlq (mensagens que expiraram)
══════════════════════════════════════════════════════════
```

---
---

## CONTEXTO GERAL — Perguntas frequentes e pontos complementares

> *Esta seção pode ser usada por qualquer apresentador para responder perguntas da banca ou aprofundar pontos não cobertos nas seções principais.*

---

### Por que DATASUS de 2014–2016? Não está desatualizado?

**Resposta curta:** É a janela onde todos os cinco sistemas têm cobertura nacional completa.

SISVAN expandiu sua cobertura progressivamente. Registros anteriores a 2014 têm muitos municípios sem dados de raça/cor e escolaridade — exatamente as variáveis que diferenciam os clusters. O modelo **pode ser re-treinado** com dados mais recentes quando a cobertura for homogênea. Os artefatos `.pkl` são substituíveis sem tocar o backend ou o app.

---

### Como o app conhece os dados do município da gestante?

1. No cadastro, a gestante informa o **CEP**.
2. O backend consulta a **API ViaCEP** e extrai o código IBGE do município.
3. Esse código é salvo em `user_locations.ibgeCode`.
4. Quando a gestante envia o questionário, o `ClassificationService` busca `log_taxa_sifilis_gest`, `cnes_hospitais` e `cobertura_prenatal_log` na tabela `ml_maternar.municipio_features` usando o código IBGE.
5. Esses dados são **injetados automaticamente** no payload — a gestante nunca precisa informar nada sobre o município.

---

### O sistema é seguro?

```
SEGURANÇA IMPLEMENTADA
─────────────────────────────────────────────────────
✓ Senhas com bcrypt (salt rounds: padrão)
✓ JWT stateless — servidor não guarda sessão
✓ Guard em todos os endpoints autenticados
✓ DTOs com class-validator — rejeita payload malformado
✓ HTTPS em produção (Cloudflare tunnel)
✓ Envelope de erro padronizado — não vaza stack trace
✓ ViaCEP com timeout — não bloqueia em falha externa
✓ RabbitMQ com DLQ — mensagens não desaparecem silenciosamente
─────────────────────────────────────────────────────
```

---

### Qual é o fluxo completo de ponta a ponta?

```
FLUXO COMPLETO — DO CEP AO RESULTADO
════════════════════════════════════════════════════════════════════
  GESTANTE                FLUTTER            NESTJS          WORKER
  ──────────              ───────            ──────          ──────
  informa CEP    →   POST /users/register → ViaCEP API
                                          ← salva ibgeCode

  preenche       →   POST /classification  → busca municipio_features
  questionário                             → publica na fila ──────→
                                           ←── resultado        ←──
                   ← exibe resultado      ← persiste check-in
  vê cluster,
  recomendações
════════════════════════════════════════════════════════════════════
```

---

### Quais são os próximos passos técnicos?

| Prioridade | Item | Justificativa |
|-----------|------|--------------|
| Alta | Refresh token rotation | Token de 7 dias precisa de rotação segura |
| Alta | Rate limiting (`@nestjs/throttler`) | Endpoints `/auth/login` e `/users/register` estão expostos |
| Alta | `flutter_secure_storage` | JWT no SharedPreferences não é cifrado no Android |
| Média | Endpoints LGPD | `/users/my-data` (download) e `DELETE /users/me` |
| Média | Re-treino com dados 2019–2024 | Melhorar cobertura geográfica do modelo |
| Baixa | Push notifications | Lembretes de consulta pré-natal |

---

### Qual foi a divisão do trabalho?

| Integrante | Responsabilidade principal |
|------------|---------------------------|
| **Gabriel** | Pipeline KDD, extração e limpeza dos 47M+ registros DATASUS, treinamento K-Means, Worker Flask de inferência |
| **Guilherme** | Backend NestJS completo, schema Prisma, integração RabbitMQ, infraestrutura Docker |
| **Sheila** | App Flutter completo, design system, integração API, RabbitMQ no contexto do app |

---

## ENCERRAMENTO — todos juntos (~1 min)

O Maternar não inventou dado.
Os dados já existiam nos sistemas do SUS há mais de uma década —
**47 milhões de registros** esperando ser usados.

O que fizemos foi:
- Cruzar **cinco bases** por município e ano
- Treinar um modelo em cima de **378.969 gestações reais**
- Embalar em uma **API segura com fila de mensagens**
- Entregar numa interface que **uma gestante com acesso básico à internet consegue usar**

A stack é aberta, containerizada e documentada.
**Escala. Pode ser auditada. Pode ser continuada.**

**Obrigado.**

---

*Maternar — Acompanhamento preventivo para uma gestação tranquila.*

`Flutter 3.8 (Android + Web)` · `NestJS 11 + PostgreSQL 16 + Prisma 7` · `Python 3.12 Flask + scikit-learn` · `RabbitMQ 3.13` · `Docker Compose`
