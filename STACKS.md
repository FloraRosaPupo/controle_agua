# Stacks do projeto `bebeu` (Flutter + Backend Node/Prisma)

Este documento explica, **stack por stack**, como o projeto funciona e como você navega pelo código com segurança. A ideia é que alguém **júnior** consiga entender o todo e, principalmente, aprender o “jeito pleno” de evoluir o app sem quebrar nada.

---

## Visão geral (o que existe aqui)

O repositório tem dois “mundos”:

- **App mobile (Flutter/Dart)**: fica em `lib/`
- **Backend (Node.js/TypeScript + Express + Prisma)**: fica em `backend/`

O app fala com o backend via HTTP (JSON) usando **Dio**, e autentica com **JWT** (token). Esse token é salvo no celular usando **FlutterSecureStorage**.

---

## Stack do App (Flutter)

### Arquitetura por pastas (como organizar a cabeça)

Dentro de `lib/`, o projeto está bem próximo de uma separação em camadas:

- **`presentation/`**: telas, widgets e estado de UI (Cubits/States)
- **`data/`**: serviços que conversam com API e modelos que representam dados do backend
- **`core/`**: coisas reutilizáveis e “globais” (tema, notificações locais, API client, utilidades)

Pensa assim:

- **Presentation** decide *o que mostrar* e *quando chamar ações*
- **Data/Services** decide *como buscar/salvar dados*
- **Core** fornece infraestrutura (HTTP client, notificações, tema, widget do sistema etc.)

Se você estiver perdido, comece pelo `lib/main.dart`.

---

### Entry point e “injeção” de dependências

O app inicia em `lib/main.dart`:

- Inicializa bindings do Flutter
- Inicializa **HomeWidget** (widget de tela inicial do Android/iOS, dependendo do suporte)
- Inicializa **NotificationService** (notificações locais + timezone)
- Cria instâncias “singleton-like” do app:
  - `ApiClient`
  - `AuthService`
  - `WaterService`
  - `SettingsService`
- Checa se existe token local: `authService.isLoggedIn()`
- Configura rotas com **GoRouter**
- Sobe a árvore de providers:
  - `RepositoryProvider<AuthService>` (para compartilhar o `AuthService`)
  - `MultiBlocProvider` (para compartilhar Cubits globais como Home/History/Settings/Notification)

**Jeito pleno de pensar**: `main.dart` é onde você monta o “container” do app (as dependências) e define navegação/tema. Evite enfiar regra de negócio pesada aqui.

---

## Stack: Navegação com `go_router`

O `GoRouter` define as rotas principais:

- `/splash` → `SplashPage` (decide redirecionamento dependendo do login)
- `/login` → `LoginPage` com `LoginCubit`
- `/register` → `RegisterPage` com `RegisterCubit`
- `/home` → `HomePage`

### O que é e por que existe

Navegação em Flutter é “trocar telas”. O `go_router` é uma biblioteca que organiza isso com:

- **URLs/paths** (`/login`, `/home`), parecido com web
- **Centralização** das rotas em um lugar só (fica mais fácil manter)
- **API simples** para navegar (`go`, `push`, `pop`) e para proteger rotas (`redirect`)

Sem um roteador, você acaba com `Navigator.push(...)` espalhado pelo app inteiro, o que vira bagunça quando o app cresce.

### Como funciona neste projeto

O roteador é criado em `lib/main.dart` e a app usa `MaterialApp.router(...)` com `routerConfig: widget.router`. Isso significa que:

- Quem “manda” nas telas é o `GoRouter`.
- Você navega sempre por **paths**.

### Quando usar `go` vs `push` (explicação, não só regra)

Pensa em “pilha de telas”:

- **`push`** coloca uma tela **em cima** da outra. O usuário pode voltar e ver a tela anterior. Bom para “fluxos” (Login → Register, Home → Detalhe).
- **`go`** troca a rota atual. É como “teleportar” para um destino. Bom quando a tela anterior não faz mais sentido voltar (ex.: depois do login, não faz sentido voltar pra tela de login).

### Como usar o `go_router` na prática (passo a passo)

- Para **ir para a Home depois do login**:
  - No `LoginCubit`, após `LoginSuccess`, na tela use `context.go('/home')`.
- Para **abrir a tela de cadastro a partir do login**:
  - No botão “Criar conta”, use `context.push('/register')` (empilha a tela, permite voltar).
