# 08 - Especificação Técnica: Backend (NestJS & Flask)

> **Última atualização:** 2026-06-07
> **Status:** Todos os módulos implementados — Auth · Users · Pregnancies · Questionnaires · Classification (RabbitMQ)

---

## 1. Visão Geral

O backend do **Maternar** é composto por dois serviços para separar a lógica de negócio
da lógica de inteligência artificial:

- **NestJS**: gerenciamento de usuárias, autenticação, persistência, proxy para o Worker de IA
- **Flask (Python)**: inferência do K-Means K=3, normalização, classificação de risco

### 1.1 Endpoints Implementados

| Método | Endpoint | Descrição | Auth |
|--------|----------|-----------|------|
| POST | `/auth/login` | Autenticação JWT | Não |
| POST | `/users/register` | Cadastro de gestante + ViaCEP | Não |
| GET | `/users/profile` | Perfil completo da usuária autenticada | Bearer JWT |
| PATCH | `/users/profile` | Atualização parcial do perfil | Bearer JWT |
| POST | `/pregnancy/create` | Criar ciclo gestacional | Bearer JWT |
| GET | `/pregnancy` | Listar gestações da usuária | Bearer JWT |
| POST | `/questionnaires/:pregnancyId/submit` | Check-in com classificação IA via RabbitMQ | Bearer JWT |
| GET | `/questionnaires/pregnancy/:pregnancyId` | Histórico de check-ins de uma gestação | Bearer JWT |
| POST | `/classification` | Classificação de perfil gestacional via IA | Bearer JWT |

### 1.2 Endpoints Pendentes (futuras sprints)

| Método | Endpoint | Descrição | Auth |
|--------|----------|-----------|------|
| POST | `/auth/refresh` | Renovar access token | Refresh JWT |
| POST | `/auth/logout` | Revogar refresh token | Bearer JWT |
| GET | `/users/my-data` | Exportar dados pessoais (LGPD) | Bearer JWT |
| DELETE | `/users/me` | Solicitar exclusão de dados (LGPD) | Bearer JWT |

---

## 2. Serviço de Gerenciamento (NestJS)

- **Tecnologia:** NestJS v11 / TypeScript 5
- **Banco de Dados:** PostgreSQL via Prisma 7
- **Responsabilidades implementadas:**
  - Cadastro e autenticação de gestantes (JWT + bcrypt)
  - Enriquecimento geográfico via ViaCEP (armazena ibgeCode em `user_locations`)
  - Gestão de ciclos gestacionais (pregnancies)
  - Check-ins periódicos com classificação IA em tempo real (questionnaires)
  - Classificação direta de perfil gestacional (`classification`)
  - Integração com Worker Flask via RabbitMQ (padrão RPC com correlation_id)

### 2.1 Endpoint de Classificação — Implementado

O fluxo do endpoint `POST /classification`:

1. Autentica a gestante via Bearer JWT
2. Busca dados do perfil (height, preGestationalWeight, raceColor, educationLevel) e `UserLocation.ibgeCode`
3. Cria automaticamente uma gestação ativa se a usuária não tiver nenhuma
4. Publica o payload na fila RabbitMQ `maternar.classificar` (padrão RPC com timeout de 10s)
5. Recebe resposta do Worker Flask e persiste o resultado como QuestionnaireResponse
6. Retorna a classificação completa com recomendações e métricas

**Request (Flutter → NestJS):**
```json
{
  "nu_peso": 72.5,
  "nu_altura": 1.62,
  "nu_imc_pre_gestacional": 24.1,
  "raca_cor": 4,
  "escolaridade": 4,
  "flag_anti_hiv": 0
}
```

**Payload interno (NestJS → Flask):**
```json
{
  "nu_peso": 72.5,
  "nu_altura": 1.62,
  "nu_imc_pre_gestacional": 24.1,
  "raca_cor": 4,
  "escolaridade": 4,
  "cod_municipio": "350950",
  "flag_anti_hiv": 0
}
```

> O `cod_municipio` é preenchido automaticamente pelo NestJS a partir de `user_locations.ibge_code`.  
> A gestante não precisa informar seu município — ele já foi capturado durante o cadastro via CEP → ViaCEP → IBGE.

