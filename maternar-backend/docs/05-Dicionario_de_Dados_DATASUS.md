# 05 - Dicionário de Dados DATASUS: Maternar

## 1. Mapeamento de Variáveis Críticas

Abaixo estão as variáveis das bases originais do DATASUS que serão utilizadas para o treinamento do modelo de IA e como elas serão mapeadas no aplicativo.

| Campo DATASUS | Origem | Descrição | Mapeamento no App |
| :--- | :--- | :--- | :--- |
| `IDADEMAE` | SINASC | Idade da mãe em anos. | Coleta direta no cadastro/perfil. |
| `ESCMAE` | SINASC | Escolaridade da mãe (código). | Pergunta sobre anos de estudo. |
| `QTDGESTANT` | SINASC | Total de gestações anteriores. | Coleta direta (multípara ou primípara). |
| `CONSULTAS` | SINASC | Nº de consultas pré-natal (faixas). | Coleta do número absoluto realizado. |
| `GESTACAO` | SINASC | Semanas de gestação no parto. | **Target Proxy** do treinamento. |
| `PESO` | SISVAN | Peso da gestante na avaliação. | Coleta de peso atual. |
| `ALTURA` | SISVAN | Estatura da gestante. | Coleta de altura. |
| `DIAG_PRINC` | SIH/SUS | Código CID-10 da internação. | Checkbox de complicações prévias. |
| `LAT`/`LONG` | CNES | Coordenadas da maternidade. | Calculado via GPS/CEP do App. |
| `IN015` | SNIS | Índice de esgoto tratado (Mun.). | Atribuído via CEP da gestante. |

## 2. Tratamento e Conversão de Escolaridade (ESCMAE)
Para o treinamento, a variável categórica `ESCMAE` será convertida em anos de estudo conforme o padrão SINASC:
*   **1:** Nenhuma escolaridade.
*   **2:** 1 a 3 anos.
*   **3:** 4 a 7 anos.
*   **4:** 8 a 11 anos.
*   **5:** 12 anos ou mais.

No app, a pergunta será simplificada: *"Até que série você estudou?"* ou *"Quantos anos você frequentou a escola?"*.

## 3. Lógica de Consultas Pré-Natal
No DATASUS, a variável `CONSULTAS` é frequentemente categórica (1: Nenhuma; 2: 1 a 3; 3: 4 a 6; 4: 7 ou mais).
No app, coletaremos o número exato e converteremos para a categoria correspondente para aplicar o centróide do K-Means.

## 4. Filtros de Dataset para Treinamento
*   **Temporal:** Registros de 2019 a 2024.
*   **Geográfico:** Recortes regionais podem ser aplicados se houver variação significativa de desfechos.
*   **Qualidade:** Excluir registros onde `SEMAGESTAC` ou `IDADEMAE` sejam nulos ou ignorados.
