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

- `**presentation/`**: telas, widgets e estado de UI (Cubits/States)
- `**data/**`: serviços que conversam com API e modelos que representam dados do backend
- `**core/**`: coisas reutilizáveis e “globais” (tema, notificações locais, API client, utilidades)

Pensa assim:

- **Presentation** decide *o que mostrar* e *quando chamar ações*
- **Data/Services** decide *como buscar/salvar dados*
- **Core** fornece infraestrutura (HTTP client, notificações, tema, widget do sistema etc.)

Se você estiver perdido, comece pelo `lib/main.dart`.

---

### Entry point e “injeção” de dependências

O app inicia em `lib/main.dart`:

- Inicializa bindings do Flutter
- Carrega **tema local imediatamente** com `AppTheme.initialize()` (SharedPreferences) para o app **não depender da API** para claro/escuro/sistema na abertura; a API continua sincronizando depois no `SettingsCubit`
- Registra o callback de interatividade do **HomeWidget**: `HomeWidget.registerInteractivityCallback(homeWidgetInteractiveCallback)` (Android dispara isso em background quando o usuário toca no `+` do widget)
- Inicializa **NotificationService** (notificações locais + timezone); **no foreground** isso pode pedir permissões de notificação e alarmes exatos no Android
- Cria instâncias “singleton-like” do app:
  - `ApiClient`
  - `AuthService`
  - `WaterService`
  - `SettingsService`
- Configura **quick add nas notificações** com `notificationService.configureQuickAddAction(...)`: resolve quantidade via `SettingsService.getSettings()` (`quickAddAmount`) e, após `addWater`, mostra a **mesma notificação de progresso** usada em outros fluxos (`showProgressNotification`, id `995`)
- Checa se existe token local: `authService.isLoggedIn()`
- Se houver login e não for web, chama **`_syncWidgetWithLatestData(...)`**: busca meta em `/settings` e consumo em `/water/today` e grava no widget — evita ficar “0 / 2000” até o usuário abrir a Home
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

- `**push`** coloca uma tela **em cima** da outra. O usuário pode voltar e ver a tela anterior. Bom para “fluxos” (Login → Register, Home → Detalhe).
- `**go`** troca a rota atual. É como “teleportar” para um destino. Bom quando a tela anterior não faz mais sentido voltar (ex.: depois do login, não faz sentido voltar pra tela de login).

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

- `**flutter_bloc`** e `**bloc**`
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

### Quando usar Cubit (e quando NÃO usar)

Use **Cubit** quando:

- **Existe um fluxo assíncrono**: chamar API, salvar algo, carregar dados do backend (ex.: `HomeCubit.loadTodayData()`, `HistoryCubit.loadHistory()`).
- **Você precisa de estados claros**: loading/erro/sucesso e a UI precisa mudar com base nisso (ex.: `LoginLoading` → `LoginSuccess`).
- **A mesma informação é usada em mais de um widget** na mesma tela (ou em várias telas) e você quer **uma fonte de verdade**.
- **Você precisa de regras de tela** (ex.: clamp de valores, update otimista, validação leve de UI) que não deveriam ficar no widget.

NÃO crie Cubit quando:

- É **estado puramente local e temporário** do widget (ex.: abrir/fechar um modal, trocar uma tab interna, animar um botão). Isso pode ficar em `StatefulWidget` com `setState`.
- É **infra** (ex.: HTTP, storage, notificação). Isso é papel de `Service`/`core`, não de Cubit.

Regra mental (bem prática):

- Se o estado morre quando você sai da tela e não precisa ser testado → pode ser `setState`.
- Se o estado representa “dados do app/usuário” ou envolve I/O (API/storage) → Cubit.

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
  - Sucesso considera resposta **200 ou 201** (APIs REST costumam usar `201 Created` em criação; tratar só `200` fazia o app achar que falhou)
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

- `**flutter_secure_storage`**: para **JWT** (`jwt_token`)
- `**shared_preferences`**: geralmente usado para preferências simples (no código atual, a maior parte de settings vem do backend; o shared_preferences aparece como dependência e pode ser usado para cache/local config)