**Resposta (NestJS → Flutter):** repassa o JSON retornado pelo Flask:
```json
{
  "cluster_id": 1,
  "cluster_nome_app": "Caminho Seguro",
  "nivel_risco": "moderado",
  "cor_hex": "#A8D8EA",
  "recomendacoes": [
    { "categoria": "nutricao", "texto": "Monitorar ganho de peso" },
    { "categoria": "consultas", "texto": "Garantir minimo de 6 consultas pre-natal (SUS)" }
  ]
}
```

### 2.2 Campos do Questionário → Modelo de IA

| Campo coletado no app | Campo enviado ao Flask | Fonte |
|----------------------|----------------------|-------|
| Peso atual (kg) | `nu_peso` | Formulário |
| Peso pré-gestacional (kg) | Calcula `nu_imc_pre_gestacional` | Formulário |
| Altura (cm → m) | `nu_altura` | Formulário |
| Raça/cor (1-5) | `raca_cor` | Formulário |
| Escolaridade (1-5) | `escolaridade` | Formulário |
| CEP → ViaCEP → IBGE | `cod_municipio` | **Backend injeta automaticamente** |

---

## 3. Serviço de Gerenciamento (NestJS)

- **Tecnologia:** NestJS (API Routes) / TypeScript
- **Banco de Dados:** PostgreSQL (schema `app`) via Prisma
- **Responsabilidades:**
  - Cadastro e autenticação de usuárias (JWT)
  - Armazenamento do histórico de questionários e classificações
  - Gestão de dicas e conteúdos de saúde por cluster
  - Agendamento de notificações Push
  - Proxy para a API Flask (centralização das chamadas do App)

---

## 3. Serviço de IA (Flask)

- **Tecnologia:** Flask 3.x / Python 3.12
- **Bibliotecas:** Scikit-learn 1.x, Pandas, Joblib, NumPy, Psycopg2
- **Porta:** 5001 (interna)

### 3.1 Modelos carregados na inicialização

```python
import joblib

# Carregados uma vez no startup do Flask
scaler = joblib.load('models/scaler_maternar.pkl')  # RobustScaler
pca    = joblib.load('models/pca_maternar.pkl')     # PCA 8 componentes
kmeans = joblib.load('models/kmeans_k3.pkl')        # KMeans K=3

CLUSTER_NOMES = {
    0: 'Obesidade Gestacional',
    1: 'Eutrofia / Baixo Peso',
    2: 'Acesso Diferenciado',
}
CLUSTER_RISCO = {0: 'alto', 1: 'moderado', 2: 'atencao'}
```

### 3.2 Pipeline de inferência