- Para **criar uma nova rota**:
  - Crie a página em `presentation/...`.
  - No `GoRouter` de `main.dart`, adicione um `GoRoute(path: '/minha-rota', builder: ...)`.
  - Use `context.go('/minha-rota')` onde precisar.

**Boas práticas**:

- Navegação deve depender de **estado** (ex.: login sucesso) e não de “ifs” espalhados na UI.
- Para rotas protegidas (precisar estar logado), um passo “pleno” seria adicionar `redirect` no `GoRouter` usando o estado de auth (hoje o app faz a checagem antes e usa splash).

### Erros comuns (e por que dão problema)

- **Misturar `Navigator.push` com `go_router`** sem critério: você perde previsibilidade (fica difícil saber quem controla a navegação).
- **Navegar “do nada” dentro do build**: pode causar loops de build. Preferir reagir a estado com `BlocListener`/`BlocConsumer` e navegar quando o estado mudar.

---

## Stack: Gerenciamento de estado com Bloc/Cubit

O projeto usa:

- **`flutter_bloc`** e **`bloc`**
- Padrão **Cubit + State** (mais simples que Bloc com eventos, ótimo para apps pequenos/médios)

### O que é (explicação de verdade)

Flutter renderiza a UI com base em **estado** (dados atuais). “Gerenciamento de estado” é o jeito que você:

- guarda esses dados
- muda esses dados quando o usuário faz algo
- faz a tela se atualizar automaticamente

O padrão do projeto é **Cubit + State**:

- **State** = “fotografia” do que a tela precisa agora (loading? dados? erro?)
- **Cubit** = “cérebro” que executa ações e emite novas fotografias

Isso separa responsabilidades:

- UI só desenha e dispara ações.
- Cubit orquestra a lógica de tela.
- Service conversa com API/storage.

### Como ler um Cubit (como se fosse uma receita)

Um Cubit geralmente tem:

- Dependências (services)
- Métodos assíncronos (load/update)
- `emit(...)` para mudar estado

Exemplo real: `LoginCubit`

- Emite `LoginLoading()`
- Chama `AuthService.login(...)`
- Emite `LoginSuccess()` ou `LoginFailure(...)`

**Jeito pleno**:

- “Estado” deve ser previsível e tipado.
- “Service” não deve mexer em UI.
- Cubit deve orquestrar: chamar service, tratar erro, emitir estado.

### Como usar Cubit na prática (com o “porquê”)

Quando você cria um Cubit novo, você está criando um “módulo” de comportamento da tela. O objetivo é:

- **não** espalhar regra de negócio na UI
- deixar o fluxo testável (dá pra testar Cubit sem abrir o app)
- padronizar loading/erro/sucesso

- **Criar um novo Cubit**:
  - Crie uma classe de estado (ex.: `ProfileState`) com os campos que a tela precisa.
  - Crie um `ProfileCubit extends Cubit<ProfileState>` recebendo services no construtor.
  - Dentro do Cubit crie métodos como `loadProfile()` ou `saveProfile(...)` que:
    - Chamam o service.
    - Fazem `emit(state.copyWith(...))` com os novos dados ou erro.
- **Usar na tela**:
  - Prover com `BlocProvider(create: (_) => ProfileCubit(meuService)..loadProfile(), child: MinhaTela())`.
  - Consumir com `BlocBuilder<ProfileCubit, ProfileState>` para desenhar a UI conforme o estado.

### Erros comuns (e como um pleno evita)

- **Guardar coisas “de UI” no service** (ex.: `BuildContext`, snackbars): service vira bagunça e fica impossível testar.
- **Emitir estado dentro de `build`**: causa loop. Emita no `initState`, em callbacks (onPressed), ou em efeitos (listener).
- **State “sem modelagem”**: quando tudo é `dynamic` e `Map`, vira erro em runtime. Prefira models/fields tipados.

### Cubits que existem (na prática do projeto)

Você vai encontrar Cubits principais em:

- `lib/presentation/auth/cubit/`
  - `LoginCubit` / `RegisterCubit`
- `lib/presentation/home/cubit/`
  - `HomeCubit` (dados de hoje)
  - `HistoryCubit` (histórico)
  - `SettingsCubit` (preferências do usuário)
  - `NotificationCubit` (preferências de alertas)

---

## Stack: HTTP Client com `dio`

### O que é e por que existe

O `dio` é a biblioteca que faz HTTP no Flutter: GET/POST/PUT/DELETE, headers, interceptors, timeouts, etc.

O problema em apps reais é: se cada lugar configurar `Dio` do seu jeito, você perde:

- consistência de `baseUrl`
- consistência de headers (ex.: `Authorization`)
- logs e tratamento de erros

Por isso existe o `ApiClient`: **um único lugar** para configurar e reaproveitar o Dio.

### `ApiClient` (a “configuração do Dio”)

Em `lib/core/api/api_client.dart`:

- Define `baseUrl` (hoje apontando pra Railway)
- Define timeouts
- Define headers default:
  - `Content-Type: application/json`
  - `x-timezone-offset`: minutos do fuso (usado pelo backend para “dia do usuário”)
- Em debug, adiciona `LogInterceptor`
- Tem métodos:
  - `setToken(token)` → adiciona `Authorization: Bearer <token>`
  - `clearToken()` → remove header

**Jeito pleno**:

- Centralizar headers/interceptors aqui evita duplicação.
- Se precisar tratar refresh token, retry, rate-limit etc., é aqui (interceptors).

### Como usar o `dio` na prática (com explicação)

O padrão é: **Service → `_apiClient.dio`**.

Por quê? Porque:

- o Service é a “fronteira” com o backend (contrato)
- o Cubit não deve conhecer detalhes de HTTP
- a UI não deve conhecer nada de HTTP

- **Dentro de um Service**:
  - Sempre receba um `ApiClient` no construtor (como já acontece em `WaterService`, `AuthService`, etc.).
  - Use `_apiClient.dio.get/post/put/delete(...)` para chamar o backend.
  - Trate `DioException` com `try/catch` e retorne mensagens amigáveis para o Cubit.
- **Nunca** crie `Dio()` direto em widget ou Cubit; isso quebra a configuração central (baseUrl, headers, interceptors).

### Erros comuns

- **Tratar erro só por `statusCode`**: em Dio, o erro muitas vezes vem como `DioException` com `response.data`. O projeto já faz certo capturando `DioException`.
- **Não pensar no contrato**: backend muda o JSON e o app quebra. Por isso models + `fromJson` ajudam.

---

## Stack: Services (camada de integração com a API)

### O que é e por que existe

Service é uma classe que representa “um conjunto de ações” contra uma fonte de dados. Aqui a fonte é o **backend HTTP**.

Exemplos:

- `AuthService`: autenticação e token
- `WaterService`: hidratação e histórico
- `SettingsService`: configurações do usuário

O motivo de existir é separar “HTTP e contrato” do resto do app.

### Como funciona neste projeto

Services moram em `lib/data/services/`, recebem um `ApiClient` e expõem métodos bem objetivos. Eles retornam:

- models (ex.: `DailyWaterDataModel`)
- `bool` / `Map` quando ainda não foi modelado
- `Exception` em caso de erro (para o Cubit decidir o que mostrar)

Services são classes que chamam o backend via `ApiClient.dio`.

### `AuthService` (login, cadastro, JWT, logout)

Em `lib/data/services/auth_service.dart`:

- `login(email, password)`
  - POST `/login`
  - pega `token`
  - salva token no storage seguro
  - chama `apiClient.setToken(token)` para autenticar as próximas requests
- `register(...)`
  - POST `/register`
  - em sucesso, chama `login(...)` automaticamente
- `logout()`
  - apaga token do storage
  - remove Authorization do Dio
- `isLoggedIn()`
  - lê token do storage
  - se existir, aplica no Dio e retorna `true`

**Por que `FlutterSecureStorage`?**

- É mais apropriado para segredos (token) do que `SharedPreferences`.
- No Android, está configurado com `encryptedSharedPreferences: true`.

### `WaterService` (hidratação)

Em `lib/data/services/water_service.dart`:

- `getTodayData()` → GET `/water/today`
- `addWater(amount)` → POST `/water`
- `getHistory(period/date)` → GET `/water/history`
- `deleteWater(id)` → DELETE `/water/:id`

### `SettingsService` (configurações do usuário)

Em `lib/data/services/settings_service.dart`:

- `getSettings()` → GET `/settings`
- `updateSettings(data)` → PUT `/settings`

Repara que o payload é flexível: o app manda apenas o que mudou.

### Como usar Services na prática (entendendo o fluxo)

- **Fluxo típico** (ex.: mudar meta diária):
  - Na tela, o usuário altera o valor (slider/campo de texto).
  - A tela chama um método do `SettingsCubit.updateSetting('dailyGoal', novoValor)`.
  - O `SettingsCubit` chama `SettingsService.updateSettings({'dailyGoal': valorTratado})`.
  - Quando der certo, o Cubit atualiza o estado; a UI reconstrói sozinha.
