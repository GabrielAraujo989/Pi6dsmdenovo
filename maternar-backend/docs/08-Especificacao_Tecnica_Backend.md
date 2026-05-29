# 08 - Especificação Técnica: Backend (Nest.js & Flask)

## 1. Visão Geral

A arquitetura de backend do **Maternar** é composta por dois serviços distintos para separar a lógica de negócio da lógica de inteligência artificial.

## 2. Serviço de Gerenciamento (Nest.js)

Responsável pela interface administrativa, persistência de dados e orquestração.

- **Tecnologia:** Nest.js (API Routes) / TypeScript.
- **Banco de Dados:** PostgreSQL (via Prisma ou TypeORM).
- **Responsabilidades:**
  - Cadastro e Autenticação de Usuárias (JWT).
  - Armazenamento do histórico de questionários.
  - Gestão de dicas e conteúdos de saúde.
  - Agendamento de notificações Push.
  - Proxy para a API Flask (para centralizar as chamadas do App).

## 3. Serviço de IA (Flask)

Serviço especializado em processamento de dados e execução do modelo de machine learning.

- **Tecnologia:** Flask / Python 3.x.
- **Bibliotecas Principais:** Scikit-learn, Pandas, Joblib.
- **Responsabilidades:**
  - **Inferência:** Receber os dados da gestante e retornar o cluster calculado via K-Means.
  - **Normalização:** Aplicar os mesmos escalonadores (Scalers) utilizados no treinamento do Colab.
  - **Cálculo de Indicadores:** Transformar peso/altura em IMC gestacional e validar contra as curvas do SISVAN.

## 4. Comunicação entre Serviços

1.  O **App Flutter** envia o questionário para o **Nest.js**.
2.  O **Nest.js** autentica a requisição e encaminha os dados necessários para o **Flask**.
3.  O **Flask** processa o K-Means e retorna o ID do Cluster.
4.  O **Nest.js** salva o resultado e retorna para o App a classificação junto com as dicas correspondentes.

## 5. Endpoints Principais (Provisório)

- `POST /api/auth/register`: Cadastro de nova usuária.
- `POST /api/quiz/submit`: Envio do questionário e recebimento da classificação.
- `GET /api/tips/:cluster_id`: Busca de dicas baseadas no perfil.