### O que é JWT (explicação simples)

JWT é um token assinado pelo servidor. Ele funciona como um “crachá”: quando o app envia esse token, o backend consegue validar e descobrir **qual usuário** está fazendo a requisição.

Aqui o backend:

- gera o token no `POST /login`
- valida o token em `authMiddleware` nas rotas protegidas

### Por que salvar token no SecureStorage

Porque token é segredo. `FlutterSecureStorage` usa mecanismos do sistema (Keychain no iOS, storage criptografado no Android) e é mais seguro que `SharedPreferences`.

### Quando usar SecureStorage (e quando usar SharedPreferences)

Use **SecureStorage** quando o dado:

- **dá acesso à conta** se alguém pegar (ex.: **JWT**, refresh token, session token)
- é **segredo** (ex.: chaves/credenciais, qualquer coisa que você não quer que apareça em backup/prints/logs)

Use **SharedPreferences** quando o dado:

- é **preferência/estado de conveniência**, e vazar não “quebra a conta” (ex.: “já viu onboarding”, última aba selecionada, flags de UI)
- pode ser facilmente refeito pelo app (cache simples)

Exemplo do seu projeto:

- **JWT** vai no SecureStorage (`AuthService` usa a chave `jwt_token`).
- **Tema (light/dark/system)** também usa SharedPreferences, via `AppTheme` (`theme_mode`), para hidratar o `ThemeMode` antes da primeira resposta de `/settings`.
- Outras preferências “leves” podem ir em SharedPreferences; boa parte de configuração ainda vem do backend.

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
- **`initialize({bool requestPermissions = true})`**: por padrão pede permissões (Android 13+ e alarmes exatos). Em **callbacks de background** (ex.: `home_widget` worker) use **`requestPermissions: false`**: o plugin tentaria `checkSelfPermission` sem `Activity` e gerava `NullPointerException`; permissões ficam para quando o app está em primeiro plano
- Agenda lembretes com `zonedSchedule(...)`
- Mantém uma fila `_scheduleChain` para evitar agendamentos concorrentes
- Implementa lógica para:
  - Agendar por “todo dia” (hora fixa) se os dias ativos forem todos
  - Agendar por “dias da semana + hora” se for seleção parcial
  - Respeitar limite prático de alarmes no Android (usa `maxAlarms = 420`)
- **IDs de notificação separados por função** (evita uma notificação “apagar” outra):
  - Lembretes agendados usam faixa base (ex.: `_scheduledReminderIdBase + ...`)
  - Progresso de meta / “bom progresso” usa id fixo dedicado; meta atingida outro id
- **Reagendar lembretes sem apagar tudo**: ao reagendar, **não** usar `cancelAll()` no Android — isso removia também notificações imediatas (progresso, quick add). O código cancela só pendentes com payload de lembrete recorrente (`hydration_recurring`)
- **Progresso ao abrir o app**: `HomeCubit` **não** chama `checkProgressAndNotify` no carregamento inicial/refresh (`notifyProgress: false`), só quando há ação real de consumo (ex.: `addWater` otimista), para não disparar “Bom progresso” toda vez que entra no app

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
- **Conflito de ID / `cancelAll`**: duas notificações com o mesmo id somem ou se sobrescrevem; cancelar “tudo” ao reagendar apagava progresso — por isso o cancelamento ficou seletivo.
- **Inicializar notificações no worker do widget sem `requestPermissions: false`**: quebra o callback e o usuário vê erro genérico ao tocar no `+` do widget.

---

## Stack: Tema e UI

### Tema (light/dark/system)

O tema vive em `lib/core/theme/app_theme.dart` e é aplicado assim:

- **Persistência local**: chave SharedPreferences `theme_mode` (valores `light`, `dark`, `system`). `AppTheme.initialize()` roda no início do `main` e preenche `AppTheme.themeMode` **antes** do primeiro frame — a UI não “espera” `/settings` para ficar no tema certo
- **`AppTheme.setThemeFromString(theme, persist: true)`**: usado pelo `SettingsCubit` ao carregar API e ao usuário trocar tema; com `persist: true` grava no disco para a próxima abertura
- **`SettingsState` inicial** usa `AppTheme.currentThemeString` para alinhar estado do Cubit com o que já está no `ValueNotifier`
- `MyApp` usa `ValueListenableBuilder<ThemeMode>` ligado a `AppTheme.themeMode`

### Widgets e telas

Ficam em `lib/presentation/...`.

Exemplo: `NotificationSettingsView` e `AlertsView` usam `BlocBuilder<NotificationCubit, NotificationState>` e fazem “update otimista” (atualiza UI antes de confirmar o backend). **Não** há mais botão “Testar agora” nessas telas (evita disparos de teste em produção).

**Jeito pleno**:

- Widgets devem ser “burros”: renderizar o estado e disparar ações.
- O Cubit faz o trabalho e decide o próximo estado.

---

## Stack: Home Widget (`home_widget`)

O projeto usa `home_widget` para atualizar/escutar interações do widget na **tela inicial** do Android (layouts nativos em `android/app/src/main/res/layout/`).

### Fluxo de dados (Flutter → widget)

- `WidgetService.updateHomeWidget(...)` grava `currentIntake`, `goal`, `progressPercent` via `HomeWidget.saveWidgetData` e chama `HomeWidget.updateWidget` nos providers grande/pequeno
- No **boot** do app, se o usuário estiver logado, `main.dart` chama `_syncWidgetWithLatestData` para não mostrar valores padrão “zerados” até abrir a Home

### Fluxo do botão `+` (widget → Flutter em background)

- Em Kotlin (`HomeWidgetLargeProvider` / `HomeWidgetSmallProvider`), o toque usa `HomeWidgetBackgroundIntent` com URI `homeWidget://addwater` (host `addwater`)
- O pacote chama o entry-point Dart `homeWidgetInteractiveCallback` em `lib/core/home_widget_interactive.dart`
- **Boas práticas nesse arquivo**:
  - `WidgetsFlutterBinding.ensureInitialized()` e `DartPluginRegistrant.ensureInitialized()` (plugins como secure storage funcionam no isolate de background)
  - Aceitar tanto `host == addwater` quanto path `/addwater` (variação de URI)
  - Ler JWT do mesmo storage que o app (`jwt_token`); criar `ApiClient`, `setToken`, chamar `WaterService` / `SettingsService`
  - `NotificationService().initialize(requestPermissions: false)` antes de mostrar notificação (nunca pedir permissão nesse contexto)
  - Após `addWater`, preferir **`showProgressNotification`** igual ao quick add da notificação (título `+Xml registrado ✅`, texto de status e barra de meta); se `getTodayData` falhar depois do POST, ainda dá para mostrar fallback simples — o importante é **não** tratar falha de sync como “não adicionou água” se o POST já tiver ido
- **UI nativa**: no widget grande, o botão rápido mostra texto do tipo `+ 50 ml` **sem** ícone `+` duplicado; fundo do card usa branco semi-transparente (`widget_card_bg.xml`) para leitura boa no wallpaper

### Guia técnico (bem “junior”) passo a passo: botão `+` do widget

Use este passo a passo quando alguém disser:

- “O `+` do widget não adiciona”
- “A notificação aparece, mas vem 0 ml / 0%”
- “O `+` funciona às vezes, às vezes não”

#### Pré-check (antes de mexer no código)

1. Você está no **Android** (o widget é Android nativo).
2. O usuário está **logado** no app (deve existir `jwt_token` no `FlutterSecureStorage`).
3. O celular tem **internet** (se não tiver, o POST/GET vai falhar).
4. O `+` do widget está sendo pressionado de verdade (teste apertando 2-3x).

#### Onde está o fluxo (mapa rápido)