- **Regra de ouro**:
  - A UI **nunca** deve chamar `Dio` diretamente.
  - Sempre passar por um Service + Cubit para ficar fácil de testar, trocar backend, etc.

### Erros comuns

- **Service retornando `Map` em tudo**: funciona no começo, mas vira dívida técnica. O “pleno” vai criando models aos poucos.
- **Service misturando muita coisa** (ex.: auth + settings): prefira serviços focados.

---

## Stack: Storage (SharedPreferences vs SecureStorage) e JWT

No projeto existem dois tipos de “armazenamento local”:

- **`flutter_secure_storage`**: para **JWT** (`jwt_token`)
- **`shared_preferences`**: geralmente usado para preferências simples (no código atual, a maior parte de settings vem do backend; o shared_preferences aparece como dependência e pode ser usado para cache/local config)

### O que é JWT (explicação simples)

JWT é um token assinado pelo servidor. Ele funciona como um “crachá”: quando o app envia esse token, o backend consegue validar e descobrir **qual usuário** está fazendo a requisição.

Aqui o backend:

- gera o token no `POST /login`
- valida o token em `authMiddleware` nas rotas protegidas

### Por que salvar token no SecureStorage

Porque token é segredo. `FlutterSecureStorage` usa mecanismos do sistema (Keychain no iOS, storage criptografado no Android) e é mais seguro que `SharedPreferences`.

### JWT (como o token flui)

Fluxo:

1. Usuário loga → backend responde `token`
2. App salva token no SecureStorage
3. App adiciona `Authorization: Bearer <token>` no `Dio`
4. Todas as rotas protegidas do backend exigem esse header

**Jeito pleno**:

- Nunca logar o token em produção.
- Tratar 401/403 com uma estratégia: deslogar e mandar pro login, ou tentar refresh (se existir).

### Como usar Storage e JWT na prática (o que acontece “por baixo”)

- **Para saber se o usuário já está logado**:
  - Use `await authService.isLoggedIn()` (já é feito no `main.dart` para decidir a navegação inicial).
- **Para logar**:
  - A UI chama `LoginCubit.login(email, senha)`.
  - O Cubit chama `AuthService.login`, que:
    - Salva o token no `FlutterSecureStorage`.
    - Chama `_apiClient.setToken(token)` para que o Dio envie `Authorization` automaticamente.
- **Para deslogar**:
  - Crie uma ação (ex.: botão “Sair”) que chama `authService.logout()` via Cubit/Controller.
  - Depois use `context.go('/login')` para mandar o usuário pra tela de login.
- **Quando usar SharedPreferences**:
  - Para coisas não sensíveis: preferências locais, flags de onboarding, etc.

### Erros comuns

- **Esquecer de aplicar token no Dio**: aí todas as rotas protegidas viram 401.
- **Guardar token em SharedPreferences**: risco maior (não é o local ideal para segredo).

---

## Stack: Notificações locais (`flutter_local_notifications` + `timezone`)

O agendamento é feito no **app**, não no backend.

### O que é e por que é “stack”

Notificação local é agendada e disparada pelo próprio app no dispositivo (não depende de servidor para “enviar push”).

Aqui você tem 2 problemas que viram stack:

- **timezone**: para o “8:00” ser 8:00 do usuário, não “8:00 UTC”.
- **limites/permissões do Android**: alarmes exatos, Doze, limites de quantidade, canais.

### `NotificationService` (infra de notificação)

Em `lib/core/services/notification_service.dart`:

- Inicializa timezone (`timezone`)
- Cria canais Android (com/sem vibração)
- Pede permissões (Android 13+ e alarmes exatos)
- Agenda lembretes com `zonedSchedule(...)`
- Mantém uma fila `_scheduleChain` para evitar agendamentos concorrentes
- Implementa lógica para:
  - Agendar por “todo dia” (hora fixa) se os dias ativos forem todos
  - Agendar por “dias da semana + hora” se for seleção parcial
  - Respeitar limite prático de alarmes no Android (usa `maxAlarms = 420`)

### Preferências de alerta (de onde vêm)

O app carrega preferências via backend:

- `NotificationCubit.loadPreferences()` chama `SettingsService.getSettings()`
- O backend devolve `notificationSettings`
- O app converte para `NotificationPreferences`

#### Conversão de dias da semana (detalhe importante)

O backend usa (Prisma):

