# 13 — Especificações de Segurança

**Papel:** Especialista em Segurança + Engenheiro de Software  
**Data:** 2026-05-29  
**Escopo:** Backend NestJS · Frontend Flutter · Pipeline Python/Flask · Infraestrutura Docker

---

## 1. Sumário Executivo

O Maternar lida com dados sensíveis de saúde de gestantes (peso, altura, IMC, histórico obstétrico, geolocalização via CEP). Qualquer violação de confidencialidade ou integridade pode causar dano real às usuárias. Esta análise mapeia vulnerabilidades identificadas no código atual, classifica por severidade e propõe ações corretivas priorizadas.

**Classificação de severidade utilizada:** Crítico · Alto · Médio · Baixo · Informativo

---

## 2. Vulnerabilidades Identificadas

### 2.1 Autenticação e Gestão de Sessão

#### [CRÍTICO] JWT com expiração de 60 segundos
**Arquivo:** `maternar-backend/src/auth/application/auth.service.ts:11`

```typescript
private readonly jwtExpirationTimeInSeconds = 60; // ← 60 SEGUNDOS
```

**Problema:** Um token com TTL de 60s expira antes do usuário terminar qualquer interação com o app. Isso força o cliente a re-autenticar constantemente ou a manter o par email/senha em memória para relogin automático — padrão que compromete a segurança da sessão.

**Impacto:** Qualquer token interceptado expira em até 60s (positivo), mas a UX força comportamentos inseguros no cliente para compensar o prazo curto.

**Correção:**
```typescript
// access token: 15-60 minutos
private readonly jwtExpirationTimeInSeconds = 60 * 15; // 15 min

// Implementar refresh token com TTL de 7-30 dias
// Endpoint: POST /auth/refresh
```

---

#### [ALTO] Ausência de Refresh Token
**Consequência direta do item anterior.** Sem refresh token, o app Flutter armazena o token em `SharedPreferences` e não tem mecanismo seguro para renovar sessão. O token válido (mesmo com 60s) deve ser tratado como credencial.

**Correção:** Implementar endpoint `POST /auth/refresh` com:
- Refresh token armazenado em banco, associado ao `userId`
- Rotação de refresh token a cada uso (token rotation)
- Blacklist de refresh tokens revogados (logout)

---

#### [ALTO] JWT_SECRET sem `getOrThrow` no módulo de Auth
**Arquivo:** `maternar-backend/src/auth/auth.module.ts:14-18`

```typescript
useFactory: (config: ConfigService) => ({
  secret: config.get('JWT_SECRET'), // ← pode retornar undefined
}),
```

**Problema:** Se `JWT_SECRET` não estiver definido no ambiente, `config.get()` retorna `undefined`. O `JwtModule` aceita `undefined` como segredo, resultando em tokens assinados sem chave (algoritmo `HS256` com segredo vazio — facilmente forjável).

**Correção:**
```typescript
secret: config.getOrThrow<string>('JWT_SECRET'),
```

---

#### [ALTO] Ausência de Rate Limiting nos endpoints de autenticação
**Arquivo:** `maternar-backend/src/auth/http/auth.controller.ts`

**Problema:** `POST /auth/login` e `POST /users/register` não possuem proteção contra força bruta ou ataques de enumeração de usuários.

**Correção:**
```bash
npm install @nestjs/throttler
```
```typescript
// app.module.ts
ThrottlerModule.forRoot([{ ttl: 60000, limit: 5 }]) // 5 req/min
// No controller:
@UseGuards(ThrottlerGuard)
@Throttle({ default: { limit: 5, ttl: 60000 } })
```

---

#### [MÉDIO] Inconsistência na política de senha entre Frontend e Backend
**Backend** (`LoginLocalDto`): `@MinLength(6)`  
**Frontend** (`main.dart:411-420`): valida mínimo 8 caracteres + especial + número + maiúscula

O backend aceita senhas de 6 caracteres que o frontend nunca permitiria criar. Isso cria uma janela de ataque para clientes que chamam a API diretamente.

**Correção:** Unificar a política de senha no backend:
```typescript
// user.dto.ts
@MinLength(8)
@Matches(/^(?=.*[A-Z])(?=.*[0-9])(?=.*[!@#$%^&*])/, {
  message: 'Senha deve conter maiúscula, número e caractere especial'
})
password: string;
```

