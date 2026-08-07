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

O código gerado pelo Drift está versionado, então não é necessário rodar o gerador para
executar o projeto. Ao alterar o esquema do banco:

```bash
dart run build_runner build
```

### 3. Testes

```bash
cd app
flutter test
```

Oito testes cobrem o serviço de sincronização: sucesso com `serverId`, erro permanente
versus transiente, `401` interrompendo a fila sem marcar nada, teto de tentativas, reuso
do `clientId` no reenvio e o mutex contra execução dupla.

Os dublês são escritos à mão — sem biblioteca de mocking nem geração de código.

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

### Organização

```
app/lib/
├── main.dart              # monta o grafo de dependências
├── app.dart               # providers e roteamento por estado de autenticação
├── core/                  # transversal às features
│   ├── error/             # tipos de falha e tradução de erros HTTP
│   ├── network/           # cliente Dio e interceptor de autenticação
│   ├── database/          # esquema e acesso ao banco local
│   ├── media/             # captura e armazenamento de fotos
│   └── location/          # GPS e cálculo de distância
└── features/
    ├── auth/
    ├── work_orders/
    ├── inspections/
    └── sync/
```

Por **feature**, não por camada: tudo que muda junto fica junto. Dentro de cada uma, três
camadas com dependência apontando para dentro:

| Camada | Responsabilidade | Conhece |
|---|---|---|
| `domain/` | modelos e regras de negócio | nada |
| `data/` | acesso a API e persistência | `domain` |
| `presentation/` | blocs e telas | `data`, `domain` |

### Fluxo de dados

```
UI ──evento──► Bloc ──► Repository ──► Api ──► Dio ──► rede
▲                │
└─────estado─────┘
```

A UI nunca chama repositório: dispara eventos e reconstrói a partir do estado. Toda a
lógica é testável sem construir widgets.

A camada `Api` conhece apenas HTTP — rotas, status, JSON — e devolve dados crus; traduzir
para objetos de domínio é trabalho do repositório.

### Injeção de dependência

Sem service locator. O `main.dart` constrói os repositórios uma única vez e o
`flutter_bloc` os distribui pela árvore via `RepositoryProvider`; os blocs vêm de
`BlocProvider`, que cuida do ciclo de vida.

Os blocs de feature nascem **dentro** do ramo autenticado da árvore, e são descartados no
logout — sem que dados de uma sessão sobrevivam à seguinte.

### Autenticação

`AuthInterceptor` injeta `Authorization: Bearer <token>` em todas as rotas exceto
`/auth/login`, e detecta `401` em rota protegida.

Um `401` não é erro da tela que fez a chamada — é a sessão que expirou. O tratamento é
centralizado: o interceptor anuncia num `StreamController`, o `AuthBloc` escuta e derruba
a sessão. O stream também resolve a dependência circular `AuthBloc → AuthRepository →
AuthApi → Dio → AuthInterceptor`: o interceptor não conhece o bloc, apenas anuncia.

A sessão é restaurada lendo token e usuário do armazenamento seguro, sem consultar
`GET /auth/me`. Num app de campo, exigir rede para reentrar deixaria o técnico de fora
justamente onde ele mais precisa.

### Persistência local

Uma tabela, `inspections`, desenhada em torno do ciclo de vida da sincronização:

| Grupo | Colunas |
|---|---|
| Identidade | `clientId` (PK), `serverId` |
| Conteúdo | `observation`, `condition`, `photoPath`, `latitude`, `longitude`, `capturedAt` |
| Fila | `syncStatus`, `lastError`, `retryCount`, `nextAttemptAt` |
| Auditoria | `workOrderId`, `createdAt`, `updatedAt` |

O `clientId` é gerado no dispositivo e é a chave de idempotência do contrato. Usá-lo como
chave primária alinha o modelo local ao contrato remoto.

Os campos de conteúdo são **anuláveis** de propósito: um rascunho é legitimamente
incompleto — o técnico escreve a observação, sai do app e volta depois para a foto. A
validação para enviar acontece na transição para `pending`, não no esquema.

O acesso passa por um DAO que concentra as consultas e um repositório que expõe as
transições de negócio. As leituras da tela de histórico são `Stream`: quando a fila altera
o status de um registro, a lista se atualiza sozinha.

### Captura de evidências

`PhotoService` abre a câmera, reduz a imagem para 1280 px e **copia do cache do sistema
para o diretório de documentos** — o Android limpa o cache quando precisa de espaço, e
guardar aquele caminho faria a inspeção sobreviver ao fechamento do app mas não a foto. O
banco guarda caminho relativo, porque o container muda entre reinstalações.