```python
def classificar_gestante(dados: dict, municipio_features: dict) -> dict:
    # 1. Calcular features derivadas
    nu_imc = dados['nu_peso'] / (dados['nu_altura'] ** 2)
    ganho_imc = nu_imc - dados['nu_imc_pre_gestacional']

    # 2. One-hot encoding raça/cor
    raca_map = {1: 'branca', 2: 'preta', 3: 'amarela', 4: 'parda', 5: 'indigena'}
    raca_col = raca_map.get(dados['raca_cor'], 'parda')

    # 3. One-hot encoding estado nutricional
    if nu_imc < 18.5:   est_nut = 'baixo_peso'
    elif nu_imc < 25.0: est_nut = 'adequado'
    elif nu_imc < 30.0: est_nut = 'sobrepeso'
    else:               est_nut = 'obesidade'

    # 4. Montar vetor de 20 features (mesma ordem do treino)
    COLS_SCALE = ['nu_imc', 'nu_imc_pre_gestacional', 'ganho_imc', 'nu_peso',
                  'nu_altura', 'log_taxa_sifilis_gest', 'cnes_hospitais',
                  'cobertura_prenatal_log', 'escolaridade']
    COLS_BIN = [
        'est_nut_baixo_peso', 'est_nut_adequado', 'est_nut_sobrepeso', 'est_nut_obesidade',
        'raca_branca', 'raca_preta', 'raca_amarela', 'raca_parda', 'raca_indigena',
        'flag_anti_hiv', 'tem_dado_sia'
    ]

    import numpy as np
    import math

    x_cont = np.array([[
        nu_imc,
        dados['nu_imc_pre_gestacional'],
        ganho_imc,
        dados['nu_peso'],
        dados['nu_altura'],
        math.log1p(municipio_features.get('taxa_sifilis_gest', 0)),
        municipio_features.get('cnes_hospitais', 2),
        math.log1p(municipio_features.get('sia_consultas_prenatal', 0)),
        dados['escolaridade'],
    ]])

    x_bin = np.array([[
        1 if est_nut == 'baixo_peso' else 0,
        1 if est_nut == 'adequado' else 0,
        1 if est_nut == 'sobrepeso' else 0,
        1 if est_nut == 'obesidade' else 0,
        1 if raca_col == 'branca' else 0,
        1 if raca_col == 'preta' else 0,
        1 if raca_col == 'amarela' else 0,
        1 if raca_col == 'parda' else 0,
        1 if raca_col == 'indigena' else 0,
        dados.get('flag_anti_hiv', 0),
        1 if municipio_features.get('tem_dado_sia', False) else 0,
    ]])

    # 5. Normalizar (RobustScaler aplica apenas nas features contínuas)
    x_scaled = np.hstack([scaler.transform(x_cont), x_bin])

    # 6. Redução PCA
    x_pca = pca.transform(x_scaled)

    # 7. Predição
    cluster_id = int(kmeans.predict(x_pca)[0])

    return {
        'cluster_id': cluster_id,
        'cluster_nome': CLUSTER_NOMES[cluster_id],
        'nivel_risco': CLUSTER_RISCO[cluster_id],
        'nu_imc_calculado': round(nu_imc, 2),
        'ganho_imc': round(ganho_imc, 2),
    }
```

---

## 4. Endpoints da API Flask

### `POST /classificar`

Classifica uma gestante e retorna seu cluster de risco.

**Request Body:**

```json
{
  "nu_peso": 72.0,
  "nu_altura": 1.62,
  "nu_imc_pre_gestacional": 24.1,
  "raca_cor": 4,
  "escolaridade": 3,
  "flag_anti_hiv": 0,
  "cod_municipio": "3509502"
}
```

**Response (200):**

```json
{
  "cluster_id": 1,
  "cluster_nome": "Eutrofia / Baixo Peso",
  "nivel_risco": "moderado",
  "nu_imc_calculado": 27.43,
  "ganho_imc": 3.33,
  "recomendacoes": [
    "Manter 6 ou mais consultas de pré-natal",
    "Monitorar ganho de peso mensalmente",
    "Garantir aporte adequado de ferro e ácido fólico"
  ]
}
```

**Possíveis clusters na resposta:**
| cluster_id | cluster_nome | nivel_risco |
|------------|-------------|------------|
| 0 | Obesidade Gestacional | alto |
| 1 | Eutrofia / Baixo Peso | moderado |
| 2 | Acesso Diferenciado | atencao |

### `GET /health`

```json
{ "status": "ok", "modelo": "kmeans_k3", "K": 3, "silhouette": 0.2873 }
```

### `GET /clusters`

Retorna os 3 perfis de cluster com métricas dos centroides.

---

## 5. Endpoints da API NestJS

| Método | Rota                                     | Descrição                                         |
| ------ | ---------------------------------------- | ------------------------------------------------- |
| `POST` | `/users/register`                        | Cadastro de nova usuária                          |
| `POST` | `/auth/login`                            | Autenticação JWT                                  |
| `GET`  | `/users/profile`                         | Consulta de perfil do usuário autenticado         |
| `POST` | `/pregnancy/create`                      | Criação de um novo ciclo gestacional              |
| `GET`  | `/pregnancy`                             | Retorna o histórico de gestações da usuária       |
| `POST` | `/questionnaires/:pregnancyId/submit`    | Submissão de check-in / questionário              |
| `GET`  | `/questionnaires/pregnancy/:pregnancyId` | Histórico de respostas/classificações da gestação |

---

## 6. Fluxo de Dados (Ponta a Ponta)