---

### 2.2 Headers de Segurança HTTP

#### [ALTO] Ausência de Helmet.js (headers HTTP de segurança)
**Arquivo:** `maternar-backend/src/main.ts`

**Problema:** A aplicação não configura headers de segurança HTTP. Isso expõe a API a ataques de clickjacking, MIME-sniffing, XSS refletido e outros.

**Correção:**
```bash
npm install helmet
```
```typescript
// main.ts
import helmet from 'helmet';
app.use(helmet());
```

Headers que seriam adicionados: `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`, `Content-Security-Policy`, `X-XSS-Protection`.

---

#### [ALTO] CORS não configurado explicitamente
**Arquivo:** `maternar-backend/src/main.ts`

**Problema:** CORS não está configurado, o que significa que, dependendo da versão do NestJS, todas as origens podem ser aceitas ou nenhuma. Para produção, é essencial configurar origens permitidas.

**Correção:**
```typescript
// main.ts
app.enableCors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') ?? ['http://localhost:3000'],
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  credentials: true,
});
```

---

### 2.3 Armazenamento de Dados Sensíveis — Mobile

#### [ALTO] JWT Token armazenado em SharedPreferences (plaintext)
**Arquivo:** `maternar-frontend/lib/app_session.dart:38-42`

```dart
static Future<void> saveToken(String token) async {
  _token = token;
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_tokenKey, token); // ← armazenamento plaintext
}
```

**Problema:** `SharedPreferences` no Android armazena dados em XML plaintext no diretório privado do app, acessível em dispositivos com root. Dados de saúde sensíveis não devem ser armazenados desta forma.

**Correção:** Usar `flutter_secure_storage` para tokens:
```yaml
# pubspec.yaml
flutter_secure_storage: ^9.0.0
```
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
await _storage.write(key: _tokenKey, value: token);
```

---

#### [MÉDIO] Dados de perfil (nome, e-mail, data de parto) em SharedPreferences
**Arquivo:** `maternar-frontend/lib/app_session.dart:44-57`

Informações de saúde como data de parto e e-mail estão em armazenamento não criptografado.

**Correção:** Migrar todos os dados sensíveis de sessão para `flutter_secure_storage`.

---

### 2.4 Comunicação em Trânsito

#### [ALTO] API URL padrão usa HTTP (sem TLS)
**Arquivo:** `maternar-frontend/lib/backend_api.dart:55-58`

```dart
static const String defaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000', // ← HTTP, sem TLS
);
```

**Problema:** Em produção, credenciais e dados de saúde trafegam sem criptografia por padrão.

**Correção:**
- Configurar HTTPS para o ambiente de produção
- No `main.ts` do NestJS, configurar certificado TLS ou usar proxy reverso (Nginx/Traefik) com HTTPS
- Atualizar o `defaultValue` para o domínio de produção com HTTPS
- Implementar network security config no Android para bloquear tráfego HTTP em release

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<network-security-config>
  <domain-config cleartextTrafficPermitted="false">
    <domain includeSubdomains="true">seu-dominio.com.br</domain>
  </domain-config>
</network-security-config>
```

---

#### [MÉDIO] Frontend consulta ViaCEP diretamente via HTTP sem validação de certificado
**Arquivo:** `maternar-frontend/lib/viacep_service.dart:17`

```dart
final uri = Uri.parse('https://viacep.com.br/ws/$digits/json/');
```

ViaCEP já usa HTTPS — ponto positivo. Porém, não há certificate pinning para essa dependência externa crítica.

**Recomendação:** Para produção, considerar proxiar a consulta de CEP pelo próprio backend (a integração já existe no NestJS), eliminando a dependência direta do app mobile com serviço externo.

---

### 2.5 Pipeline Python/Flask (Serviço de IA)

#### [ALTO] Endpoints HTTP do Flask sem autenticação
**Arquivo:** `ApiDatasus/flask_api/app.py`

**Problema:** Os endpoints `POST /classificar` e `GET /clusters` não possuem autenticação. Qualquer cliente com acesso à rede pode enviar dados e obter classificações.

