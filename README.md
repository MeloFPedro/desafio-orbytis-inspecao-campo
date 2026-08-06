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

### Organização por feature

```
app/lib/
├── main.dart              # monta o grafo de dependências
├── app.dart               # providers e roteamento por estado de autenticação
├── core/                  # transversal às features
│   ├── error/             # tipos de falha e tradução de erros HTTP
│   ├── network/           # cliente Dio e interceptor de autenticação
│   └── database/          # persistência local
└── features/
    ├── auth/
    ├── work_orders/
    ├── inspections/
    └── sync/
```

A organização é **por feature**, não por camada. Tudo que muda junto fica junto: alterar
o fluxo de inspeção significa abrir uma pasta, não quatro. O agrupamento por tipo
(`blocs/`, `models/`, `screens/`) funciona em app pequeno e degrada conforme cresce.

### Camadas dentro de cada feature

| Camada | Responsabilidade | Conhece |
|---|---|---|
| `domain/` | modelos e regras de negócio | nada |
| `data/` | acesso a API e persistência | `domain` |
| `presentation/` | blocs e telas | `data`, `domain` |

A dependência aponta sempre para dentro. O `domain` não importa Dio nem Flutter, o que
o torna testável sem infraestrutura.

### Fluxo de dados

```
UI ──evento──► Bloc ──► Repository ──► Api ──► Dio ──► rede
▲                │
└─────estado─────┘
```

A UI nunca chama repositório: ela dispara eventos e reconstrói a partir do estado.
Consequência prática: toda a lógica é testável sem construir widgets.

A camada `Api` conhece apenas HTTP — rotas, status, JSON — e devolve dados crus. Traduzir
para objetos de domínio é trabalho do repositório. Isso permite trocar a biblioteca de
rede sem tocar em nada acima.

### Injeção de dependência

Sem biblioteca de service locator. O `main.dart` constrói os repositórios uma única vez e
o `flutter_bloc` os distribui pela árvore via `RepositoryProvider`; os blocs vêm de
`BlocProvider`, que cuida do ciclo de vida e chama `close()` automaticamente.

Os blocs de feature são criados **dentro** do ramo autenticado da árvore. Assim nascem no
login e são descartados no logout, sem que dados de uma sessão sobrevivam à seguinte.

### Autenticação

`AuthInterceptor` injeta `Authorization: Bearer <token>` em todas as rotas exceto
`/auth/login`, e detecta `401` em rota protegida.

Um `401` não é erro da tela que fez a chamada — é a sessão que expirou. O tratamento é
centralizado: o interceptor anuncia num `StreamController`, o `AuthBloc` escuta e derruba
a sessão, e o app inteiro volta ao login. Sem isso, cada bloc precisaria tratar o caso por
conta própria, com mensagens divergentes para a mesma causa.

O stream também resolve uma dependência circular: `AuthBloc → AuthRepository → AuthApi →
Dio → AuthInterceptor`. O interceptor não conhece o bloc; apenas anuncia, e quem quiser
escuta.

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

### Carga inicial e refresh são eventos distintos

`WorkOrdersRequested` e `WorkOrdersRefreshed` fazem a mesma chamada, mas a tela reage
diferente: a carga inicial mostra spinner de tela cheia; o refresh mantém a lista visível
e deixa o `RefreshIndicator` sinalizar. Com um evento único, o pull-to-refresh apagaria a
lista por um instante a cada atualização.

### Lista vazia não é um estado

`WorkOrdersLoaded` com zero itens é um resultado válido, não uma situação distinta. Um
estado `Empty` separado duplicaria a lógica de transição apenas para diferenciar "chegou
uma lista" de "chegou uma lista sem itens". A tela decide o que desenhar.

### Conclusão de operação ≠ mudança de estado

O `RefreshIndicator` exige um `Future` que complete quando a atualização termina. A
primeira implementação aguardava a próxima emissão do bloc — e travava.

O motivo: o bloc descarta estados iguais ao atual. Um refresh que traz dados idênticos é
uma operação concluída **sem** emissão, e o indicador girava indefinidamente. O bug só
aparece com dados estáticos, que é justamente o caso do mock.

A correção foi o evento carregar um `Completer`, completado pelo handler num `finally`.
O indicador passa a acompanhar a operação, não o estado.

### Valores desconhecidos de enum não derrubam o parsing

`WorkOrderPriority` e `WorkOrderStatus` têm um caso `unknown` usado como fallback. Se a API
devolver um valor não previsto, aquela OS aparece marcada como desconhecida em vez de
quebrar a lista inteira. Num app de campo, mostrar dado parcial é preferível a mostrar
tela de erro.

Pelo mesmo motivo, coordenadas são lidas como `num` antes de virar `double`: JSON não
distingue `-7` de `-7.0`, e `as double` falharia sobre um inteiro.

---

## Limitações conhecidas

- **A lista de ordens de serviço não é persistida localmente.** Sem conexão, a tela exibe
  erro em vez dos últimos dados conhecidos. Com mais tempo, o repositório serviria do banco
  local e a rede seria apenas atualização.
- **Sem paginação.** O mock devolve cinco registros; uma carga real exigiria paginação ou
  carregamento incremental.
- **O token não é renovado.** A API mock não expõe refresh token, então a expiração leva
  ao login. Em produção, um interceptor tentaria renovar antes de derrubar a sessão.
- **Sem testes automatizados até o momento.**