- `daysOfWeek`: `0=Domingo, 1=Segunda, ... 6=Sábado`

O Flutter usa `DateTime.weekday`:

- `1=Segunda, ... 7=Domingo`

Por isso `NotificationPreferences.fromJson()` faz o mapeamento `0 -> 7` e `toJson()` faz `7 -> 0`.

**Jeito pleno**:

- Documentar e testar essas conversões, porque bug de “dia errado” é clássico.

### Como usar notificações na prática (entendendo o que está acontecendo)

- **Carregar e aplicar preferências do backend**:
  - `NotificationCubit.loadPreferences()` já:
    - Busca `/settings` via `SettingsService`.
    - Converte em `NotificationPreferences`.
    - Chama `NotificationService.scheduleHydrationReminders(prefs)` se estiver `enabled`.
- **Atualizar preferências quando o usuário mexe na tela**:
  - `NotificationSettingsView` chama `_updatePrefs(prefs.copyWith(...))`.
  - `_updatePrefs` chama `NotificationCubit.updatePreferences(...)`.
  - O Cubit:
    - Faz update otimista do estado.
    - Chama `SettingsService.updateSettings({'notifications': prefs.toJson()})`.
    - Reagenda os lembretes chamando `NotificationService.scheduleHydrationReminders`.
- **Notificação de progresso**:
  - Sempre que os dados de hoje mudam (ex.: após `addWater`), você pode chamar
    `NotificationService.checkProgressAndNotify(current: total, goal: meta, userName: nome)`
    para mostrar uma notificação com barra de progresso.

### Erros comuns (por que notificação “some”)

- **Fuso/hora errada**: sem timezone bem definido, o agendamento sai fora do esperado.
- **Android sem alarme exato**: o projeto tenta pedir permissão; sem ela, pode atrasar.
- **Agendar demais**: Android tem limite; por isso existe `maxAlarms` e lógica de reduzir pontos.

---

## Stack: Tema e UI

### Tema (light/dark/system)

O tema vive em `lib/core/theme/` (ex.: `app_theme.dart`) e é aplicado assim:

- `MyApp` usa `ValueListenableBuilder<ThemeMode>` para reagir a mudanças
- `SettingsCubit` aplica tema quando carrega settings do backend e quando usuário muda

### Widgets e telas

Ficam em `lib/presentation/...`.

Exemplo: `NotificationSettingsView` usa `BlocBuilder<NotificationCubit, NotificationState>` e faz “update otimista” (atualiza UI antes de confirmar o backend).

**Jeito pleno**:

- Widgets devem ser “burros”: renderizar o estado e disparar ações.
- O Cubit faz o trabalho e decide o próximo estado.

---

## Stack: Home Widget (`home_widget`)

O projeto usa `home_widget` para atualizar/escutar interações do widget na tela inicial:

- Em `main.dart`: registra callback `HomeWidget.registerInteractivityCallback(...)`
- Usa `WidgetService.updateHomeWidget(...)` para atualizar dados no widget (ex.: progresso)

Esse é um “extra” que conecta app com o sistema operacional.

---

## Stack do Backend (Node.js + TypeScript)
### O que é e por que existe

O backend é quem:

- cadastra/loga o usuário
- guarda os dados no banco (PostgreSQL)
- valida o JWT para proteger dados
- entrega JSON pro app consumir

Sem backend, o app teria que guardar tudo localmente (mais simples, mas perde sincronização e login real).


O backend está em `backend/` e usa:

- **Express** (API HTTP)
- **Prisma** (ORM)
- **PostgreSQL** (via `DATABASE_URL`)
- **jsonwebtoken** (JWT)
- **bcrypt** (hash de senha)
- **dotenv** (variáveis de ambiente)
- **cors** (permitir chamadas)

### Entry point

Em `backend/src/server.ts`:

- cria app express
- habilita `cors` e `express.json()`
- carrega `routes`
- sobe na porta `PORT` (ou 3000)

### Rotas e autenticação

Em `backend/src/routes.ts`:

- `POST /register` e `POST /login` são públicas
- Rotas protegidas usam `authMiddleware`:
  - lê `Authorization: Bearer <token>`
  - valida com `JWT_SECRET`
  - injeta `userId` em `req` (via `AuthRequest`)

### Auth (cadastro/login)

Em `backend/src/auth.ts`:

- `register`:
  - valida campos
  - cria hash com bcrypt
  - cria usuário no banco
  - cria `notificationSettings` padrão