**Correção:** Implementar API Key simples para o serviço interno:
```python
from functools import wraps
import os

API_KEY = os.environ.get('FLASK_API_KEY')

def require_api_key(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        key = request.headers.get('X-API-Key')
        if not key or key != API_KEY:
            return jsonify({'error': 'Unauthorized'}), 401
        return f(*args, **kwargs)
    return decorated
```

---

#### [MÉDIO] Credenciais padrão fracas no docker-compose
**Arquivo:** `maternar-backend/.env.example:1`

```
DATABASE_URL="postgresql://admin:gestasus_password@localhost:5432/gestasus_db"
```

A senha `gestasus_password` é exatamente o tipo de credencial que um atacante tentaria primeiro. O `.env.example` deve usar senhas placeholder claramente aleatórias.

**Correção:**
```
DATABASE_URL="postgresql://admin:SUBSTITUA_POR_SENHA_FORTE@localhost:5432/gestasus_db"
JWT_SECRET="SUBSTITUA_POR_STRING_ALEATORIA_DE_32_BYTES_MINIMO"
```

---

### 2.6 Validação e Sanitização

#### [MÉDIO] CEP não normalizado antes da consulta ViaCEP no Frontend
**Arquivo:** `maternar-frontend/lib/viacep_service.dart`

A sanitização remove caracteres não-numéricos, mas não valida dígitos verificadores do CEP. Um atacante pode usar sequências como `00000000` para enumerar a API.

**Recomendação:** A validação de CEP válido via IBGE deve permanecer no backend (já implementada no `ViaCepService` do NestJS).

---

#### [BAIXO] Ausência de validação de Content-Type nos endpoints
**Arquivo:** `maternar-backend/src/main.ts`

O `ValidationPipe` com `whitelist: true` e `forbidNonWhitelisted: true` já oferece boa proteção. Adicionar validação explícita de `Content-Type: application/json` é uma camada extra recomendada.

---

### 2.7 Logs e Auditoria

#### [MÉDIO] Ausência de log de eventos de segurança
**Problema:** Tentativas de login falhas, criações de conta, acessos com token inválido e classificações de IA não são logados com contexto suficiente para auditoria.

**Correção:** Implementar logging estruturado com:
- IP de origem
- User-Agent
- Timestamp
- UserId (quando disponível)
- Evento: `AUTH_SUCCESS`, `AUTH_FAILURE`, `REGISTRATION`, `TOKEN_EXPIRED`

```typescript
// Exemplo no AuthService
this.logger.warn('AUTH_FAILURE', { email, ip: request.ip, timestamp: new Date() });
```

---

## 3. Matriz de Risco e Priorização

| # | Vulnerabilidade | Severidade | Esforço de Correção | Prioridade |
|---|----------------|------------|---------------------|------------|
| 1 | JWT expira em 60 segundos | Crítico | Baixo | P0 |
| 2 | JWT_SECRET pode ser undefined | Alto | Mínimo | P0 |
| 3 | Ausência de Helmet.js | Alto | Mínimo | P0 |
| 4 | Sem rate limiting em auth | Alto | Baixo | P1 |
| 5 | Token JWT em SharedPreferences | Alto | Médio | P1 |
| 6 | API padrão sem HTTPS | Alto | Médio (infra) | P1 |
| 7 | CORS não configurado | Alto | Mínimo | P1 |
| 8 | Flask API sem autenticação | Alto | Baixo | P1 |
| 9 | Inconsistência política de senha | Médio | Baixo | P2 |
| 10 | Dados de perfil em SharedPreferences | Médio | Médio | P2 |
| 11 | Credenciais fracas no .env.example | Médio | Mínimo | P2 |
| 12 | Ausência de auditoria/logging | Médio | Médio | P2 |
| 13 | ViaCEP sem certificate pinning | Médio | Médio | P3 |
| 14 | CEP sem validação de dígito | Baixo | Baixo | P3 |

---

## 4. Recomendações Arquiteturais

### 4.1 Autenticação — Fluxo Recomendado

```
Cliente Flutter
    │
    ├─ POST /auth/login ──────────────► NestJS
    │   ◄── { access_token (15min), refresh_token (7d) }
    │
    ├─ GET /users/profile (Bearer access_token)
    │
    ├─ (token expira) ───────────────►
    │   POST /auth/refresh (Bearer refresh_token)
    │   ◄── { novo access_token, novo refresh_token }
    │
    └─ POST /auth/logout (invalida refresh_token no BD)
```