- XML nativo: `android/app/src/main/res/layout/home_widget_*.xml` (o botão chama um `PendingIntent`)
- Kotlin providers: `HomeWidgetLargeProvider.kt` / `HomeWidgetSmallProvider.kt` (geram o broadcast `homeWidget://addwater`)
- Callback Dart: `lib/core/home_widget_interactive.dart` (faz addWater + notificação + update do widget)
- APIs:
  - `WaterService.addWater(...)` → `POST /water`
  - `water.getTodayData()` → `GET /water/today`

#### Passo a passo durante o bug (o “como diagnosticar”)

1. Aperte o `+` e procure logs com o prefixo **exato** `[Widget +]`
   - Se **não aparecer nenhum log**, o callback Dart nem está sendo chamado.
   - Nesse caso, vá para “Caso A” (abaixo).

2. Confirme a URI chegou como esperado
   - No log deve aparecer algo como:
     - `uri=homewidget://addwater`
     - `host=addwater`
     - `path` (pode vir vazio ou `'/addwater'`, o callback aceita ambos)
   - Se o host/path estiverem diferentes do esperado, o callback retorna sem chamar API.
   - Nesse caso, vá para “Caso B”.

3. Valide autenticação (JWT)
   - Procure logs como:
     - `Token ausente no secure storage`
   - Se aparecer, o widget não consegue falar com o backend.
   - Vá para “Caso C”.

4. Verifique se não está quebrando em permissões de notificação (background)
   - Se aparecer `NullPointerException` em `checkPermission` / `requestNotificationsPermission`:
     - isso acontece quando `NotificationService.initialize()` tenta pedir permissão **no background**
   - Solução esperada no callback:
     - `NotificationService().initialize(requestPermissions: false)`
   - Vá para “Caso D”.

5. Verifique quantidade do “quick add”
   - O callback tenta carregar `quickAddAmount` via `SettingsService.getSettings()`.
   - Se falhar, ele usa fallback local:
     - `200ml` (quick add) e `2000ml` (goal)
   - Não travar aqui é normal; o log vai dizer “Falha ao carregar settings, usando fallback”.

6. Confira o POST (adicionar água)
   - Procure log:
     - `Enviando addWater(amount=...)`
     - `addWater concluido com sucesso`
   - Se der falha, o problema é rede/Auth/backend.
   - Garanta que `WaterService.addWater` aceita `statusCode == 200 || statusCode == 201`.

7. Garanta que a notificação usa o mesmo padrão do botão `+`
   - Após o POST, o callback faz:
     - `water.getTodayData()` → total/goal
     - calcula `percent`
     - chama `notify.showProgressNotification(...)`
     - id unificado de progresso: `995`
   - Se a notificação aparece mas está “zerada”, normalmente é porque `getTodayData()` retornou total/goal = 0 (vá para “Caso E”).

8. Atualize o widget visual
   - Em seguida roda:
     - `WidgetService.updateHomeWidget(progress, currentIntake, goal)`
   - Se o POST funcionou, mas o widget não atualiza, isso geralmente é falha nessa etapa (rede ou falha do update do remoto).
   - Vá para “Caso F”.

#### Fluxos de erro comuns (Casos)

Caso A: “não aparece log nenhum”
- Motivo provável: o XML/Kotlin não está gerando o broadcast `homeWidget://addwater`.
- Onde olhar: `HomeWidgetLargeProvider.kt` / `HomeWidgetSmallProvider.kt` e os ids do layout `home_widget_*.xml`.

Caso B: “host/path não bate”
- Motivo provável: URI não está chegando no formato esperado.
- Onde olhar: `home_widget_interactive.dart` (condição de host/path).

Caso C: “Token ausente”
- Motivo provável: não está logado no app ou secure storage não foi preenchido.
- Onde olhar: `AuthService` e a chave `jwt_token`.

Caso D: “NullPointerException em requestNotificationsPermission”
- Motivo provável: pedir permissão no background.
- Onde olhar: `NotificationService.initialize(requestPermissions: false)` no callback do widget.

