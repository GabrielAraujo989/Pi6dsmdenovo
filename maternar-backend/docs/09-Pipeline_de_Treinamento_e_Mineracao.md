# 09 - Pipeline de Treinamento e Mineração (Google Colab)

## 1. Objetivo
Descrever o processo de treinamento offline do modelo K-Means utilizando os microdados do DATASUS para identificar perfis de risco gestacional.

## 2. Ferramentas
*   **Ambiente:** Google Colab / Jupyter Notebook.
*   **Linguagem:** Python 3.10+.
*   **Bibliotecas:** Pandas, Scikit-learn, Seaborn, Matplotlib, PyDBC (para arquivos .dbc).

## 3. Estratégia de Linkage (Cruzamento de Bases)
O principal desafio é unir bases que não possuem um ID único universal. A estratégia será:

1.  **Chave Primária (Relativa):** `NUMERODN` (Número da Declaração de Nascido Vivo) presente no SINASC e SIM.
2.  **Chave Geográfica:** `CODMUNRES` (Código do Município de Residência) para cruzar com dados de saneamento (SNIS) e hospitais (CNES).
3.  **Filtragem Temporal:** Unificar registros por ano e competência para garantir que os dados reflitam o mesmo período.

## 4. Engenharia de Features por Base

### SINASC (Mãe e Parto)
*   **Feature:** `IDADEMAE` -> Normalização.
*   **Feature:** `ESCMAE` -> Mapeamento categórico (ex: 1=Nenhuma, 2=1-3 anos...).
*   **Feature:** `QTDGESTANT` -> Tratamento de outliers.
*   **Feature:** `CONSULTAS` -> Conversão de faixa para valor numérico médio.
*   **Target Proxy:** `GESTACAO` (Semanas) e `PESONASC` (Peso ao nascer) para validar se o cluster de "risco" realmente gera desfechos de prematuridade.

### SISVAN (Nutrição)
*   **Cálculo:** `IMC = PESO / (ALTURA²)` adaptado para a semana gestacional (Curva de Atalah).

### SIH/SUS (Internações)
*   **Transformação:** Cruzar via `NUMERODN` ou CPF (se disponível) para criar a feature binária `TEVE_COMPLICACAO_GRAVE` (Baseada em CID-10 de Pré-eclâmpsia, Infecções e Hemorragias).

### SNIS/CNES (Ambiental/Infraestrutura)
*   **Feature:** `ESGOTO_TRATADO` (SNIS) -> Índice socioeconômico do município.
*   **Feature:** `DISTANCIA_UTI` (CNES) -> Cálculo de distância euclidiana entre as coordenadas do município e a maternidade mais próxima com UTI Neonatal.

## 5. Modelagem (K-Means)
1.  **Normalização:** `StandardScaler` em todas as features numéricas.
2.  **Otimização:** Uso do Método do Cotovelo (Elbow Method) para confirmar o número de clusters (4 sugeridos).
3.  **Interpretação:** Análise dos centróides para rotular os clusters (Caminho Seguro, Atenção Redobrada, Cuidado Integral, Rede de Apoio).

## 6. Saídas do Processo
*   **`model_centroids.joblib`**: Coordenadas dos centróides para a API Flask.
*   **`scaler_params.joblib`**: Parâmetros de normalização para que a inferência no App use a mesma escala do treinamento.
*   **Relatório de Acurácia:** Validação estatística de que os clusters de risco estão correlacionados com partos prematuros na base histórica.