- `login`:
  - valida senha
  - gera JWT com `expiresIn: "7d"`
  - retorna `{ token, user }`

**Jeito pleno**:

- Nunca retornar hash de senha.
- Padronizar mensagens/formatos de erro.
- Considerar rate-limit e lockout para brute force (não está implementado hoje).

### Prisma e modelos

Em `backend/prisma/schema.prisma`:

- `User`
  - campos: `dailyGoal`, `quickAddAmount`, `theme`, `dailyReminder`, `vibration`
  - relação com `WaterLog[]`
  - relação opcional com `NotificationSetting`
- `NotificationSetting`
  - `daysOfWeek: Int[]`
  - janela `startTime/endTime`
  - `intervalInMinutes`, `enabled`
- `WaterLog`
  - `amount`, `date`, `userId`
  - index por `(userId, date)`

### Settings (GET/PUT + trocar senha)

Em `backend/src/settings.ts`:

- `GET /settings` retorna:
  - dados do usuário + `notificationSettings` (ou default)
- `PUT /settings` atualiza:
  - campos simples do usuário
  - e faz `upsert` de `notificationSettings` quando `notifications` vier no body
- `PUT /settings/password` troca a senha validando a atual

### Água (logs, hoje, histórico)

Em `backend/src/water.ts`:

Ponto importante: o backend usa o header `x-timezone-offset` para calcular “início e fim do dia do usuário” em UTC, e assim `GET /water/today` funciona corretamente para qualquer fuso.

Rotas:

- `POST /water` cria um `WaterLog`
- `GET /water/today` soma os logs do dia do usuário e devolve:
  - `total`, `dailyGoal`, `remaining`, `percent`, `logs`, `name`
- `GET /water/history` devolve logs e estatísticas
- `DELETE /water/:id` apaga log (com checagem de dono)

### Como usar o backend na prática

- **Quando criar um endpoint novo**:
  - Defina o modelo em `schema.prisma` se precisar de nova tabela/campo.
  - Implemente a função em `backend/src/...` usando `prisma` para ler/gravar.
  - Adicione a rota em `routes.ts` e, se for privada, inclua `authMiddleware`.
- **Como o app consome**:
  - Crie (ou ajuste) um Service em `lib/data/services/...` chamando essa rota com o `ApiClient`.
  - Use esse Service dentro de um Cubit.
  - A tela conversa só com o Cubit, nunca diretamente com o backend.

---

## Como um “pleno” adicionaria uma feature nova (checklist)

Exemplo: “Adicionar um novo campo de configuração do usuário”.

- **Backend**
  - Atualizar `schema.prisma` e rodar migração (se aplicável)
  - Atualizar `GET /settings` para retornar o campo
  - Atualizar `PUT /settings` para aceitar o campo e validar
- **App**
  - Atualizar `SettingsState` e `SettingsCubit.loadSettings()`
  - Atualizar `SettingsCubit.updateSetting(...)` para enviar o payload certo
  - Atualizar a tela em `presentation/...` para exibir e chamar o Cubit
- **Contratos**
  - Garantir nome do campo e tipo (string/number/bool) iguais
  - Se houver conversão (como `daysOfWeek`), documentar e testar

**Regra de ouro**: mexa em uma camada por vez, e sempre confira o “contrato” JSON entre app e backend.

---

## Debug e manutenção (atalhos mentais)

- **Erro 401 “Token inválido”**
  - Verificar se `AuthService.isLoggedIn()` está aplicando token no `ApiClient`
  - Conferir se `JWT_SECRET` do backend está setado corretamente
- **Dia “errado” no today/history**
  - Conferir header `x-timezone-offset` (vem do `ApiClient`)
  - Conferir funções `getStartOfUserDayInUTC` no backend
- **Notificação não dispara**
  - Android: permissão de notificações + permissão de alarmes exatos
  - Verificar se `NotificationCubit` está chamando `scheduleHydrationReminders`
  - Em debug, `NotificationService` tem logs de agendamento

---

## Glossário (pra fixar)

- **Cubit**: classe que controla estado (emitindo estados) sem eventos explícitos.
- **State**: objeto que representa “como a UI deve estar agora”.
- **Service**: classe que fala com API/infra (HTTP/storage) e retorna dados.
- **JWT**: token assinado que prova quem é o usuário.
- **Bearer token**: formato do header `Authorization`.
- **Prisma**: ORM que mapeia modelos e gera queries pra PostgreSQL.
- **Upsert**: “cria se não existe, atualiza se existe”.