```
App Flutter
    │
    │ POST /api/quiz/submit {peso, altura, raca, escolaridade, municipio}
    ▼
NestJS
    │ 1. Autentica JWT
    │ 2. Busca municipio_features no PostgreSQL
    │    (taxa_sifilis, cnes_hospitais, cobertura_prenatal)
    │
    │ POST /classificar (interno)
    ▼
Flask (IA)
    │ 1. Monta vetor 20 features
    │ 2. RobustScaler → PCA (8 comp.) → KMeans.predict()
    │ 3. Retorna cluster_id + métricas
    ▼
NestJS
    │ 1. Salva {user_id, cluster_id, timestamp, imc, municipio} no PostgreSQL
    │ 2. Busca recomendações do cluster
    │ 3. Retorna resposta completa ao App
    ▼
App Flutter
    Exibe: perfil de risco + recomendações + histórico
```

---

## 7. Banco de Dados (PostgreSQL)

### Schema `app` (NestJS)

```sql
-- Usuárias
CREATE TABLE app.usuarios (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       TEXT UNIQUE NOT NULL,
    nome        TEXT,
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- Classificações
CREATE TABLE app.classificacoes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id      UUID REFERENCES app.usuarios(id),
    cluster_id      SMALLINT NOT NULL CHECK (cluster_id IN (0, 1, 2)),
    cluster_nome    TEXT,
    nu_imc          NUMERIC(5,2),
    nu_peso         NUMERIC(5,1),
    ganho_imc       NUMERIC(4,2),
    cod_municipio   TEXT,
    nivel_risco     TEXT,
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- Dicas por cluster
CREATE TABLE app.dicas (
    id          SERIAL PRIMARY KEY,
    cluster_id  SMALLINT NOT NULL CHECK (cluster_id IN (0, 1, 2)),
    titulo      TEXT,
    conteudo    TEXT,
    categoria   TEXT  -- 'nutricao', 'consultas', 'exames', 'alertas'
);
```

### Schema `ml_maternar` (dados de treino — referência)

```sql
-- Features das gestantes (base DATASUS)
ml_maternar.gestante_features  -- 378.969 registros, cluster_km3 = coluna final
ml_maternar.municipio_risco    -- 3.479 municípios com taxas de risco
```

---

## 8. Variáveis de Ambiente

```env
# NestJS (arquivo .env — ver .env.example)
DATABASE_URL="postgresql://admin:password@localhost:5490/gestasus_db?schema=public"
JWT_SECRET="chave_secreta_minimo_32_bytes"
PORT=3000

# RabbitMQ (conexão com Worker Flask)
RABBITMQ_HOST=seu.host
RABBITMQ_PORT=5672
RABBITMQ_USER=usuario
RABBITMQ_PASSWORD=senha
RABBITMQ_VHOST=/
RABBITMQ_QUEUE=maternar.classificar
```

---

## 9. Recomendações por Cluster (conteúdo para tabela `dicas`)

### Cluster 0 — Obesidade Gestacional

| Categoria | Recomendação                                              |
| --------- | --------------------------------------------------------- |
| Nutricao  | Encaminhar para nutricionista especializado em gestação   |
| Consultas | Monitoramento intensivo: consultas a cada 2-3 semanas     |
| Exames    | Rastreamento de pré-eclâmpsia e diabetes gestacional      |
| Alertas   | Risco elevado de parto cesáreo e complicações metabólicas |

### Cluster 1 — Eutrofia / Baixo Peso

| Categoria | Recomendação                                                 |
| --------- | ------------------------------------------------------------ |
| Nutricao  | Orientação nutricional básica; monitorar ganho de peso       |
| Consultas | Garantir mínimo de 6 consultas pré-natal (padrão SUS)        |
| Exames    | Hemograma, glicemia, VDRL, anti-HIV (rotina)                 |
| Alertas   | Verificar se peso pré-gestacional está em zona de baixo peso |

### Cluster 2 — Acesso Diferenciado

| Categoria | Recomendação                                                     |
| --------- | ---------------------------------------------------------------- |
| Nutricao  | Avaliação nutricional completa (acesso a centros especializados) |
| Consultas | Verificar se está vinculada a maternidade de referência          |
| Exames    | Atenção ao VDRL — município com taxa de sífilis mais elevada     |
| Alertas   | Pode necessitar de encaminhamento para pré-natal de alto risco   |
