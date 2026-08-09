# Inspeção de Campo — Desafio Técnico Orbytis

[![CI](https://github.com/MeloFPedro/desafio-orbytis-inspecao-campo/actions/workflows/ci.yml/badge.svg)](https://github.com/MeloFPedro/desafio-orbytis-inspecao-campo/actions/workflows/ci.yml)

Mini app Flutter de inspeção de campo com persistência local e sincronização offline-first.

Um técnico faz login, consulta suas ordens de serviço, registra uma inspeção com foto e
GPS, salva localmente e sincroniza com a API quando há conexão.

## Estrutura do repositório

- `app/` — aplicativo Flutter (Android)
- `mock-api/` — API mock em Node/Express fornecida no desafio
- `docs/` — enunciado e contrato da API, como fornecidos

---

## Escopo implementado

### Obrigatório

| Requisito | Onde |
|---|---|
| Tela de login consumindo `POST /auth/login` | `features/auth` |
| Token persistido com `flutter_secure_storage` | `AuthRepository` |
| Rotas autenticadas bloqueadas sem token | `_AuthGate` em `app.dart` |
| Logout | ação na barra superior da lista |
| `GET /work-orders` com título, endereço, prioridade e status | `features/work_orders` |
| Estados de carregando, vazio e erro | `WorkOrdersState` |
| Pull-to-refresh | `WorkOrdersPage` |
| Detalhe da OS com descrição e observações do backoffice | cabeçalho do formulário |
| Formulário com observação, foto e localização | `features/inspections` |
| Salvar rascunho / Concluir inspeção | `InspectionsRepository` |
| Banco local sobrevivendo ao encerramento do app | Drift, tabela `inspections` |
| Fila com `draft`, `pending`, `synced`, `failed` | `SyncStatus` |
| Mensagem de erro legível no `failed` | coluna `lastError` |
| Sincronização manual e automática ao recuperar conexão | `SyncService` + `SyncBloc` |
| Envio via `POST /inspections` | `InspectionsApi`, multipart |
| Status atualizado na UI após sincronizar | `Stream` do Drift |
| Histórico de todas as inspeções locais | `SyncHistoryPage` |
| Filtro por status de sincronização | chips na tela de histórico |
| Ação de tentar novamente para `failed` | botão no card |

### Desejável

| Requisito | Situação |
|---|---|
| Gerenciamento de estado com BLoC | quatro blocs — auth, ordens de serviço, formulário e sincronização |
| Modelos imutáveis e codegen coerente | `Equatable` em todos os modelos; Drift para o banco. **Freezed adiado** — ver Decisões técnicas |
| Testes unitários ou de BLoC | oito testes do serviço de sincronização |

### Opcional

| Requisito | Situação |
|---|---|
| Geofence de 200 m | **implementado** — avisa a distância, sem bloquear |
| CI básico | **implementado** — formatação, análise estática e testes no GitHub Actions |
| Campos dinâmicos via `form-schema` | não implementado — ver Limitações |
| Dark mode | não implementado |

---

## Como rodar

### Pré-requisitos

| Ferramenta | Versão | Observação |
|---|---|---|
| Flutter | 3.44 (stable) | `flutter doctor` sem erros no toolchain Android |
| Android Studio | recente | necessário pelo Android SDK e pelo gerenciador de AVD |
| Node.js | 18+ | testado com 24 LTS |
| Emulador Android | API 34+ | ou device físico (ver Base URL) |

O app é **Android-only** — as demais plataformas não foram geradas, conforme o escopo do
desafio.

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

### Base URL

No emulador não é preciso configurar nada: o padrão é `http://10.0.2.2:3000`, o alias que
o emulador Android usa para alcançar o `localhost` da máquina hospedeira.

Em device físico esse endereço não existe. Com o aparelho conectado por USB:

```bash
adb reverse tcp:3000 tcp:3000
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

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

Por **feature**, não por camada: tudo que muda junto fica junto. Alterar o fluxo de
inspeção significa abrir uma pasta, não quatro. O agrupamento por tipo (`blocs/`,
`models/`, `screens/`) funciona em app pequeno e degrada conforme cresce.

Dentro de cada feature, três camadas com a dependência apontando para dentro:

| Camada | Responsabilidade | Conhece |
|---|---|---|
| `domain/` | modelos e regras de negócio | nada |
| `data/` | acesso a API e persistência | `domain` |
| `presentation/` | blocs e telas | `data`, `domain` |

O `domain` não importa Dio nem Flutter, o que o torna testável sem infraestrutura.

### Fluxo de dados

```
UI ──evento──► Bloc ──► Repository ──► Api ──► Dio ──► rede
▲                │
└─────estado─────┘
```

A UI nunca chama repositório: dispara eventos e reconstrói a partir do estado. É o que
atende à separação entre interface, estado e dados pedida no enunciado, e o que torna toda
a lógica testável sem construir widgets.

A camada `Api` conhece apenas HTTP — rotas, status, JSON — e devolve dados crus; traduzir
para objetos de domínio é trabalho do repositório. Assim a biblioteca de rede pode ser
trocada sem tocar em nada acima.

Sem service locator: o `main.dart` constrói os repositórios uma vez e o `flutter_bloc` os
distribui pela árvore. Os blocs de feature nascem **dentro** do ramo autenticado, e são
descartados no logout — sem que dados de uma sessão sobrevivam à seguinte.

### Autenticação

`AuthInterceptor` injeta `Authorization: Bearer <token>` em todas as rotas exceto
`/auth/login`, e detecta `401` em rota protegida.

Um `401` não é erro da tela que fez a chamada — é a sessão que expirou. O tratamento é
centralizado: o interceptor anuncia num `StreamController`, o `AuthBloc` escuta e derruba
a sessão, e as rotas empilhadas são desfeitas. Sem isso, cada bloc precisaria tratar o
caso por conta própria, com mensagens divergentes para a mesma causa.

O stream também resolve uma dependência circular: `AuthBloc → AuthRepository → AuthApi →
Dio → AuthInterceptor`. O interceptor não conhece o bloc, apenas anuncia.

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

O `clientId` é um UUID gerado no dispositivo e é a chave de idempotência definida no
contrato. Usá-lo como chave primária alinha o modelo local ao contrato remoto, em vez de
mantê-lo como coluna secundária ao lado de um inteiro autoincremento.

Os campos de conteúdo são **anuláveis** de propósito: um rascunho é legitimamente
incompleto — o técnico escreve a observação, sai do app e volta depois para a foto. Se o
esquema exigisse esses campos, salvar rascunho seria impossível.

A validação para enviar — observação com dez caracteres, foto e coordenadas — acontece na
transição para `pending`, não no esquema. É a distinção entre o que o banco aceita guardar
e o que a regra de negócio considera pronto. Essas são as mesmas regras que o servidor
aplica: validar antes evita gastar rede com um erro previsível, e faz o técnico descobrir
o problema com o ativo ainda à frente, e não horas depois ao recuperar sinal.

O acesso passa por um DAO que concentra as consultas e um repositório que expõe as
transições de negócio. As leituras da tela de histórico são `Stream`: quando a fila altera
o status de um registro, a lista se atualiza sozinha.

### Captura de evidências

`PhotoService` abre a câmera, reduz a imagem para 1280 px e **copia do cache do sistema
para o diretório de documentos**. O `image_picker` grava no cache, que o Android limpa
quando precisa de espaço — guardar aquele caminho faria a inspeção sobreviver ao
fechamento do app mas não a foto, e a falha apareceria dias depois, na sincronização,
longe da causa. O banco guarda caminho **relativo**, porque o container do app muda entre
reinstalações.

Ao substituir uma foto, a anterior só é apagada depois que a nova está gravada no banco.
Na ordem inversa, uma falha de escrita deixaria a inspeção sem foto alguma.

`LocationService` distingue os quatro modos de falha do GPS: serviço desligado, permissão
negada, permissão negada permanentemente e ausência de sinal dentro do tempo limite. Cada
um exige uma ação diferente do usuário, e só o terceiro é um beco sem saída — a partir da
segunda recusa o Android para de exibir o diálogo e responde "negado" sem sinal visível.
Por isso `LocationFailure` carrega `canOpenSettings`, e a mensagem oferece atalho para as
configurações do app. O `timeLimit` de 20 segundos cobre o quarto caso, o técnico dentro
de uma subestação sem céu visível.

Ambas as capturas gravam no banco imediatamente, em vez de aguardarem "Salvar rascunho".
Se ficassem em memória, um encerramento do app pelo sistema deixaria o arquivo no disco e
a inspeção sem referência a ele.

Quando a posição capturada está a mais de 200 m do ponto da ordem de serviço, o campo
exibe a distância — **aviso, não bloqueio**. GPS impreciso é comum em campo, e travar o
registro de quem está no local seria pior do que aceitar uma coordenada duvidosa com aviso
visível.

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

`draft` nunca vai para a API. O retry manual zera o contador de tentativas: é uma nova
decisão do técnico, não a continuação da sequência anterior de falhas.

### Classificação de erro

A decisão entre `failed` e nova tentativa vem de `Failure.isPermanent`, e não de uma
cadeia de condicionais dentro do serviço — assim é testável isoladamente e não diverge
entre pontos de uso:

| Situação | Classificação | Destino |
|---|---|---|
| Sem rede, timeout, DNS, `5xx` | transiente | `pending` com backoff |
| `400` payload inválido | permanente | `failed` com a mensagem do campo |
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
memória, fechar o app zeraria o contador e o aparelho voltaria martelando a API — o que é
inaceitável num app sujeito a ser encerrado pelo sistema a qualquer momento.

### Gatilhos

| Gatilho | Backoff | Retorno visual |
|---|---|---|
| Botão de sincronizar | ignora | mensagem na tela |
| Conectividade restaurada | ignora | silencioso |
| Login | ignora | silencioso |
| Conclusão de inspeção | respeita | silencioso |
| Abertura do histórico | respeita | silencioso |
| Temporizador (1 min) | respeita | silencioso |

Os três primeiros ignoram o adiamento porque representam **informação nova**: o backoff
foi calculado sob a premissa de que a rede estava ruim, e cada um deles indica que a
premissa mudou. Concluir uma inspeção não diz nada sobre a rede, e o temporizador menos
ainda — forçar ali truncaria o crescimento exponencial em um minuto.

O temporizador existe porque, sem ele, `nextAttemptAt` seria respeitado mas nunca
executado: o adiamento só valeria se outro gatilho aparecesse por acaso depois dele.

Note que **subir o servidor não dispara nada**: do ponto de vista do dispositivo a
conectividade não mudou, e o `connectivity_plus` reporta interfaces de rede, não
alcançabilidade do servidor. Ele serve como gatilho, nunca como garantia — se a tentativa
falhar, o backoff cuida do resto.

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
inflaria a imagem em cerca de 33% contra o limite de 8 MB do servidor, e a foto já é
reduzida para 1280 px na captura.

---

## Decisões técnicas

### Stack

**BLoC** para gerência de estado, alinhado à stack indicada no enunciado. O modelo
evento → estado torna a lógica testável sem construir widgets.

**Dio** para rede, pelos interceptors — o token é injetado num único lugar em vez de ser
repetido em cada chamada.

**Drift** como banco local. As três razões, em ordem de peso neste projeto:

1. **Consultas reativas.** O Drift devolve `Stream` de resultados, e a tela de histórico
   se atualiza sozinha quando a fila muda um status. Sem isso, cada alteração exigiria
   notificar a UI explicitamente — o tipo de acoplamento onde estados divergem.
2. **SQL verificado em tempo de compilação.** Erro de coluna vira erro de build, não
   exceção no aparelho do técnico.
3. **Migrações versionadas**, com caminho documentado para evoluir o esquema.

**Freezed adiado.** O escopo desejável cita "modelos imutáveis (Freezed) e/ou codegen
coerente". Preferi priorizar o escopo obrigatório a empilhar duas ferramentas de geração
de código simultaneamente — cada uma tem sua própria classe de problemas de build.
Imutabilidade e igualdade por valor vêm de `Equatable`, sem codegen; o Drift cobre a parte
de geração.

### Erros: transporte vs. protocolo

O Dio é configurado com `validateStatus: (_) => true`, ou seja, **nenhum status HTTP lança
exceção**:

- `DioException` significa falha de transporte — sem rede, timeout, DNS. Sempre transiente.
- `response.statusCode` significa que o servidor respondeu, inclusive com erro. O status
  decide se o erro é permanente.

Com o comportamento padrão do Dio, um `401` de senha errada e uma queda de Wi-Fi chegariam
ambos como `DioException`, e a fila precisaria adivinhar a diferença.

O `ValidationFailure` produzido localmente usa o mesmo formato `campo → mensagens` que a
API devolve num `400`, então a tela renderiza os dois sem saber de onde o erro veio.

### Onde há BLoC e onde não há

Quatro blocs, todos onde existe decisão a tomar: autenticação, lista de ordens de serviço,
formulário e sincronização.

**A fila não é um bloc.** `SyncService` vive fora da árvore de widgets, porque precisa
rodar quando a conexão volta, independentemente da tela em que o técnico esteja. Se a
lógica morasse num bloc, pararia ao sair da tela que o criou. O `SyncBloc` apenas aciona e
expõe o andamento, e fica na raiz da árvore para que o ouvinte de conectividade sobreviva
à navegação.

**O histórico não tem bloc.** O Drift já expõe a lista como `Stream`, e o `StreamBuilder`
cancela a assinatura anterior ao trocar de stream — o comportamento necessário na mudança
de filtro. Um bloc ali seria repasse sem lógica, e precisaria do transformador
`restartable()` para não deixar duas assinaturas ativas.

### Modelagem de estados

Dois padrões diferentes, de propósito. O critério: **estados separados quando os dados são
disjuntos; estado único com campo de status quando os mesmos dados persistem através das
transições.**

Em `AuthState`, `AuthAuthenticated` carrega usuário e `AuthLoading` não carrega nada —
separar torna combinações impossíveis inexprimíveis. No formulário de inspeção, `clientId`
e rascunho existem em todos os momentos, e estados separados obrigariam a copiar os mesmos
dados a cada transição.

As classes seladas permitem `switch` exaustivo: um estado novo faz o compilador apontar
todos os lugares que precisam decidir o que fazer com ele.

### Classe do Drift usada como modelo de domínio

A `Inspection` gerada é imutável, tem `copyWith` e igualdade por valor. Um modelo de
domínio paralelo, com mapeamento nos dois sentidos, isolaria a apresentação da
persistência — mas custaria cerca de 80 linhas para proteger contra uma troca de banco que
não está no horizonte deste projeto.

O acoplamento é real e assumido. Num sistema com mais de uma fonte de dados para a mesma
entidade, a decisão se inverteria.

### Status da ordem de serviço não é alterado pelo app

O contrato expõe apenas leitura de ordens de serviço — não há `PATCH` nem endpoint de
transição. Alterar o `status` localmente seria pior do que não alterar: a próxima chamada
a `GET /work-orders` traria o valor antigo de volta e o técnico veria o campo oscilar.

Em compensação, o card exibe um selo derivado das inspeções locais — "Inspeção: Pendente".
É informação da qual o app é dono, e responde à pergunta real do técnico: *em quais destas
eu já trabalhei?*

### Parsing tolerante a dados inesperados

`WorkOrderPriority` e `WorkOrderStatus` têm um caso `unknown` de fallback: um valor não
previsto marca aquela OS como desconhecida em vez de derrubar a lista inteira. Coordenadas
são lidas como `num` antes de virar `double`, porque JSON não distingue `-7` de `-7.0`.

Num app de campo, mostrar dado parcial é preferível a mostrar tela de erro.

---

## Testes

```bash
cd app
flutter test
```

Oito testes cobrem o `SyncService`, que concentra as regras avaliadas como críticas:

| Teste | Regra verificada |
|---|---|
| sucesso | marca `synced`, guarda o `serverId` e conta a tentativa |
| erro permanente | `400` vai para `failed` sem reagendar |
| erro transiente | permanece `pending` com nova tentativa agendada |
| `401` | interrompe a fila sem marcar nada, e não tenta os seguintes |
| teto de tentativas | transiente vira `failed` na quinta |
| reenvio | reutiliza o mesmo `clientId` |
| foto ausente | erro permanente detectado sem gastar rede |
| mutex | chamada concorrente é descartada |

Os dublês são escritos à mão, sem biblioteca de mocking nem geração de código:
implementar `noSuchMethod` permite cobrir só os métodos usados, e qualquer chamada
inesperada estoura em vez de devolver silêncio.

Os testes não usam banco real. O SQLite nativo exigiria a biblioteca disponível para a VM
do Dart, o que é atrito desnecessário — as asserções verificam **quais campos o serviço
decide gravar**, que é exatamente a lógica em questão.

---

## Limitações conhecidas e próximos passos

- **A lista de ordens de serviço não é persistida localmente.** Sem conexão, a tela exibe
  erro em vez dos últimos dados conhecidos. Com mais tempo, o repositório serviria do banco
  local e a rede seria apenas atualização — a mesma estrutura já usada para inspeções.
- **Um técnico por dispositivo.** O banco local não é segmentado por usuário: trocar de
  conta no mesmo aparelho expõe os rascunhos da sessão anterior, e uma inspeção enviada por
  outro usuário seria atribuída a ele, já que o servidor grava `createdBy` a partir do
  token de quem envia. A correção seria uma coluna de proprietário filtrando as consultas —
  e deliberadamente **não** limpar o banco no logout, o que destruiria inspeções ainda não
  sincronizadas.
- **O token não é renovado.** A API mock não expõe refresh token, então a expiração leva ao
  login. Em produção, um interceptor tentaria renovar antes de derrubar a sessão.
- **Fotos perdidas por encerramento do sistema não são recuperadas.** Se o Android matar o
  app enquanto a câmera está em primeiro plano, o resultado da captura se perde. O
  `image_picker` oferece `retrieveLostData()` para esse caso.
- **A tela de formulário não tem saída se a câmera travar.** Durante a captura o formulário
  fica desabilitado, e se o `image_picker` não retornar não há como cancelar.
- **Cobertura de testes concentrada na fila.** Blocs e camada de dados não têm testes; a
  prioridade foi a lógica com maior risco de regressão silenciosa.
- **Campos dinâmicos não implementados.** `GET /work-orders/:id/form-schema` existe no
  contrato, mas o mock devolve o mesmo esquema para qualquer ordem de serviço — os quatro
  campos estão fixos no `server.js`. Um renderizador dinâmico demonstraria flexibilidade
  que os dados não exercitam, ao custo de reescrever um formulário já verificado. Com mais
  tempo, seria o próximo passo, junto de um mock que variasse o esquema por tipo de ativo.
- **Sem paginação.** O mock devolve cinco registros; uma carga real exigiria paginação ou
  carregamento incremental.
- **Papéis não são usados.** O contrato prevê `field_technician` e `admin`, e o `role` é
  persistido, mas nenhuma tela distingue os dois. Uma visão de supervisão exigiria endpoint
  e permissão que o mock não expõe.
- **O mock não vincula ordens de serviço a técnicos.** `GET /work-orders` devolve a lista
  completa para qualquer token válido, enquanto `GET /inspections` filtra por `createdBy`.
  A assimetria é da API mock; o app exibe o que recebe.