### 4.2 Armazenamento Seguro no Flutter

```
SharedPreferences (não sensível)     flutter_secure_storage (sensível)
─────────────────────────────────    ────────────────────────────────
✅ Preferências de UI                ✅ JWT access_token
✅ Configurações do app              ✅ JWT refresh_token
✅ Flag de onboarding                ✅ E-mail / nome (se necessário)
                                     ✅ Data de parto
```

### 4.3 Camadas de Defesa Recomendadas

```
Internet
    │
    ├─ [L1] TLS/HTTPS (Nginx / Cloudflare)
    │
    ├─ [L2] Rate Limiting + WAF
    │
    ├─ [L3] Helmet.js (security headers)
    │
    ├─ [L4] Autenticação JWT com refresh token
    │
    ├─ [L5] Validação de input (ValidationPipe + class-validator)
    │
    ├─ [L6] Autorização por recurso (guard + claims)
    │
    └─ [L7] Auditoria / logging estruturado
```

---

## 5. Conformidade com LGPD

O Maternar coleta e processa **dados de saúde** (categoria especial segundo o Art. 11 da LGPD). Requisitos específicos:

| Requisito LGPD | Status Atual | Ação Necessária |
|---------------|-------------|-----------------|
| Base legal para tratamento de dados sensíveis | ⚠️ Não documentada | Definir base legal (consentimento ou tutela da saúde) |
| Consentimento explícito | ⚠️ Tela de termos de uso vazia | Implementar tela de consentimento com texto legalmente revisado |
| Direito de acesso aos dados (Art. 18) | ❌ Não implementado | Implementar endpoint `GET /users/my-data` |
| Direito à exclusão (Art. 18, VII) | ❌ Não implementado | Implementar endpoint `DELETE /users/me` |
| Minimização de dados | ⚠️ Parcial | Revisar campos opcionais vs. obrigatórios no cadastro |
| Prazo de retenção | ❌ Não definido | Definir política de retenção de dados |
| DPO (Encarregado de Dados) | ❌ Não definido | Designar DPO (exigido para dados sensíveis) |

---

## 6. Checklist de Segurança para Deploy em Produção

```
[ ] JWT_SECRET com mínimo de 32 bytes aleatórios (use: openssl rand -base64 32)
[ ] JWT expiração configurada para 15+ minutos
[ ] Refresh token implementado e testado
[ ] Helmet.js instalado e configurado
[ ] CORS configurado com origens explícitas
[ ] Rate limiting em endpoints de autenticação
[ ] HTTPS habilitado com certificado válido (Let's Encrypt)
[ ] flutter_secure_storage substituindo SharedPreferences para dados sensíveis
[ ] flutter build apk --obfuscate --split-debug-info para release
[ ] Variáveis de ambiente não commitadas no git
[ ] .env.* no .gitignore verificado
[ ] Flask API com autenticação por API Key
[ ] Portas internas (5432, 5672, 5001) não expostas publicamente
[ ] Imagens Docker atualizadas (sem CVEs críticos)
[ ] Auditoria de logs de auth habilitada
[ ] Política de senha idêntica entre frontend e backend
[ ] Tela de consentimento LGPD implementada
[ ] Endpoint de exclusão de dados implementado
```

---

## 7. Ferramentas Recomendadas para Análise Contínua

| Ferramenta | Finalidade | Como usar |
|-----------|-----------|-----------|
| `npm audit` | Vulnerabilidades em dependências Node.js | `npm audit` no `maternar-backend/` |
| `safety` | Vulnerabilidades em dependências Python | `pip install safety && safety check` |
| `trivy` | Scan de vulnerabilidades em imagens Docker | `trivy image maternar_worker` |
| `flutter_lints` | Análise estática do Dart | Já configurado (`flutter analyze`) |
| `OWASP Dependency-Check` | CVEs em dependências | Integrar ao CI/CD |
| `Snyk` | Análise contínua de segurança | `snyk test` no repositório |

---

*Documento elaborado com base na análise do código-fonte nas versões disponíveis em 2026-05-29. Reavalie após mudanças arquiteturais significativas.*