Caso E: “notificação sai 0 ml / 0%”
- Motivo provável: `GET /water/today` retornou total/goal como 0 (ou falhou e caiu em fallback).
- Onde olhar: `WaterService.getTodayData()` e o debug do callback (logs de `getTodayData ok`).

Caso F: “POST adiciona, mas widget não muda”
- Motivo provável: falha no `WidgetService.updateHomeWidget` (ou timeout/rede).
- Onde olhar: `WidgetService.updateHomeWidget` e logs do callback.

### Limitações que vale internalizar

- Widget na **lock screen** como app widget “cheio” não é o mesmo modelo da launcher; lembrete com ação na notificação costuma ser o caminho para atalho similar
- Se não houver rede/DNS, qualquer fluxo que chame a API falha — o log costuma mostrar `Failed host lookup` ou `connection error`

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

## Quando usar cada stack (guia de decisão rápido)

Use esta seção como cola no dia a dia: “tenho problema X, qual stack eu uso?”.

### Flutter (UI base)

Use quando:

- você vai construir tela, componente visual, layout, animação, tema
- precisa renderizar estado e responder interação (toque, input, scroll)

Não use para:

- regra de negócio pesada e chamada HTTP direta (isso vai para Cubit/Service)

### `go_router` (navegação)

Use quando:

- precisa trocar de tela por rota (`/login`, `/home`)
- quer centralizar rotas e manter navegação previsível
- precisa controlar fluxo de autenticação entre telas

### Cubit/Bloc (estado e fluxo da tela)

Use quando:

- existe loading/sucesso/erro
- a tela depende de API/storage/notificações
- você precisa de regra de tela testável e organizada

Não use quando:

- é só estado visual local e curto (ex.: expandir card, alternar aba local)

### `dio` + `ApiClient` (HTTP)

Use quando:

- app precisa falar com backend REST
- precisa de headers globais (`Authorization`, timezone), timeout, interceptor e logs

Não use:

- `Dio()` solto em widget/cubit

### Services (`AuthService`, `WaterService`, `SettingsService`)

Use quando:

- precisa encapsular contrato com API (endpoint + payload + parse + erro)
- quer reutilizar a mesma integração em mais de um Cubit/tela

### Models (`fromJson`/`toJson`)

Use quando:

- backend retorna estrutura que precisa virar tipo forte no app
- você quer evitar `Map` espalhado e erro em runtime

Exemplo clássico do projeto:

- `NotificationPreferences` faz conversão de `daysOfWeek` backend <-> Flutter

### `flutter_secure_storage`

Use quando:

- dado é sensível e dá acesso à conta (JWT, refresh token, segredo)

### `shared_preferences`

Use quando:

- dado é preferência local não sensível (flags de UI, onboarding, cache simples)

### `flutter_local_notifications` + `timezone`

Use quando:

- lembrete é local no dispositivo (não depende de push server)
- horário precisa respeitar fuso do usuário

### Theme (`AppTheme` + `ThemeMode`)

Use quando:

- precisa alternar claro/escuro/sistema globalmente
- quer consistência visual em todo app

### `home_widget`

Use quando:

- quer mostrar resumo do app na tela inicial do sistema
- quer interação rápida sem abrir fluxo completo

### Node.js + Express (backend API)

Use quando:

- precisa endpoint HTTP para cadastro/login/dados do usuário
- quer centralizar regra de negócio que deve ser confiável no servidor

### Prisma

Use quando:

- precisa mapear banco em modelos e consultar dados de forma segura/organizada
- quer `upsert`, relações e tipagem melhor que SQL bruto espalhado

### PostgreSQL

Use quando:

- dados precisam persistir com segurança e consistência
- app precisa histórico por usuário, consultas e relações

### JWT (`jsonwebtoken`)

Use quando:

- autenticação é stateless via token
- backend precisa identificar usuário a cada requisição protegida

### `bcrypt`

Use quando:

- for salvar senha de usuário (sempre hash, nunca texto puro)