`LocationService` distingue os quatro modos de falha do GPS: serviço desligado, permissão
negada, permissão negada permanentemente e ausência de sinal. Só o terceiro é um beco sem
saída — a partir da segunda recusa o Android para de exibir o diálogo e responde "negado"
sem sinal visível —, então `LocationFailure` carrega `canOpenSettings` e a mensagem
oferece atalho para as configurações.

Ambas as capturas gravam no banco imediatamente, em vez de aguardarem "Salvar rascunho".

Quando a posição está a mais de 200 m do ponto da OS, o campo exibe a distância — **aviso,
não bloqueio**. GPS impreciso é comum em campo, e travar o registro de quem está no local
seria pior do que aceitar uma coordenada duvidosa com aviso visível.

---

## Fila de sincronização

### Estados

```
        Salvar rascunho          Concluir
   ─────────────────────►  draft ─────────►  pending
                                                │
                        ┌───────────────────────┤
                        │                       │
              erro transiente               200 ou 201
              (rede, timeout, 5xx)              │
                        │                       ▼
                        ▼                    synced
                pending + backoff
                        │
              teto de 5 tentativas
              ou erro permanente
              (400, 404, 409)
                        │
                        ▼
                     failed ──── retry manual ────► pending
```

`draft` nunca vai para a API.

### Classificação de erro

A decisão entre `failed` e nova tentativa vem de `Failure.isPermanent`, e não de uma
cadeia de condicionais dentro do serviço:

| Situação | Classificação | Destino |
|---|---|---|
| Sem rede, timeout, DNS, `5xx` | transiente | `pending` com backoff |
| `400` payload inválido | permanente | `failed` |
| `404`, `409` | permanente | `failed` |
| Foto ausente no dispositivo | permanente | `failed`, sem gastar rede |
| `401` | — | **nada é marcado**, a fila para |

O `401` é o caso que mais importa acertar. Sessão expirada não diz nada sobre a inspeção:
marcá-la como `failed` faria o técnico encontrar todos os registros em vermelho por causa
de um token vencido, e teria que reenviá-los um a um. A passada é interrompida, tudo
permanece `pending`, e sobe sozinho depois do próximo login.

### Backoff

Falha transiente incrementa `retryCount` e grava `nextAttemptAt` — 30 s, 1 min, 2 min,
4 min, com teto de uma hora. Na quinta tentativa o registro vai para `failed`.

O estado do adiamento fica **na linha da tabela**, não numa variável do serviço. Em
memória, fechar o app zeraria o contador e o aparelho voltaria martelando a API.

### Gatilhos

| Gatilho | Backoff | Retorno visual |
|---|---|---|
| Botão de sincronizar | ignora | mensagem na tela |
| Conectividade restaurada | ignora | silencioso |
| Login | ignora | silencioso |
| Abertura do histórico | respeita | silencioso |
| Temporizador (1 min) | respeita | silencioso |

Os três primeiros ignoram o adiamento porque representam **informação nova**: o backoff
foi calculado sob a premissa de que a rede ou o servidor estavam ruins, e cada um deles
indica que a premissa mudou. O temporizador não ignora — passar um minuto não é
informação, e forçar ali truncaria o crescimento exponencial.

O temporizador existe porque, sem ele, `nextAttemptAt` seria respeitado mas nunca
executado: o adiamento só valeria se outro gatilho aparecesse por acaso depois dele.

Note que **subir o servidor não dispara nada**. Do ponto de vista do dispositivo a
conectividade não mudou — o `connectivity_plus` reporta interfaces de rede, não
alcançabilidade do servidor.

### Concorrência

Botão manual, conectividade e temporizador podem coincidir. O serviço tem um mutex: uma
segunda chamada durante uma passada em curso retorna imediatamente com `skipped`, em vez
de aguardar — chamadas acumuladas dispararariam em cascata quando a primeira terminasse.

### Idempotência

Cada inspeção nasce com um `clientId` (UUID) gerado no dispositivo. Reenvios usam o mesmo
valor, e o servidor responde `200` com o registro existente em vez de duplicar.

Por isso o cliente trata **`200` e `201` igualmente como sucesso**. Aceitar apenas `201`
faria todo reenvio parecer falha: o app retentaria, receberia `200` de novo, e nunca
sairia do lugar — exatamente o cenário em que a resposta se perde na volta e o registro já
existe no servidor.

### Envio

`multipart/form-data`, conforme recomendado no contrato. A alternativa JSON com base64
inflaria a imagem em cerca de 33% contra o limite de 8 MB do servidor.

