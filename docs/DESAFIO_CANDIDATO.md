# Desafio técnico — Desenvolvedor Mobile Flutter

**Prazo sugerido:** até 7 dias corridos  
**Entrega:** repositório Git (público ou privado com acesso) + README  
**Escopo:** app Flutter Android

---

## Contexto

A [Orbytis](https://orbytis.com.br/) desenvolve soluções tecnológicas e softwares personalizados — incluindo aplicativos mobile corporativos — com foco em fluidez operacional, formulários digitais (como o eForms) e inteligência sistêmica. Atua em cenários próximos aos da [Engeselt](https://engeselt.com.br/), empresa de engenharia e operação de campo no setor elétrico (redes de distribuição, subestações, operações técnicas e comerciais), onde técnicos trabalham fora do escritório e precisam registrar ordens de serviço, preencher formulários, anexar evidências (foto + GPS) e sincronizar dados offline.

Neste desafio, você vai construir um **mini app de inspeção de campo**, com foco em arquitetura, persistência local e sync — não em UI sofisticada.

---

## Objetivo

Implementar um app Flutter em que um técnico:

1. Faz login
2. Visualiza uma lista de ordens de serviço (OS)
3. Abre uma OS e preenche um formulário de inspeção (texto + foto + GPS)
4. Salva o resultado **localmente**
5. Sincroniza com a API quando houver conexão
6. Visualiza o status de sincronização de cada inspeção

---



## Escopo obrigatório



### 1. Autenticação

- Tela de login
- Consumir `POST /auth/login` da API mock
- Persistir o token de forma segura
- Bloquear rotas autenticadas sem token
- Logout



### 2. Lista de ordens de serviço

- Consumir `GET /work-orders`
- Exibir título, endereço/local, prioridade e status
- Estados de loading / vazio / erro
- Pull-to-refresh



### 3. Detalhe + formulário de inspeção

Para uma OS, permitir registrar uma inspeção com:

- **Observação**
- **Foto**
- **Localização**
- Botão **Salvar rascunho**
- Botão **Concluir inspeção**



### 4. Persistência local + sync

- Banco local 
- Inspeções devem sobreviver a kill do app
- Fila de sincronização com status claros:
  - `draft` — rascunho
  - `pending` — pronta para sync
  - `synced` — enviada com sucesso
  - `failed` — falhou (com mensagem de erro legível)
- Sync manual (botão) **e** tentativa automática ao recuperar conectividade
- Envio via `POST /inspections` 
- Após sync com sucesso, atualizar status local e refletir na UI



### 5. Tela de histórico / status

- Lista de inspeções locais (todas as OS)
- Filtro por status de sync
- Indicação visual clara do estado de cada item
- Ação de **tentar novamente** para itens `failed`



### 6. Qualidade mínima

- Estrutura de pastas organizada
- Separação UI / estado / dados
- README com: como rodar, decisões técnicas, limitações conhecidas
- Tratamento básico de erros de rede

---



## Escopo desejável

Pontuação extra — faça só se o obrigatório estiver sólido:

- Gerenciamento de estado com **BLoC** 
- Modelos imutáveis (Freezed) e/ou codegen coerente
- Testes unitários ou de BLoC

---



## Escopo opcional

- Campos dinâmicos a partir de `GET /work-orders/:id/form-schema`
- Geofence simples: avisar se o GPS está a mais de 200 m do ponto da OS
- Dark mode e layout cuidadoso para uso outdoor
- CI básico

---



## Fora de escopo (não fazer)

- Backend real / Firebase Auth / Google Sign-In
- Publicação nas lojas
- Biometria, NFC, totem/kiosk
- Mapas avançados, clustering, offline tiles
- Multi-tenant, flavors complexos, i18n completa
- Design system elaborado — UI limpa e funcional basta

---



## API mock

Use a API mock fornecida nesta pasta (`mock-api/`).

Credenciais de teste:


| E-mail                   | Senha      |
| ------------------------ | ---------- |
| `tecnico@orbytis.com.br` | `123456`   |
| `admin@orbytis.com.br`   | `admin123` |


Instruções de subida: ver `mock-api/README.md`.

Contrato completo: ver `CONTRATO_API.md`.

---



## Requisitos técnicos


| Item        | Orientação                                              |
| ----------- | ------------------------------------------------------- |
| Flutter     | Canal stable recente                                    |
| Plataformas | Android                                                 |
| Estado      | Livre — BLoC é diferencial alinhado à nossa stack      |
| Rede        | Livre                                                   |
| Local DB    | Livre; Justificar escolha                               |
| Git         | Histórico legível (commits pequenos > 1 commit monstro) |


**Não é obrigatório** clonar nossa stack interna. Avaliamos clareza de decisões e qualidade da solução.

---



## Entrega esperada

1. Link do repositório Git
2. README contendo:
  - Como instalar dependências e subir o mock
  - Como rodar o app
  - Arquitetura escolhida
  - Como funciona a fila de sincronização
  - O que ficou pendente / o que faria com mais tempo
3. (Opcional) vídeo curto (5–10 min) explicando o fluxo offline → online

---



## Critérios que mais pesam na avaliação

1. Modelagem offline/sync
2. Arquitetura e organização do código
3. Tratamento de erros e estados de UI
4. Qualidade do README e comunicação técnica
5. Testes e robustez da fila

---