### `dotenv`

Use quando:

- backend precisa ler segredo/config por ambiente (`DATABASE_URL`, `JWT_SECRET`)

### `cors`

Use quando:

- seu backend recebe requisição de origens diferentes (web, mobile, ambiente local)

### TypeScript no backend

Use quando:

- quer reduzir bug por tipagem e melhorar manutenção/refatoração

### Railway (deploy atual da API)

Use quando:

- precisa publicar backend com URL pública consumida pelo app
- quer ambiente simples para deploy contínuo de API

### Regra de decisão (1 linha)

Se o problema for:

- **tela/visual** -> Flutter
- **troca de página** -> go_router
- **estado e fluxo da tela** -> Cubit
- **HTTP** -> Dio/ApiClient
- **integração de endpoint** -> Service
- **estrutura de dados** -> Model
- **segredo** -> SecureStorage
- **preferência simples** -> SharedPreferences
- **lembrete local com horário** -> Notifications + timezone
- **persistência e regras confiáveis** -> Backend (Express + Prisma + Postgres)

---

## Roteiro Junior: explicar (e replicar) as stacks com clareza

Essa seção existe pra você conseguir pegar qualquer iniciante e fazer uma explicação completa sem “pular” o essencial.
A ordem mental é sempre a mesma:

`Entrada (main.dart)` → `Navegação (go_router)` → `Estado (Cubit/State)` → `API (Service + ApiClient)` → `Auth/Storage` → `Notificações + Widget` → `Backend`.

### 0) Script de 30 segundos (pra começar bem)

Quando alguém perguntar “como esse app funciona?”, responda:

1. “O app sobe em `lib/main.dart`, registra rotas no `GoRouter` e monta os providers (Cubits).”
2. “As telas desenham o estado e chamam ações; quem conversa com API são os `Services`.”
3. “Os `Services` usam `dio` via `ApiClient`, com JWT no header `Authorization: Bearer ...`.”
4. “Notificações e widget ficam em `core/` (ex.: `NotificationService` e `home_widget`).”
5. “O backend é o dono do contrato: Express + Prisma (ex.: endpoints `GET /water/today` e `GET /settings`).”

### 1) Cada stack com 1 frase + 1 exemplo de arquivo (o mínimo completo)

#### Flutter (UI base)
- **Onde**: `lib/presentation/`
- **Exemplo**: `lib/presentation/home/widgets/alerts_view.dart` renderiza a UI a partir de `NotificationCubit`.
- **Nunca faça**: chamar `dio` direto na tela.

#### Navegação: `go_router`
- **Onde**: `lib/main.dart`
- **Exemplo**: rota `/login` cria `LoginCubit(authService)` e mostra `LoginPage`.
- **Nunca faça**: misturar `Navigator.push` em todo lugar sem critério.

#### Estado: `flutter_bloc` / `Cubit`
- **Onde**: `lib/presentation/**/cubit/`
- **Exemplo**: `HomeCubit.loadTodayData()` chama `WaterService.getTodayData()`.
- **Nunca faça**: lógica de regra de negócio no `build`.

#### HTTP: `dio` + `ApiClient`
- **Onde**:
  - `lib/core/api/api_client.dart`
  - `lib/data/services/*_service.dart`
- **Exemplo**: `WaterService.addWater()` faz `POST /water`.
- **Nunca faça**: criar `Dio()` “solto” sem usar o `ApiClient`.

#### Auth + Persistência: `flutter_secure_storage` (JWT) e `shared_preferences` (preferências)
- **Onde**: `lib/data/services/auth_service.dart` e `lib/core/theme/app_theme.dart`
- **Exemplo**:
  - `AuthService` salva `jwt_token` no secure storage.
  - `AppTheme.initialize()` lê `theme_mode` do `SharedPreferences`.
- **Nunca faça**: guardar JWT em `SharedPreferences`.