---

## Decisões técnicas

### Stack

**BLoC** para gerência de estado, alinhado à stack indicada no enunciado. O modelo
evento → estado torna a lógica testável sem construir widgets.

**Dio** para rede, pelos interceptors — o token é injetado num único lugar em vez de ser
repetido em cada chamada.

**Drift** como banco local, por três razões: SQL verificado em tempo de compilação;
consultas reativas (`Stream`); e migrações versionadas. A segunda é a decisiva aqui — sem
ela, cada alteração de status feita pela fila exigiria notificar a UI explicitamente,
exatamente o tipo de acoplamento onde estados divergem.

**Freezed adiado.** O escopo desejável cita "modelos imutáveis (Freezed) e/ou codegen
coerente". Preferi priorizar o escopo obrigatório a empilhar duas ferramentas de geração
de código simultaneamente. Imutabilidade e igualdade por valor vêm de `Equatable`.

### Erros: transporte vs. protocolo

O Dio é configurado com `validateStatus: (_) => true`, ou seja, **nenhum status HTTP lança
exceção**:

- `DioException` significa falha de transporte — sem rede, timeout, DNS. Sempre transiente.
- `response.statusCode` significa que o servidor respondeu, inclusive com erro. O status
  decide se o erro é permanente.

Com o comportamento padrão do Dio, um `401` de senha errada e uma queda de Wi-Fi chegariam
ambos como `DioException`, e a fila precisaria adivinhar a diferença.

### Onde há BLoC e onde não há

Quatro blocs, todos onde existe decisão a tomar: autenticação, lista de ordens de serviço,
formulário e sincronização.

**A fila não é um bloc.** `SyncService` vive fora da árvore de widgets, porque precisa
rodar quando a conexão volta, independentemente da tela em que o técnico esteja. O
`SyncBloc` apenas aciona e expõe o andamento.

**O histórico não tem bloc.** O Drift já expõe a lista como `Stream`, e o `StreamBuilder`
cancela a assinatura anterior ao trocar de stream — o comportamento necessário na mudança
de filtro. Um bloc ali seria repasse sem lógica.

### Classe do Drift usada como modelo de domínio

A `Inspection` gerada é imutável, tem `copyWith` e igualdade por valor. Um modelo de
domínio paralelo isolaria a apresentação da persistência, mas custaria cerca de 80 linhas
para proteger contra uma troca de banco que não está no horizonte deste projeto.

O acoplamento é assumido. Num sistema com mais de uma fonte de dados para a mesma
entidade, a decisão se inverteria.

### Status da ordem de serviço não é alterado pelo app

O contrato expõe apenas leitura de ordens de serviço — não há `PATCH` nem endpoint de
transição. Alterar o `status` localmente seria pior do que não alterar: a próxima chamada
a `GET /work-orders` traria o valor antigo de volta e o técnico veria o campo oscilar.

Em compensação, o card exibe um selo derivado das inspeções locais — "Inspeção: Pendente".
É informação da qual o app é dono, e responde à pergunta real do técnico: *em quais destas
eu já trabalhei?*

---

## Limitações conhecidas

- **A lista de ordens de serviço não é persistida localmente.** Sem conexão, a tela exibe
  erro em vez dos últimos dados conhecidos. Com mais tempo, o repositório serviria do banco
  local e a rede seria apenas atualização.
- **Um técnico por dispositivo.** O banco local não é segmentado por usuário: trocar de
  conta no mesmo aparelho expõe os rascunhos da sessão anterior, e uma inspeção
  sincronizada por outro usuário seria atribuída a ele, já que o servidor grava `createdBy`
  a partir do token de quem envia. A correção seria uma coluna de proprietário filtrando as
  consultas — deliberadamente **não** limpando o banco no logout, o que destruiria
  inspeções ainda não sincronizadas.
- **O token não é renovado.** A API mock não expõe refresh token, então a expiração leva ao
  login. Em produção, um interceptor tentaria renovar antes de derrubar a sessão.
- **Sem paginação.** O mock devolve cinco registros; uma carga real exigiria paginação.
- **Papéis não são usados.** O contrato prevê `field_technician` e `admin`, mas nenhuma
  tela distingue os dois. Uma visão de supervisão exigiria endpoint que o mock não expõe.
- **O mock não vincula ordens de serviço a técnicos.** `GET /work-orders` devolve a lista
  completa para qualquer token válido, enquanto `GET /inspections` filtra por `createdBy`.
  A assimetria é da API mock; o app exibe o que recebe.
