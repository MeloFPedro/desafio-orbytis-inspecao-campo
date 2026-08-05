# Inspeção de Campo — Desafio Técnico Orbytis

Mini app Flutter de inspeção de campo com persistência local e sincronização offline-first.

Um técnico faz login, consulta suas ordens de serviço, registra uma inspeção com foto e
GPS, salva localmente e sincroniza com a API quando há conexão.

## Estrutura

- `app/` — aplicativo Flutter (Android)
- `mock-api/` — API mock em Node/Express fornecida no desafio
- `docs/` — enunciado, contrato da API e guia de setup do ambiente

---

## Como rodar

### Pré-requisitos

| Ferramenta | Versão | Observação |
|---|---|---|
| Flutter | 3.44 (stable) | `flutter doctor` sem erros no toolchain Android |
| Android Studio | recente | necessário pelo Android SDK e pelo gerenciador de AVD |
| Node.js | 18+ | testado com 24 LTS |
| Emulador Android | API 34+ | ou device físico (ver observação sobre base URL) |

O app é **Android-only** — as demais plataformas não foram geradas, conforme o escopo do desafio.

### 1. Subir a API mock

```bash
cd mock-api
npm install     # obrigatório na primeira vez: as dependências não vêm no repositório
npm start
```

O servidor sobe em `http://localhost:3000`. Deixe esse terminal aberto.

Para conferir, `http://localhost:3000` deve responder um JSON com `"health": "ok"`.

### 2. Rodar o app

Com o emulador **já aberto**:

```bash
cd app
flutter pub get
flutter run
```

### Base URL por ambiente

A URL da API fica em `app/lib/core/network/dio_client.dart`, na constante
`ApiConfig.baseUrl`.

| Ambiente | Base URL |
|---|---|
| Emulador Android | `http://10.0.2.2:3000` (padrão) |
| Device físico | `http://<IP-da-máquina>:3000`, com o device na mesma rede |

`10.0.2.2` é o alias que o emulador Android usa para alcançar o `localhost` da máquina
hospedeira.

### Credenciais de teste

| E-mail | Senha | Papel |
|---|---|---|
| `tecnico@orbytis.com.br` | `123456` | field_technician |
| `admin@orbytis.com.br` | `admin123` | admin |

### Resetar os dados do mock

```bash
cd mock-api
cp db/db.seed.json db/db.json
npm start
```

> O mock guarda os tokens **em memória**. Reiniciar o servidor invalida todas as sessões
> ativas, e chamadas protegidas passam a responder `401`. O app trata isso derrubando a
> sessão e voltando para o login.

---

## Arquitetura

_Em construção._

## Fila de sincronização

_Em construção._

---

## Decisões técnicas

Registro corrido das escolhas não óbvias e suas razões.

### Stack

**BLoC** para gerência de estado. O enunciado indica que é a stack da Orbytis, e o modelo
evento → estado torna a lógica testável sem construir widgets.

**Dio** para rede, pelos interceptors — o token é injetado num único lugar em vez de ser
repetido em cada chamada.

**Freezed adiado.** O escopo desejável cita "modelos imutáveis (Freezed) e/ou codegen
coerente". Optei por priorizar o escopo obrigatório e não empilhar duas ferramentas de
geração de código (Freezed + Drift) simultaneamente. Imutabilidade e igualdade por valor
são obtidas com `Equatable`, sem codegen.

### Erros: transporte vs. protocolo

O Dio é configurado com `validateStatus: (_) => true`, ou seja, **nenhum status HTTP
lança exceção**. Isso cria uma separação limpa:

- `DioException` significa falha de transporte — sem rede, timeout, DNS. Sempre transiente.
- `response.statusCode` significa que o servidor respondeu, inclusive com erro. O status
  decide se o erro é permanente.

Com o comportamento padrão do Dio, um `401` de senha errada e uma queda de Wi-Fi chegariam
ambos como `DioException`, e a fila de sincronização precisaria adivinhar a diferença.

### `isPermanent` no tipo `Failure`

Cada subclasse de `Failure` declara se o erro é permanente (`400`, `401`, `404`, `409`) ou
transiente (rede, timeout, `5xx`). A fila de sincronização consulta essa propriedade para
decidir entre marcar a inspeção como `failed` ou mantê-la em `pending` para nova tentativa.

Manter a regra no tipo, e não numa cadeia de condicionais dentro do serviço de sync, torna
a classificação testável isoladamente e impede divergência entre pontos de uso.

`UnknownFailure` é classificado como **transiente**: um erro não previsto não deveria
condenar permanentemente um registro do técnico. O teto de tentativas da fila é o que
impede reenvio infinito.

### Modelagem de estados de autenticação

A mensagem de erro vive **dentro** de `AuthUnauthenticated`, em vez de existir um estado
`AuthFailure` separado.

O motivo é o `Equatable`: o BLoC não reemite um estado igual ao anterior. Com estado
separado, errar a senha duas vezes seguidas produziria dois `AuthFailure` idênticos e o
segundo seria descartado — a mensagem não reapareceria. Com o erro dentro do estado, a
transição passa por `AuthLoading` no meio, o que quebra a igualdade.

`AuthLoading` é reservado ao login em andamento; a verificação de sessão na abertura usa
`AuthInitial`. Isso mantém a tela de login montada durante a requisição, preservando o
formulário e o listener que exibe o erro.

### Sessão restaurada do disco

`AuthRepository.restoreSession()` lê token e usuário do armazenamento seguro, sem consultar
`GET /auth/me`. Num app de campo, exigir rede para restaurar sessão deixaria o técnico de
fora justamente onde ele mais precisa entrar.

### Cleartext HTTP apenas em debug

A permissão `android:usesCleartextTraffic="true"` está em
`android/app/src/debug/AndroidManifest.xml`, não no manifesto principal. O mock roda em
HTTP puro, mas builds de release continuam exigindo HTTPS.

---

## Limitações conhecidas

_Em construção._