#### Notificações: `flutter_local_notifications` + `timezone`
- **Onde**: `lib/core/services/notification_service.dart`
- **Exemplo**:
  - `scheduleHydrationReminders(...)` usa `zonedSchedule(...)`.
  - `checkProgressAndNotify(...)` mostra “Bom progresso” por id fixo.
- **Nunca faça**: pedir permissão de notificação em background sem `Activity` (use `requestPermissions: false` no worker do widget).

#### Tema: `AppTheme`
- **Onde**: `lib/core/theme/app_theme.dart`, usado por `SettingsCubit`
- **Exemplo**:
  - `SettingsCubit.loadSettings()` aplica tema vindo de `/settings` e persiste.

#### Widget do sistema: `home_widget`
- **Onde**:
  - Kotlin: `android/app/src/main/kotlin/...HomeWidget*Provider.kt`
  - Dart callback: `lib/core/home_widget_interactive.dart`
  - Update: `lib/core/services/widget_service.dart`
- **Exemplo**:
  - Kotlin dispara URI `homeWidget://addwater`
  - Dart callback faz `WaterService.addWater(...)`, depois chama `showProgressNotification(...)` e atualiza o widget.

### 2) Guia final: como “clonar” essas stacks em outros projetos (sem misturar camadas)

Use essa checklist como modelo:

1. **Backend define contrato**:
   - endpoints (paths) + JSON request/response
   - autenticação (JWT) e middleware (ex.: `authMiddleware`)
2. **App cria Navigation**:
   - rotas `/login`, `/home`, etc. no `GoRouter`
3. **App cria State por tela**:
   - para cada tela que chama API, cria um Cubit com `Loading/Loaded/Error`
4. **App cria Service por domínio**:
   - `AuthService`, `WaterService`, `SettingsService` (ou seus equivalentes)
5. **App cria Model para os dados mais importantes**:
   - evita `Map` espalhado no resto da UI
6. **App centraliza HTTP**:
   - usa `ApiClient` para `baseUrl`, `timeout`, header `Authorization`
7. **Auth e storage**:
   - JWT vai em `FlutterSecureStorage`
   - preferências leves/tema em `SharedPreferences` via `AppTheme`
8. **Sistema operacional (se precisar)**:
   - notificações: `NotificationService`
   - widget: `home_widget` (Kotlin + callback Dart)

Se seguir essa ordem, você terá as mesmas stacks do projeto e não vai cair na armadilha clássica de “UI chamando API” ou “estado misturado com layout”.

## Resumo dos ajustes recentes (para você não “perder o fio”)

Esta seção documenta mudanças importantes que já estão no código — útil em code review, onboarding e quando algo “parecia bug” mas era detalhe de plataforma.

| Área | O que era o problema / objetivo | O que foi feito (onde olhar) |
|------|--------------------------------|------------------------------|
| **Tema** | Abrir o app e ficar em `system` ou piscar até `/settings` responder | `AppTheme.initialize()` no `main` + persistência `theme_mode` em SharedPreferences; `SettingsCubit` persiste ao mudar tema |
| **Notificações de progresso** | “Bom progresso” ao entrar no app; notificação sumindo ao reagendar alertas | `HomeCubit` só chama `checkProgressAndNotify` quando faz sentido (`notifyProgress`); reagendamento cancela só lembretes com payload `hydration_recurring`; IDs separados para lembrete vs progresso vs meta |
| **Permissões em background** | Toque no `+` do widget gerava erro do plugin de notificações (contexto nulo) | `initialize(requestPermissions: false)` no callback do widget |
| **POST água** | Backend retornava `201` e o app achava falha | `WaterService.addWater` aceita `200` e `201` |
| **Widget zerado** | `main` gravava 0/2000 antes de ter dados | `_syncWidgetWithLatestData` após `isLoggedIn` |
| **Quick add unificado** | Notificação do widget diferente da da ação `+` do lembrete | `configureQuickAddAction` no `main` + `showProgressNotification` no `home_widget_interactive` |
| **Produto** | Botão “Testar agora” em alertas | Removido de `notification_settings_view` e `alerts_view` |
| **Layout widget** | Dois `+` e espaço enorme antes do botão | `home_widget_large.xml` + fundo mais translúcido em `widget_card_bg.xml` |

