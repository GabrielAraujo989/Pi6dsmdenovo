# 03 - Arquitetura de Dados e IA: Maternar

## 1. Visão Geral do Modelo

O motor de classificação utiliza o algoritmo **K-Means** (Clustering Não Supervisionado) para agrupar perfis de gestantes. O treinamento é realizado em Python (Google Colab) com dados históricos do DATASUS e a inferência ocorre em tempo real via **API Flask**.

## 2. Fontes de Dados (Training & Linkage)

O cruzamento (linkage) das bases será feito via `CODMUNRES` (Município) ou `NUMERODN` (Nº Declaração Nascido Vivo).

- **SINASC (Principal):** `IDADEMAE`, `ESCMAE`, `QTDGESTANT`, `CONSULTAS`, `GESTACAO` (Variável alvo/proxy).
- **SISVAN (Nutricional):** `PESO`, `ALTURA` (Cálculo de curva de ganho de IMC).
- **SIH/SUS (Internações):** `DIAG_PRINC` (Mapeado para variável booleana `TEVE_COMPLICACAO_GRAVE`).
- **CNES (Geolocalização):** Coordenadas (`LAT`/`LONG`) da maternidade com UTI Neonatal mais próxima.
- **SNIS (Saneamento):** Índice `IN015` (Esgoto tratado no município).

## 3. Pipeline de Dados (Google Colab)

1.  **Extração:** Download dos microdados do DATASUS.
2.  **Limpeza e Transformação:**
    - Cálculo de IMC gestacional.
    - Filtragem de registros de complicações graves via CID-10 (SIH).
    - Normalização de variáveis para o K-Means.
3.  **Linkage:** União das bases por identificadores geográficos e individuais.
4.  **Treinamento:** Execução do K-Means (Scikit-learn) para definir os centróides.
5.  **Exportação:** Modelo salvo em `.joblib` ou `.pkl` para a API Flask.

## 4. Variáveis de Entrada para o Motor de Inferência (Input da Gestante)

| Variável           | Fonte DATASUS (Treino) | Coleta no App (Inferência) |
| :----------------- | :--------------------- | :------------------------- |
| **Idade**          | `IDADEMAE`             | Input Numérico             |
| **Escolaridade**   | `ESCMAE`               | Seletor Categórico         |
| **Gestações Ant.** | `QTDGESTANT`           | Input Numérico             |
| **Consultas**      | `CONSULTAS`            | Input Numérico (atual)     |
| **IMC**            | `PESO` / `ALTURA`      | Peso e Altura informados   |
| **Comorbidade**    | `DIAG_PRINC` (SIH)     | Checkbox (Sim/Não)         |
| **Saneamento**     | `IN015` (SNIS)         | Via CEP/Localização        |

## 5. Arquitetura da Solução (3 Camadas)

- **Frontend (Flutter):** Interface de usuário e questionário.
- **Backend (Nest.js):** Gerenciamento de estado, autenticação e persistência PostgreSQL.
- **IA Backend (Flask):** Serviço especializado que carrega o modelo K-Means e processa a classificação.

## 6. Mapeamento de Clusters (Saída)

- **Cluster 0 -> "Caminho Seguro"** (Acompanhamento ideal)
- **Cluster 1 -> "Atenção Redobrada"** (Jovens, poucas consultas)
- **Cluster 2 -> "Cuidado Integral"** (Risco clínico/histórico de complicação)
- **Cluster 3 -> "Rede de Apoio"** (Vulnerabilidade socioambiental)
