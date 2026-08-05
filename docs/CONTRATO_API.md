# Contrato da API mock — Desafio Flutter

Base URL local: `http://localhost:3000`  
Emulador Android: `http://10.0.2.2:3000`  
Dispositivo físico: use o IP da máquina na LAN (ex.: `http://192.168.x.x:3000`)

Autenticação: header `Authorization: Bearer <token>` nas rotas protegidas.

Content-Type JSON: `application/json`  
Upload de inspeção: preferencialmente `multipart/form-data` (alternativa JSON documentada abaixo).

---

## Auth

### `POST /auth/login`

**Body**
```json
{
  "email": "tecnico@orbytis.com.br",
  "password": "123456"
}
```

**200**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "tokenType": "Bearer",
  "expiresIn": 86400,
  "user": {
    "id": "u_001",
    "name": "Ana Técnica",
    "email": "tecnico@orbytis.com.br",
    "role": "field_technician"
  }
}
```

**401**
```json
{
  "message": "Credenciais inválidas"
}
```

### `GET /auth/me` (protegida)

**200**
```json
{
  "id": "u_001",
  "name": "Ana Técnica",
  "email": "tecnico@orbytis.com.br",
  "role": "field_technician"
}
```

---

## Work orders

### `GET /work-orders` (protegida)

Query opcional: `?status=open|in_progress|done`

**200**
```json
[
  {
    "id": "wo_1001",
    "code": "OS-2026-001",
    "title": "Inspeção de poste — Rua das Acácias",
    "description": "Verificar estado do poste e conexões aparentes.",
    "address": "Rua das Acácias, 120 — João Pessoa/PB",
    "priority": "high",
    "status": "open",
    "latitude": -7.1195,
    "longitude": -34.8450,
    "scheduledAt": "2026-07-28T13:00:00.000Z",
    "updatedAt": "2026-07-26T12:00:00.000Z"
  }
]
```

### `GET /work-orders/:id` (protegida)

**200** — mesmo objeto da lista + `notes` opcional.

**404**
```json
{ "message": "Ordem de serviço não encontrada" }
```

### `GET /work-orders/:id/form-schema` (protegida) — stretch

```json
{
  "workOrderId": "wo_1001",
  "fields": [
    {
      "key": "observation",
      "type": "text",
      "label": "Observação",
      "required": true,
      "minLength": 10
    },
    {
      "key": "condition",
      "type": "select",
      "label": "Condição do ativo",
      "required": true,
      "options": ["bom", "regular", "ruim", "crítico"]
    },
    {
      "key": "photo",
      "type": "photo",
      "label": "Foto da evidência",
      "required": true
    },
    {
      "key": "location",
      "type": "location",
      "label": "Local da inspeção",
      "required": true
    }
  ]
}
```

---

## Inspections

### `GET /inspections` (protegida)

Retorna inspeções já sincronizadas no servidor (do usuário autenticado).

**200**
```json
[
  {
    "id": "insp_9001",
    "clientId": "550e8400-e29b-41d4-a716-446655440000",
    "workOrderId": "wo_1001",
    "observation": "Poste ok, pequena oxidação na base.",
    "condition": "regular",
    "photoUrl": "/uploads/insp_9001.jpg",
    "latitude": -7.1197,
    "longitude": -34.8451,
    "capturedAt": "2026-07-26T15:10:00.000Z",
    "syncedAt": "2026-07-26T15:12:00.000Z",
    "createdBy": "u_001"
  }
]
```

### `POST /inspections` (protegida) — multipart (recomendado)

`Content-Type: multipart/form-data`

| Campo | Tipo | Obrigatório | Descrição |
|-------|------|-------------|-----------|
| `clientId` | string (UUID) | sim | ID gerado no app; usado para idempotência |
| `workOrderId` | string | sim | ID da OS |
| `observation` | string | sim | Texto da inspeção |
| `condition` | string | não | Ex.: bom/regular/ruim/crítico |
| `latitude` | number | sim | GPS |
| `longitude` | number | sim | GPS |
| `capturedAt` | string ISO-8601 | sim | Momento da coleta no dispositivo |
| `photo` | file (jpg/png) | sim | Evidência |

**201 — criada**
```json
{
  "id": "insp_9002",
  "clientId": "550e8400-e29b-41d4-a716-446655440000",
  "workOrderId": "wo_1001",
  "observation": "Poste ok, pequena oxidação na base.",
  "condition": "regular",
  "photoUrl": "/uploads/insp_9002.jpg",
  "latitude": -7.1197,
  "longitude": -34.8451,
  "capturedAt": "2026-07-26T15:10:00.000Z",
  "syncedAt": "2026-07-26T15:12:00.000Z",
  "createdBy": "u_001"
}
```

**200 — idempotente (mesmo `clientId` já existente)**  
Retorna o registro já criado (não duplica).

**400**
```json
{
  "message": "Payload inválido",
  "errors": {
    "observation": ["mínimo de 10 caracteres"],
    "photo": ["arquivo obrigatório"]
  }
}
```

**401** — token ausente/inválido  
**409** — `workOrderId` inexistente (opcional no mock)

### Alternativa JSON (aceitável se documentada)

`POST /inspections` com body:

```json
{
  "clientId": "550e8400-e29b-41d4-a716-446655440000",
  "workOrderId": "wo_1001",
  "observation": "Poste ok, pequena oxidação na base.",
  "condition": "regular",
  "latitude": -7.1197,
  "longitude": -34.8451,
  "capturedAt": "2026-07-26T15:10:00.000Z",
  "photoBase64": "<base64 sem data-uri prefix>"
}
```

> Se usar JSON, limite o tamanho da foto no app (ex.: resize para max 1280px / ~1MB) e documente no README.

---

## Erros genéricos

```json
{
  "message": "Descrição legível do erro"
}
```

Simule falhas no app (modo avião, mock offline) para validar a fila — não dependa só do servidor.

---

## Regras de negócio esperadas no app (mesmo que a API seja simples)

1. Toda inspeção nasce com um `clientId` (UUID) gerado no dispositivo.
2. Rascunhos (`draft`) **não** vão para a API.
3. Itens `pending` / `failed` entram na fila de sync.
4. Sucesso → `synced` + guardar `serverId` (`id` retornado).
5. Falha de rede → permanece `pending` ou vai para `failed` com motivo.
6. Reenvio deve reutilizar o mesmo `clientId`.