**Debug rápido do widget**: prefixo de log `[Widget +]` em `home_widget_interactive.dart`. Se aparecer `Failed host lookup` no Dio, é rede/DNS — não é bug do botão em si.

---

## Plano para dominar o projeto `bebeu`

Objetivo: em **4–6 semanas** (ajuste o ritmo) você conseguir **navegar sozinho** de splash → cubits → services → backend e **alterar features sem medo**. Cada fase tem entregável verificável.

### Fase 1 — Mapa mental e fluxo feliz (3–5 dias)

- Ler este `STACKS.md` inteiro uma vez e voltar só às seções “HTTP”, “JWT”, “Notificações” e “Home widget” quando precisar.
- Rodar o app em debug, logar, ir à Home, adicionar água, abrir histórico e alertas.
- Rastrear no código, na ordem: `main.dart` → `SplashPage` / `HomePage` → `HomeCubit` → `WaterService` → rota `GET /water/today` no backend.
- **Entregável**: desenhar num papel (ou Notion) um fluxo “login → token no Dio → today” com 5 caixas e setas.

### Fase 2 — Contrato app ↔ API (1 semana)

- Abrir `lib/data/services/*.dart` e `backend/src/*.ts` **lado a lado** para `auth`, `water`, `settings`.
- Anotar: método HTTP, path, campos JSON de request/response, quem exige `authMiddleware`.
- Testar com app + logs Dio (debug) ou Postman na API pública (se tiver credenciais de teste).
- **Entregável**: mini tabela sua (3 endpoints que mudam com mais frequência) com payload esperado.

### Fase 3 — Estado e UI (1 semana)

- Para cada Cubit principal, listar estados possíveis (`HomeLoading`, `HomeLoaded`, …) e **quem emite** cada um.
- Entender update otimista em `SettingsCubit` / `NotificationCubit` e por que exists rollback em `catch`.
- **Entregável**: uma alteração pequena guiada (ex.: texto de empty state ou label) sem mexer em regra de negócio, só lendo estado.

### Fase 4 — Notificações e tempo (1 semana)

- Ler `notification_service.dart` com calma: canais, `zonedSchedule`, payload dos lembretes, `checkProgressAndNotify`.
- No celular: conceder notificações + alarmes exatos; mudar intervalo em Alertas e confirmar reagendamento.
- **Entregável**: explicar em uma frase por que `initialize(requestPermissions: false)` existe no widget.

### Fase 5 — Home widget e Android nativo (3–5 dias)

- Ler os `.kt` dos providers e os `.xml` de layout; relacionar ids (`widget_add_area`) com `setOnClickPendingIntent`.
- Quebrar de propósito só em **dev** (ex.:URL offline) e ler o log `[Widget +]` para associar sintoma ↔ causa.
- **Entregável**: alterar só cópia ou cor em XML e ver no launcher após rebuild.

### Fase 6 — Backend confiante (1–2 semanas, intercalado)

- Rodar backend local (se tiver `.env`); entender `authMiddleware`, Prisma, modelos de `WaterLog` e `User`.
- Fazer uma mudança segura: campo read-only extra em `GET /settings` ou log de debug no servidor.
- **Entregável**: um PR pequeno “só backend” ou “só app” — evita PR gigante.

### Hábitos que aceleram

- **Sempre** achar o “donos:” arquivo antes de editar (`grep` / busca por símbolo).
- **Nunca** misturar tema, widget background e agendamento na mesma alteração sem testar cada um.
- Preferir **uma camada por commit** quando estiver aprendendo (facilita `git bisect` e revisão).

### Como saber que você “dominou”

- Consegue implementar **sozinho**: “novo campo em settings” seguindo o checklist deste doc.
- Quando algo quebra, você classifica em **< 2 min** em: rede, auth, fuso, permissão Android, ou bug de estado Flutter.

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

