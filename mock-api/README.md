# API mock — Desafio Flutter

Servidor mínimo com [json-server](https://github.com/typicode/json-server) + middleware de auth e upload.

## Pré-requisitos

- Node.js 18+

## Subir

```bash
cd mock-api
npm install
npm start
```

API em: `http://localhost:3000`

## Credenciais

| E-mail | Senha |
|--------|-------|
| `tecnico@orbytis.com.br` | `123456` |
| `admin@orbytis.com.br` | `admin123` |

## Endpoints principais

- `POST /auth/login`
- `GET /auth/me`
- `GET /work-orders`
- `GET /work-orders/:id`
- `GET /work-orders/:id/form-schema`
- `GET /inspections`
- `POST /inspections` (multipart ou JSON)

Detalhes em `../CONTRATO_API.md`.

## Emulador / device

| Ambiente | Base URL |
|----------|----------|
| iOS Simulator | `http://localhost:3000` |
| Android Emulator | `http://10.0.2.2:3000` |
| Device físico | `http://<IP-da-sua-maquina>:3000` |

Android: se necessário, permita cleartext (HTTP) no debug.

## Resetar dados

Pare o servidor, restaure `db/db.json` a partir de `db/db.seed.json` e suba de novo:

```bash
cp db/db.seed.json db/db.json
npm start
```
