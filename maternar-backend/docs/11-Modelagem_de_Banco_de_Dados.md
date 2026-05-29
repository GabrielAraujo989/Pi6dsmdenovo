# 11 - Modelagem Detalhada de Banco de Dados: Maternar

Este documento detalha a estrutura do banco de dados PostgreSQL, os relacionamentos e a lógica de persistência para o projeto Maternar.

## 1. Diagrama Entidade-Relacionamento (Conceitual)

O sistema baseia-se em um modelo onde um **Usuário** (Gestante) pode ter múltiplas **Gestações** ao longo do tempo. Cada gestação possui um **Questionário** de entrada que gera uma **Classificação (Cluster)**, a qual, por sua vez, determina as **Dicas** visualizadas.

---

## 2. Dicionário de Tabelas

### 2.1. Tabela `users` (Gestante)

Armazena os dados de autenticação e perfil básico da usuária.

- `id` (UUID, PK): Identificador único.
- `nome` (VARCHAR): Nome completo.
- `email` (VARCHAR, Unique): E-mail de login.
- `senha_hash` (VARCHAR): Senha criptografada.
- `data_nascimento` (DATE): Usada para calcular a idade exata no momento de cada gestação.
- `created_at` (TIMESTAMP): Data de cadastro.

### 2.2. Tabela `gestacoes`

Gerencia os ciclos gestacionais da usuária.

- `id` (UUID, PK): Identificador único.
- `user_id` (UUID, FK): Referência a `users.id`.
- `data_inicio_dum` (DATE): Data da Última Menstruação (para cálculo de IG).
- `data_prevista_parto` (DATE): Calculada pelo sistema.
- `status` (ENUM): 'Ativa', 'Finalizada', 'Interrompida'.
- `cluster_id` (INTEGER, FK): Referência ao cluster atual atribuído pela IA (tabela `clusters`).

### 2.3. Tabela `questionario_respostas`

Armazena os inputs brutos enviados ao motor de IA (Flask).

- `id` (UUID, PK): Identificador único.
- `gestacao_id` (UUID, FK): Referência a `gestacoes.id`.
- `escolaridade` (INTEGER): Código ESCMAE (1-5).
- `qtd_gestacoes_ant` (INTEGER): Histórico de partos/abortos.
- `num_consultas_atual` (INTEGER): Quantidade de consultas realizadas até o envio.
- `peso_inicial` (DECIMAL): Peso no início da gestação.
- `altura` (DECIMAL): Altura da gestante (em metros).
- `cep` (VARCHAR): Localização para cruzamento de saneamento/CNES.
- `teve_complicacao_previa` (BOOLEAN): Se possui histórico clínico grave.
- `data_resposta` (TIMESTAMP).

### 2.4. Tabela `clusters` (Perfis de Cuidado)

Tabela mestre com as definições dos centróides e nomes acolhedores.

- `id` (SERIAL, PK): ID técnico do cluster (0, 1, 2, 3).
- `nome_tecnico` (VARCHAR): Ex: 'Risco Moderado'.
- `nome_acolhedor` (VARCHAR): Ex: 'Atenção Redobrada'.
- `descricao` (TEXT): Definição do perfil para a equipe de saúde.
- `cor_hex` (VARCHAR): Código da cor para a UI (ex: #FFD700).

### 2.5. Tabela `dicas`

Conteúdo educativo personalizado.

- `id` (SERIAL, PK): Identificador da dica.
- `titulo` (VARCHAR): Título chamativo.
- `conteudo` (TEXT): Texto completo da orientação.
- `categoria` (ENUM): 'Saúde', 'Nutrição', 'Direitos', 'Exames'.

### 2.6. Tabela `cluster_dicas` (Relacionamento N:N)

Associa quais dicas aparecem para quais perfis.

- `cluster_id` (INTEGER, FK): Referência a `clusters.id`.
- `dica_id` (INTEGER, FK): Referência a `dicas.id`.

---

## 3. Relacionamentos e Cardinalidade

1.  **Usuário para Gestação (1:N):** Uma gestante pode ter várias gestações registradas no histórico do app, mas cada gestação pertence a apenas uma usuária.
2.  **Gestação para Questionário (1:1 ou 1:N):** Cada gestação tem ao menos um questionário inicial para classificação. Caso a gestante mude de comportamento (ex: passe a ir a mais consultas), ela pode re-responder o questionário para atualizar seu cluster.
3.  **Gestação para Cluster (N:1):** Várias gestações podem cair no mesmo perfil (ex: Caminho Seguro).
4.  **Cluster para Dicas (N:N):** Um cluster pode ter muitas dicas associadas, e uma mesma dica (ex: "Beba água") pode ser recomendada para múltiplos clusters.

---

## 4. Lógica de Integração com IA (Flask)

O backend **Nest.js** coleta os dados da tabela `questionario_respostas` e envia via JSON para o **Flask**. O Flask processa o modelo K-Means e devolve o `cluster_id`. O Nest.js então atualiza o campo `cluster_id` na tabela `gestacoes` para que o frontend (Flutter) saiba quais dicas filtrar através da tabela `cluster_dicas`.
