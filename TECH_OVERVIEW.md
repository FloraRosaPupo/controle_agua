# Bebeu — Documentação Técnica Nível Pleno

> Cobre cada decisão de design, cada detalhe de implementação, cada gotcha e cada ponto não óbvio do projeto. Leia do início ao fim antes de tocar em qualquer arquivo.

---

## 1. Visão Geral do Repositório

O repo tem **dois projetos independentes** que se comunicam via HTTP:

```
bebeu/
├── lib/              → App Flutter (Dart 3, SDK ^3.10.8)
├── backend/          → API REST (Node.js + TypeScript)
│   └── src/          → Código-fonte TypeScript
│   └── prisma/       → Schema e migrations do banco
├── android/          → Configurações Android (manifest, widgets nativos)
├── ios/              → Configurações iOS
└── assets/           → Imagens e animações Lottie
```

O app Flutter consome a API hospedada no Railway. **Não há monorepo tooling** — os dois projetos são completamente independentes; o backend é buildado e deployado separado.

---

## 2. Stack Completa

### Flutter / Dart

| Pacote | Versão | Papel |
|---|---|---|
| `flutter_bloc` | ^9.1.1 | Gerenciamento de estado — padrão Cubit |
| `bloc` | ^9.2.0 | Base do flutter_bloc |
| `go_router` | ^17.1.0 | Navegação declarativa com deep links |
| `provider` | ^6.1.5 | Usado apenas para `RepositoryProvider` do `AuthService` |
| `dio` | ^5.9.2 | Cliente HTTP com interceptors |
| `flutter_secure_storage` | ^9.2.4 | Armazena JWT com criptografia nativa do OS |
| `sqflite` | ^2.4.2 | SQLite local para cache offline |
| `shared_preferences` | ^2.5.4 | Preferências simples (tema) |
| `connectivity_plus` | ^6.1.4 | Detecta mudanças de rede em tempo real |
| `flutter_local_notifications` | ^21.0.0 | Notificações locais + agendamento |
| `timezone` | ^0.11.0 | Manipulação de fuso horário para notificações |
| `home_widget` | ^0.9.0 | Widget nativo Android/iOS da tela inicial |
| `lottie` + `dotlottie_loader` | — | Animações .lottie na splash e loading |
| `intl` | ^0.20.2 | Formatação de datas |
| `path_provider` | ^2.1.5 | Caminhos de diretório para o SQLite |

### Backend (Node.js)

| Tecnologia | Papel |
|---|---|
| TypeScript | Linguagem com tipagem estática |
| Express | Framework HTTP minimalista |
| Prisma | ORM type-safe sobre PostgreSQL |
| PostgreSQL | Banco relacional (hospedado no Railway) |
| bcrypt | Hash de senha (custo 10 rounds) |
| jsonwebtoken | JWT com expiry de 7 dias |
| dotenv | Variáveis de ambiente |
| Railway | Plataforma de deploy (PaaS) + PostgreSQL |

---

## 3. Arquitetura Flutter — Camadas em Detalhe

### 3.1 A regra das camadas

```
┌──────────────────────────────────────────────────────────┐
│ PRESENTATION (lib/presentation/)                         │
│  Pages + Widgets visuais + Cubits + States               │
│  → Sabe APENAS: "o que mostrar" e "quando chamar ação"   │
│  → NUNCA faz chamada HTTP direta                         │
│  → NUNCA acessa SQLite diretamente (apenas HomeCubit)    │
├──────────────────────────────────────────────────────────┤
│ DATA (lib/data/)                                         │
│  Services + Models                                       │
│  → Sabe: "como buscar/salvar dados externos"             │
│  → Cada service tem uma responsabilidade única           │
│  → Models têm fromJson/toJson e NADA de lógica de UI     │
├──────────────────────────────────────────────────────────┤
│ CORE (lib/core/)                                         │
│  ApiClient, Theme, NotificationService, WidgetService    │
│  → Infraestrutura horizontal reutilizável                │
│  → Não depende de nenhuma camada acima                   │
└──────────────────────────────────────────────────────────┘
```

**Por que `provider` junto com `flutter_bloc`?**
`AuthService` é exposto via `RepositoryProvider` (do pacote `provider`) porque não tem estado reativo — é um serviço imperativo. Os Cubits são expostos via `BlocProvider` porque têm estado. Misturar os dois é intencional e idiomático no ecossistema bloc.

### 3.2 Injeção de Dependências — Manual e Explícita

Sem `get_it`, sem `injectable`. Tudo instanciado em `main.dart`:

```dart
final apiClient = ApiClient();              // singleton manual
final authService = AuthService(apiClient);
final waterService = WaterService(apiClient);
final settingsService = SettingsService(apiClient);
```

Os Cubits recebem os services **pelo construtor** — essa é a DI clássica. A consequência é que:
- É fácil trocar implementações (ex: mock nos testes)
- O grafo de dependências é totalmente visível no `main.dart`
- Não há "magia" de container de DI

O `ApiClient` é uma instância única passada para todos os services. Isso é importante: quando `AuthService.login()` chama `apiClient.setToken(token)`, **todos os services já ganham o header Authorization** na próxima request, porque compartilham a mesma instância do `Dio`.

---

## 4. Gerenciamento de Estado — Cubit em Profundidade

### 4.1 Por que Cubit e não Bloc?

Cubit é uma versão simplificada do Bloc sem `Event`. Aqui não há necessidade de rastrear eventos (auditoria, undo/redo complexo), então Cubit elimina boilerplate desnecessário. A regra é simples: se precisar de histórico de eventos, use Bloc; caso contrário, use Cubit.

### 4.2 Dois estilos de State

**Estilo 1: subclasses seladas** (HomeState, HistoryState, NotificationState, LoginState, RegisterState)

```dart
abstract class HomeState {}
class HomeInitial extends HomeState {}
class HomeLoading extends HomeState {}
class HomeLoaded extends HomeState { final int currentIntake; ... }
class HomeOffline extends HomeState { final int pendingCount; ... }
class HomeError extends HomeState { final String message; }
```

Quando usar: estados **mutuamente exclusivos** onde cada estado tem um conjunto diferente de dados.

Na UI, o `BlocBuilder` vira um `if/else is` — o compilador garante que você trate todos os casos.

**Estilo 2: state único com copyWith** (SettingsState)

```dart
class SettingsState {
  final String name;
  final double dailyGoal;
  final bool isLoading;
  final String? error;
  // ...
  SettingsState copyWith({ ... }) { ... }
}
```

Quando usar: quando os dados formam um **objeto coeso** onde vários campos mudam juntos (settings é um formulário com vários campos, não tem sentido modelar como subclasses).

### 4.3 Optimistic Update — O padrão completo

Toda mutação no app usa este padrão:

```dart
Future<void> updateSetting(String key, dynamic value) async {
  final oldState = state;           // 1. salva estado atual
  emit(state.copyWith(...));        // 2. atualiza UI imediatamente (otimista)
  try {
    await service.update(...);      // 3. tenta persistir
  } catch (e) {
    emit(oldState);                 // 4. ROLLBACK se falhar
    // opcionalmente: restaurar efeito colateral (ex: tema)
  }
}
```

**Por que retornar `String?` e não lançar exceção?**
`HomeCubit.addWater()` retorna `String?` (mensagem de erro ou null). Isso porque o Cubit **não deve interagir com a UI diretamente** — não pode chamar `ScaffoldMessenger`. A página chama `addWater()`, recebe o erro e decide como exibir. É separação de responsabilidades: o Cubit decide o que deu errado, a UI decide como mostrar.

### 4.4 BlocBuilder vs BlocConsumer

```dart
// BlocBuilder: só reconstrói widgets
BlocBuilder<SettingsCubit, SettingsState>(
  builder: (context, state) => ...,
)

// BlocConsumer: reconstrói + efeito colateral
BlocConsumer<HomeCubit, HomeState>(
  listenWhen: (prev, curr) => curr is HomeLoaded && curr.syncedCount > 0,
  listener: (context, state) {
    // mostra SnackBar — efeito colateral que não é widget
  },
  builder: (context, state) => ...,
)
```

`listenWhen` é crucial: filtra para executar o `listener` apenas quando a condição for true — evita SnackBars duplicados quando o estado muda por outros motivos.

### 4.5 BlocObserver em Debug

```dart
class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    debugPrint('🔄 ${bloc.runtimeType}: ${change.currentState.runtimeType} → ${change.nextState.runtimeType}');
  }
}
```

Registrado em `main()` apenas em `kDebugMode`. Loga **toda** transição de estado de todos os Cubits. Essencial para debug — você vê no console exatamente a sequência de estados.

---

## 5. HomeCubit — A Peça Central do App

O `HomeCubit` é o mais complexo do projeto. Entender ele é entender 60% do comportamento do app.

### 5.1 Máquina de estados completa

```
HomeInitial
    │ loadTodayData()
    ▼
HomeLoading
    ├── sem internet ──────────────────────────────► HomeOffline
    │                                                    │
    │                                                    │ internet volta (Stream)
    │                                                    │ _syncAndReload()
    │                                                    │    ├── isSyncing=true → HomeOffline(isSyncing=true)
    │                                                    │    ├── envia pending_logs via API
    │                                                    │    └── loadTodayData()
    │                                                    │         └──────────────────────────────────┐
    │                                                    │                                             │
    └── API OK ────────────────────────────────────► HomeLoaded ◄───────────────────────────────────┘
    │                                                    │
    └── API falha ─────────────────────────────────► HomeOffline (mesmo que sem internet)
```

**Detalhe crítico**: se a API falha (timeout, 500, etc.) o app cai em `HomeOffline` — não em `HomeError`. `HomeError` só aparece se `getTodayData()` retorna `null` (dados válidos mas vazios). Isso é uma escolha de UX: uma falha de rede não deve bloquear o usuário.

### 5.2 Connectivity Stream — Race condition protegida

```dart
HomeCubit(this._waterService) : super(HomeInitial()) {
  _connectivitySub = ConnectivityService.onConnectivityChanged.listen(
    (results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (isConnected && _isOffline) {
        _isOffline = false;
        _syncAndReload();
      } else if (!isConnected && !_isOffline) {
        _isOffline = true;
      }
    },
  );
}
```

O `_isOffline` é uma flag local que evita que `_syncAndReload()` seja chamado múltiplas vezes se o stream emitir vários eventos rápidos (o Android às vezes emite `none` + `wifi` em sequência). Só entra em `_syncAndReload` se **estava** offline e **agora está** online.

`@override Future<void> close()` cancela o `StreamSubscription` — sem isso, vazamento de memória garantido porque o stream do `connectivity_plus` é broadcast e infinito.

### 5.3 Fluxo de adição de água — Online

```dart
// 1. Update otimista IMEDIATO (UI não trava)
final optimisticIntake = currentState.currentIntake + ml;
emit(HomeLoaded(
  currentIntake: optimisticIntake,
  todayHistory: [{"id": "temp_${timestamp}", ...}, ...currentHistory],
  ...
));

// 2. Atualiza widget Android com o valor otimista
_updateWidget(progress, optimisticIntake, dailyGoal);

// 3. Chama API em background
await _waterService.addWater(ml);

// 4. Substitui o estado otimista pelos dados reais da API
await refreshTodayData(); // → substitui "temp_xxx" pelo id real

// 5. Se API falhar: ROLLBACK
emit(currentState); // volta ao estado anterior
_updateWidget(currentState.progress, currentState.currentIntake, currentState.dailyGoal);
```

O item com `id: "temp_xxx"` é tratado na UI para mostrar "Adicionando..." como texto, enquanto o id real não chega. Ao chamar `refreshTodayData()` depois, o estado é substituído pelos dados reais com IDs definitivos.

### 5.4 Fluxo de adição — Offline

```dart
// Sem chamar API — tudo local
await LocalDatabaseService.addPendingLog(ml);         // persiste na fila SQLite
await LocalDatabaseService.updateCachedIntake(newIntake); // atualiza o cache

// Emit HomeOffline atualizado com novo intake
emit(HomeOffline(currentIntake: newIntake, pendingCount: ..., ...));
```

O usuário vê o progresso aumentar imediatamente, mesmo sem internet. A quantidade fica em `pending_logs` até a sincronização.

### 5.5 Sincronização ao reconectar

```dart
Future<void> _syncAndReload() async {
  final pending = await LocalDatabaseService.getPendingLogs();
  if (pending.isEmpty) { await loadTodayData(); return; }

  // Mostra indicador "Sincronizando N registros..." no banner
  emit(HomeOffline(..., isSyncing: true));

  // Envia um por um (sequencial, não paralelo — garante ordem)
  for (final log in pending) {
    await _waterService.addWater(log['amount']);
    await LocalDatabaseService.markLogSynced(log['id']); // synced=1
    syncedCount++;
  }

  _pendingSyncedCount = syncedCount;
  await loadTodayData(); // → emite HomeLoaded com syncedCount > 0
  _pendingSyncedCount = 0; // reseta após o emit
}
```

**Por que sequencial e não `Future.wait`?** Para garantir a ordem cronológica dos registros no banco. Se fossem paralelas e uma falhasse no meio, seria difícil controlar o estado de sincronização.

**Por que `markLogSynced` ao invés de deletar?** Registro histórico. Se algo der errado, é possível inspecionar o que foi sincronizado. Os registros com `synced=1` não aparecem mais em `getPendingLogs()`.

---

## 6. Offline-First — LocalDatabaseService em Detalhe

### 6.1 Schema SQLite

```sql
CREATE TABLE cached_data (
  id INTEGER PRIMARY KEY,
  date TEXT UNIQUE,     -- 'YYYY-MM-DD' — só um registro por dia
  total_intake INTEGER,
  daily_goal INTEGER,
  user_name TEXT,
  updated_at TEXT
);

CREATE TABLE pending_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  amount INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  synced INTEGER DEFAULT 0  -- 0=pendente, 1=sincronizado
);
```

`cached_data` usa `CONFLICT REPLACE` no insert — funciona como upsert. Toda vez que o app carrega dados da API, atualiza o cache do dia atual.

### 6.2 Lazy initialization do banco

```dart
static Database? _db;
static Future<Database> get _database async {
  _db ??= await _initDB(); // inicializa só na primeira chamada
  return _db!;
}
```

O banco só é aberto quando o primeiro método de `LocalDatabaseService` é chamado. Evita abrir no boot do app desnecessariamente.

---

## 7. Sistema de Notificações — Complexidade Real

`NotificationService` é o componente mais complexo do projeto. É um **Singleton** (`factory NotificationService() => _instance`) — qualquer lugar que chame `NotificationService()` recebe a mesma instância.

### 7.1 Canais Android por vibração

O Android identifica canais de notificação pelo ID. Uma vez criado com vibração ativa, o usuário pode desativar vibração nas configurações do sistema — **o app não tem controle**. A solução adotada:

```dart
String _androidChannelNowId() =>
    _vibrationEnabled ? 'bebeu_water_now' : 'bebeu_water_now_nv';
String _androidChannelScheduledId() =>
    _vibrationEnabled ? 'bebeu_hydration_scheduled' : 'bebeu_hydration_scheduled_nv';
```

Dois canais separados por tipo de vibração. Quando o usuário muda vibração:
1. `setVibrationEnabled(bool)` é chamado
2. Cria (ou recria) os canais com os IDs corretos
3. Se os lembretes estavam ativos, re-agenda usando o novo canal

### 7.2 O problema do limite de alarmes Android

Android limita ~500 alarmes exatos por app. O `NotificationService` usa **420** como limite com margem de segurança.

**Cenário problemático**: usuário ativa notificações a cada 30 min das 08:00 às 22:00 todos os dias da semana:
- Marcas por dia: (22h - 8h) × 2 = 28 marcas
- Por semana: 28 × 7 = 196 alarmes → cabe

**Cenário extremo**: a cada 30 min, todos os dias, janela 00:00–23:59:
- 48 marcas × 7 = 336 alarmes → ainda cabe

Se ultrapassar 420, o algoritmo `_hydrationSlotsEvenPerDay` distribui igualmente os slots disponíveis entre os dias ativos.

### 7.3 Dois modos de agendamento

**Modo "Todos os dias"** (`_activeDaysAreFullWeek` → true):

Usa `matchDateTimeComponents.time` — o Android re-dispara o alarme todo dia naquele horário. Um único alarme para "08:00" dispara todo dia às 08:00. Eficiente em número de alarmes.

```dart
await _notificationsPlugin.zonedSchedule(
  id: _scheduledReminderIdBase + total, // id único por horário
  scheduledDate: _nextDailyClockTime(hour, minute),
  matchDateTimeComponents: DateTimeComponents.time, // repete todo dia
  ...
)
```

**Modo "Dias específicos"** (`_activeDaysAreFullWeek` → false):

Usa `matchDateTimeComponents.dayOfWeekAndTime` — repete semanalmente no mesmo dia da semana e horário.

```dart
id: _scheduledReminderIdBase + (s.weekday * 1440 + s.totalMinutes)
// Fórmula garante ID único por (dia_da_semana, horário)
// Ex: terça(2) às 10:00(600min) → 20000 + (2*1440 + 600) = 23480
```

### 7.4 Race condition no agendamento

O re-agendamento envolve: cancelar todos + agendar novos. Se chamado duas vezes em sequência rápida, pode resultar em alarmes duplicados. A solução é um `Future` chain:

```dart
Future<void> _scheduleChain = Future<void>.value(); // começa resolvido

Future<void> scheduleHydrationReminders(NotificationPreferences prefs) async {
  _scheduleChain = _scheduleChain
      .catchError((_) {}) // engole erro da tentativa anterior
      .then((_) => _scheduleHydrationRemindersImpl(prefs)); // enfileira
  await _scheduleChain;
}
```

Qualquer chamada enquanto a anterior ainda executa é enfileirada, nunca paralela.

### 7.5 Quick Add via notificação — Background execution

O botão `+ Xml ml` na notificação executa código **com o app fechado**. Isso é possível via `onDidReceiveNotificationResponse`:

```dart
// A notificação tem uma action:
AndroidNotificationAction(
  'quick_add_water',       // actionId
  '+ 200ml',
  showsUserInterface: true, // abre o app em foreground
  cancelNotification: true,
)

// Quando o usuário toca, o callback é chamado:
Future<void> _onNotificationResponse(NotificationResponse details) async {
  if (details.actionId != _quickAddActionId) return;
  final ml = await _resolveQuickAddAmount();
  await _onQuickAddFromNotification!(ml);
}
```

O `_onQuickAddFromNotification` é configurado em `main.dart` com uma closure que acessa `waterService` e `settingsService` — serviços já inicializados no processo principal.

### 7.6 Milestones de progresso — Controle de duplicatas

```dart
final Set<int> _notifiedMilestones = {};

void checkProgressAndNotify({required int current, required int goal, ...}) {
  if (current >= goal && !_notifiedMilestones.contains(100)) {
    _notifiedMilestones.add(100); // marca como notificado
    // dispara notificação de meta atingida
  } else if (percent >= 80 && !_notifiedMilestones.contains(80)) {
    _notifiedMilestones.add(80);
    // dispara notificação 80%
    _startProgressReminder(); // timer de 30 min para relnbrar
  }
  // ...
}
```

O `Set<int>` garante que cada milestone (70%, 80%, 100%) só dispara **uma vez por sessão**. O `resetDailyMilestones()` existe para resetar no início de um novo dia — mas atualmente não é chamado automaticamente (ponto de melhoria).

---

## 8. Widget Nativo Android — Background Isolate

### 8.1 A anotação `@pragma('vm:entry-point')`

```dart
@pragma('vm:entry-point')
Future<void> homeWidgetInteractiveCallback(Uri? uri) async { ... }
```

Esta anotação informa ao compilador Dart/Flutter que esta função pode ser chamada de fora do isolate principal (pelo Android). **Sem ela**, o tree-shaking do compilador pode remover a função, quebrando o callback silenciosamente em builds release.

### 8.2 O problema do isolate separado

Quando o usuário toca no `+` do widget Android, o Android chama `homeWidgetInteractiveCallback` em um **processo/isolate separado** do app. Isso significa:

- O `ApiClient` do `main.dart` não existe neste contexto
- O `HomeCubit` não existe
- O token JWT não está no header do Dio

Por isso, o callback precisa **reinicializar tudo do zero**:

```dart
WidgetsFlutterBinding.ensureInitialized();      // necessário para plugins
DartPluginRegistrant.ensureInitialized();         // registra plugins no isolate

final token = await _storage.read(key: 'jwt_token'); // lê do secure storage
if (token == null) return; // não está logado

final client = ApiClient();    // nova instância
client.setToken(token);
final water = WaterService(client);
final notify = NotificationService();
await notify.initialize(requestPermissions: false); // sem pedir permissão de novo

// executa a ação
await water.addWater(quickAddAmount);
await WidgetService.updateHomeWidget(...); // atualiza o widget
```

`requestPermissions: false` é crítico — não pode exibir dialog de permissão em background.

### 8.3 Registro em `main.dart`

```dart
await HomeWidget.registerInteractivityCallback(homeWidgetInteractiveCallback);
```

Registra a função como handler do Android antes do `runApp`. Deve ser feito em toda inicialização do app.

---

## 9. Tema — ValueNotifier sem reconstrução global

O tema usa `ValueNotifier<ThemeMode>` ao invés de Cubit:

```dart
static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
```

**Por que não um Cubit?** O tema precisa ser acessado e modificado de qualquer lugar, inclusive fora da árvore de widgets (ex: `AppTheme.initialize()` em `main()` antes do `runApp`). Um `ValueNotifier` estático resolve isso sem precisar de `BuildContext`.

Em `MyApp`:

```dart
ValueListenableBuilder<ThemeMode>(
  valueListenable: AppTheme.themeMode,
  builder: (context, mode, child) {
    return MaterialApp.router(themeMode: mode, ...);
  },
)
```

Só o `MaterialApp.router` é reconstruído quando o tema muda — não a árvore inteira.

**Inicialização antecipada**: `AppTheme.initialize()` é chamado **antes** de `runApp`. Isso garante que quando o primeiro frame é renderizado, o tema correto já está definido. Sem isso, o app pisca do tema padrão para o salvo.

### 9.1 Persitência de tema — Dois mecanismos

1. **SharedPreferences** (local): persiste `'light'`/`'dark'`/`'system'` em `AppTheme._themeModeKey`
2. **API** (remota): `SettingsCubit.loadSettings()` sincroniza o tema do servidor e salva em SharedPreferences com `persist: true`

A inicialização do app lê SharedPreferences (rápido, sem rede). A API sincroniza depois, quando o `SettingsCubit` carrega. Se o usuário usa dois dispositivos, a API garante sincronização.

---

## 10. Navegação (GoRouter)

### 10.1 Estrutura de rotas

```dart
GoRoute(path: '/splash', builder: (_, __) => SplashPage(isLoggedIn: loggedIn)),
GoRoute(path: '/login', builder: (_, __) => BlocProvider(
  create: (_) => LoginCubit(authService), child: LoginPage()
)),
GoRoute(path: '/register', builder: (_, __) => BlocProvider(
  create: (_) => RegisterCubit(authService), child: RegisterPage()
)),
GoRoute(path: '/home', builder: (_, __) => const HomePage()),
```

`LoginCubit` e `RegisterCubit` são criados **dentro da rota** — isso garante que são destruídos quando a rota é descartada (menos vazamentos). O `HomePage` não precisa de `BlocProvider` porque os Cubits principais (`HomeCubit`, `HistoryCubit`, etc.) estão no `MultiBlocProvider` global.

### 10.2 Splash como redirect

`SplashPage` recebe `isLoggedIn` calculado em `main()`:

```dart
final loggedIn = await authService.isLoggedIn();
```

`authService.isLoggedIn()` lê o token do `FlutterSecureStorage`. Se existir, seta no `ApiClient` e retorna `true`. A splash mostra a animação Lottie e ao completar navega para `/home` ou `/login`.

**Fallback de navegação**: se a animação falhar (asset corrompido, etc.), um `Future.delayed(1s)` garante que o usuário não fica preso na splash:

```dart
void _scheduleFallbackNavigation() {
  if (_scheduledFallbackNavigation) return; // só agenda uma vez
  _scheduledFallbackNavigation = true;
  Future.delayed(const Duration(seconds: 1), _navigateToNextScreen);
}
```

### 10.3 HomePage — PageView sem swipe

```dart
PageView.builder(
  controller: controller,
  physics: const NeverScrollableScrollPhysics(), // swipe desativado
  itemCount: children.length,
  ...
)
```

O swipe é desativado por UX — o gráfico de barras do histórico e os sliders do settings conflitariam com o swipe horizontal da PageView.

A animação de transição entre abas é customizada com `AnimatedBuilder`:

```dart
final page = controller.page ?? initialPage.toDouble();
final difference = (index - page).abs();
final opacity = (1 - (difference * 0.3)).clamp(0.0, 1.0); // fade-out lateral
final slideValue = (index - page) * 30; // offset vertical (sobe/desce)

return Opacity(opacity: opacity, child: Transform.translate(offset: Offset(0, slideValue.abs()), child: child));
```

Efeito: ao trocar de aba, a aba anterior some com fade + leve deslizamento para cima. Mais fluido que o slide horizontal padrão.

---

## 11. Mapeamento de Dias da Semana — Bug clássico resolvido

Este é um gotcha que poderia causar notificações no dia errado:

| Contexto | Domingo | Segunda | ... | Sábado |
|---|---|---|---|---|
| Backend (Prisma/JS) | 0 | 1 | ... | 6 |
| Flutter (DateTime) | 7 | 1 | ... | 6 |
| Notificação (timezone pkg) | 7 | 1 | ... | 6 |

`NotificationPreferences.fromJson` faz o mapeamento:

```dart
final List<int> mappedDays = rawDays.map((day) {
  if (day == 0) return 7; // Domingo: 0 (backend) → 7 (Flutter)
  return day;
}).toList();
```

`toJson` faz o inverso:

```dart
final List<int> backendDays = activeDays.map((day) {
  if (day == 7) return 0; // Domingo: 7 (Flutter) → 0 (backend)
  return day;
}).toList();
```

**Adicionalmente**: o campo `daysOfWeek` no PostgreSQL é `Int[]` — Prisma pode serializar como string JSON em algumas versões. O `fromJson` protege contra isso:

```dart
dynamic dow = json['daysOfWeek'];
if (dow is String) {
  try { dow = jsonDecode(dow); } catch (_) { dow = null; }
}
```

---

## 12. Timezone no Backend — Como funciona de verdade

O app envia em **todo request** o header:

```dart
'x-timezone-offset': DateTime.now().timeZoneOffset.inMinutes.toString()
// Brasil (UTC-3): retorna '-180'
// Portugal (UTC+0): retorna '0'
// India (UTC+5:30): retorna '330'
```

No backend, `getStartOfUserDayInUTC` usa esse offset para calcular a meia-noite **local do usuário** em UTC:

```typescript
// Usuário está no Brasil (offset = -180 min)
// Agora é 2026-04-10 01:00:00 UTC → que é 2026-04-09 22:00:00 Brasil

const offsetMinutes = -180  // lido do header (app manda -180 para UTC-3)
const now = new Date()  // 2026-04-10T01:00:00Z

// Converte para o "relógio local do usuário" (fictício, em UTC)
const userLocalNow = new Date(now.getTime() + (offsetMinutes * 60 * 1000))
// = 2026-04-10T01:00:00Z + (-180 * 60000) = 2026-04-09T22:00:00Z
// = representa "22:00 no relógio do usuário"

// Define meia-noite local
userLocalNow.setUTCHours(0, 0, 0, 0)  // = 2026-04-09T00:00:00Z (local 00:00)

// Converte de volta para UTC real
return new Date(userLocalNow.getTime() - (offsetMinutes * 60 * 1000))
// = 2026-04-09T00:00:00Z - (-180 * 60000) = 2026-04-09T03:00:00Z
// = meia-noite Brasil em UTC
```

Resultado: o servidor filtra `WHERE date >= '2026-04-09T03:00:00Z'` que corresponde a meia-noite brasileira. Sem esse cálculo, usuários fora de UTC teriam registros cortados no meio da noite.

### 12.1 Histórico semanal — DOM a SAB

A rota `/water/history` sem parâmetros retorna a **semana atual de Domingo a Sábado** (não os últimos 7 dias):

```typescript
const dayOfWeek = userLocalNow.getUTCDay() // 0=Dom, 6=Sab no "relógio local"
const localSunday = new Date(userLocalNow)
localSunday.setUTCDate(localSunday.getUTCDate() - dayOfWeek) // vai para domingo
```

E a média diária considera **dias decorridos da semana**, não 7 dias fixos:

```typescript
const daysElapsed = userLocalNow.getUTCDay() + 1 // 1 se for domingo, 7 se for sábado
const average = Math.round(totalIntake / daysElapsed)
```

Isso evita médias artificialmente baixas no início da semana. Na UI (`history_view.dart`), o Flutter recalcula os stats localmente usando a mesma lógica (`now.weekday % 7 + 1`).

---

## 13. AuthService — Segurança do Token

### 13.1 FlutterSecureStorage por plataforma

```dart
static const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
```

- **Android**: usa `EncryptedSharedPreferences` — criptografia AES-256 via Android Keystore
- **iOS**: usa Keychain com `first_unlock` — acessível após o primeiro unlock do dispositivo (permite acesso em background depois que o usuário desbloqueou pelo menos uma vez)

### 13.2 Fluxo de mudança de senha

```
1. PUT /settings/password { currentPassword, newPassword }
2. Backend: bcrypt.compare(curPass, user.password)   → valida senha atual
3. Backend: bcrypt.hash(newPass, 10)                → gera novo hash
4. Backend: prisma.user.update({ password: hash })   → salva
5. Resposta: 200 OK ou 400 "Senha atual incorreta"
```

**O JWT não é invalidado após mudança de senha.** Token existente continua válido por 7 dias. Ponto de segurança para considerar em evoluções futuras.

### 13.3 Logout completo

```dart
Future<void> logout() async {
  await _storage.delete(key: _tokenKey);   // remove do secure storage
  _apiClient.clearToken();                  // remove do header do Dio
}
```

Na `SettingsView`, além do `logout()`, o app também limpa SharedPreferences:

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.clear();  // limpa tema local
await authService.logout();
context.go('/login');
```

---

## 14. Backend — Decisões de Design

### 14.1 Partial update em `/settings`

O `updateSettings` aceita qualquer subconjunto de campos:

```typescript
data: {
  name: name !== undefined ? String(name) : undefined,
  dailyGoal: dailyGoal !== undefined ? Number(dailyGoal) : undefined,
  // ...
}
```

Prisma ignora campos `undefined`. Isso permite o app enviar `{ theme: 'dark' }` sem precisar enviar todos os outros campos. Cada mudança de configuração na UI dispara uma request com apenas o campo alterado.

### 14.2 NotificationSetting — Upsert

```typescript
await prisma.notificationSetting.upsert({
  where: { userId },
  create: { userId, type: '...', ... },
  update: { type: '...', ... },
});
```

Usuários criados antes da `NotificationSetting` existir no schema podem não ter o registro. O upsert garante que sempre existe, sem erro de "not found".

### 14.3 `deleteWater` — Verificação de ownership

```typescript
const log = await prisma.waterLog.findUnique({ where: { id } })
if (log.userId !== userId) {
  return res.status(403).json({ error: "Não autorizado" })
}
await prisma.waterLog.delete({ where: { id } })
```

Sempre verifica que o registro pertence ao usuário autenticado antes de deletar. Evita que um usuário delete registros de outro conhecendo o UUID.

### 14.4 Índice de performance

```prisma
@@index([userId, date])
```

As queries mais frequentes são `WHERE userId = ? AND date >= ? AND date <= ?`. O índice composto cobre exatamente esse padrão — fundamental para performance conforme o banco cresce.

---

## 15. Models — Transformações de Dados

### 15.1 DailyWaterDataModel

```dart
factory DailyWaterDataModel.fromJson(Map<String, dynamic> json) {
  return DailyWaterDataModel(
    total: json['total'] ?? 0,
    dailyGoal: json['dailyGoal'] ?? 2000,  // fallback se não vier
    name: json['name'] ?? 'Usuário',
    remaining: json['remaining'] ?? 0,
    percent: (json['percent'] ?? 0.0).toDouble(),
    logs: (json['logs'] as List?)
        ?.map((log) => WaterLogModel.fromJson(log))
        .toList() ?? [],
  );
}
```

O `?? valor` em cada campo é defensive coding — a API pode retornar campos nulos em edge cases (ex: usuário sem goal definido). Não deve lançar exceção de NPE.

### 15.2 WaterLogModel — Conversão de fuso

```dart
factory WaterLogModel.fromJson(Map<String, dynamic> json) {
  return WaterLogModel(
    id: json['id'] ?? '',
    amount: json['amount'] ?? 0,
    date: DateTime.parse(json['date'].toString()).toLocal(), // UTC → local
  );
}
```

`.toLocal()` converte a data UTC do backend para o fuso local do dispositivo. Sem isso, o horário exibido na UI estaria em UTC.

---

## 16. UI — Detalhes Não Óbvios

### 16.1 AddWaterButton — Comportamento duplo

- **Toque simples**: adiciona `quickAddAmount` ml imediatamente + animação de burst (texto `+Xml` que sobe e some)
- **Long press**: abre modal com slider para escolher quantidade entre 50ml e 1000ml (divisões de 50ml)

A animação usa `AnimationController` com `SingleTickerProviderStateMixin`:

```dart
_opacity = Tween<double>(begin: 1, end: 0).animate(
  CurvedAnimation(parent: _controller,
    curve: const Interval(0.28, 1, curve: Curves.easeOut)),
);
_slide = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -2.2))
    .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
```

`Interval(0.28, 1)` faz o fade começar só em 28% da animação — o texto primeiro sobe, depois some.

### 16.2 Dismissible — Por que `return false`

```dart
confirmDismiss: (direction) async {
  await cubit.deleteWaterLog(log["id"]); // cubit remove da lista otimisticamente
  // mostra SnackBar com "Desfazer"
  return false; // NÃO deixa o Dismissible remover o widget
},
```

O Cubit já removeu o item da lista ao emitir o novo state. Se `return true`, o `Dismissible` também tentaria remover o widget — conflito que causaria `setState called after dispose`. Retornar `false` delega o controle de remoção visual ao estado do Cubit.

### 16.3 Slider de Meta — Dois callbacks distintos

```dart
Slider(
  onChanged: (value) {
    cubit.slideDailyGoal(value); // só atualiza estado local, SEM API
  },
  onChangeEnd: (value) {
    cubit.updateSetting('dailyGoal', value); // SÓ aqui chama a API
  },
)
```

`slideDailyGoal` existe especificamente para isso — atualizar o valor visual enquanto o usuário arrasta, sem spam de requests HTTP. Só dispara a request quando o usuário solta o slider.

### 16.4 HomeOffline — Conteúdo "mocado"

```dart
// Cria um HomeLoaded falso para reutilizar os widgets de progresso
final mockedLoaded = HomeLoaded(
  currentIntake: state.currentIntake,
  dailyGoal: state.dailyGoal,
  // ...
  todayHistory: const [], // histórico vazio no offline
);

Opacity(opacity: 0.55, child: _buildCircularProgress(theme, colors, mockedLoaded))
```

Reutiliza os mesmos widgets do modo online, mas com opacidade reduzida para indicar que são dados do cache. O histórico fica bloqueado com overlay "Histórico disponível quando conectado".

### 16.5 `@Preview` annotations

```dart
@Preview(name: 'Settings - Light')
Widget settingsViewLightPreview() { ... }
```

São annotations do pacote `flutter/widget_previews.dart` para visualizar widgets no Flutter DevTools sem rodar o app. Não impactam o build de produção.

---

## 17. Configurações — Fluxo de Sincronização

As configurações têm **duas fontes de verdade**: API (remota, canônica) e estado local do Cubit.

```
App abre
  → AppTheme.initialize()         [SharedPreferences — rápido, sem rede]
  → SettingsCubit.loadSettings()  [GET /settings — sincroniza do servidor]
      → applyTheme(persist: true) [atualiza SharedPreferences com o tema do servidor]
      → emit(state.copyWith(...)) [atualiza todos os campos]
      → NotificationService().setVibrationEnabled(state.vibration)

Usuário muda configuração
  → updateSetting('theme', 'dark')
      → AppTheme.setThemeFromString('dark', persist: true) [aplica imediatamente]
      → emit(state.copyWith(theme: 'dark'))                [otimista]
      → PUT /settings { theme: 'dark' }                   [persiste no servidor]
      → se falhar: emit(oldState) + AppTheme.setThemeFromString(oldTheme)
```

---

## 18. `NotificationCubit` — O que carrega e o que agenda

```dart
Future<void> loadPreferences() async {
  final data = await _settingsService.getSettings();
  final prefs = NotificationPreferences.fromJson(data['notificationSettings'] ?? {});
  emit(NotificationLoaded(prefs));

  if (prefs.enabled) {
    await _notificationService.scheduleHydrationReminders(prefs); // re-agenda sempre
  }
}
```

**Detalhe importante**: `scheduleHydrationReminders` é chamado toda vez que `loadPreferences` executa — inclusive ao abrir o app. Isso garante que se o usuário reinstalou o app (alarmes perdidos) ou atualizou o OS (alarmes limpos), os lembretes voltam automaticamente na próxima abertura.

`AlertsView.initState()` chama `loadPreferences()` explicitamente ao entrar na aba — garante sincronia do servidor mesmo que o Cubit tenha dados em cache de uma sessão anterior.

---

## 19. Pontos de Melhoria / Dívidas Técnicas

### Críticos

1. **JWT sem refresh**: token expira em 7 dias e não há renovação automática. Ao expirar, o usuário recebe erro 401 silencioso — o app não redireciona para login. O `ApiClient` não tem interceptor de 401.

2. **`resetDailyMilestones()` não é chamado automaticamente**: os milestones de notificação (70%, 80%, 100%) são resetados apenas quando `NotificationService` é recriado (reinício do app). Se o usuário usar o app por mais de 24h sem fechar, não receberá notificações de meta no novo dia.

3. **`NotificationCubit` e `SettingsCubit` fazem GET /settings separados**: duas chamadas HTTP desnecessárias ao inicializar. Poderiam compartilhar o mesmo request.

### Menores

4. **`SettingsView` instancia `SharedPreferences` diretamente na UI** no botão de logout — deveria estar em um método do `SettingsCubit`.

5. **`_pendingSyncedCount` como variável de instância**: usado para passar dados entre `_syncAndReload()` e o `emit()` de `loadTodayData()`. É um anti-pattern leve — poderia ser parâmetro de método.

6. **Sem tratamento de conflito de sincronização offline**: se o usuário adicionou água offline e online no mesmo período, os dados são somados sem deduplicação.

---

## 20. Como o App se Comporta em Diferentes Cenários

| Cenário | Comportamento |
|---|---|
| App abre, token válido, com internet | splash → home com dados da API |
| App abre, token válido, sem internet | splash → home com dados do SQLite cache |
| App abre, sem token | splash → login |
| Usuário perde internet no meio do uso | HomeCubit escuta Stream, emite HomeOffline |
| Usuário reconecta | HomeCubit sincroniza pending_logs → emite HomeLoaded com syncedCount |
| Usuário adiciona água sem internet | salva em pending_logs, atualiza cache, mostra progresso |
| Widget Android `+` clicado com app fechado | background isolate inicializa tudo, chama API, atualiza widget |
| Notificação recorrente com botão `+` | `_onNotificationResponse` → chama handler configurado no `main()` |
| Token expira (7 dias) | request retorna 401, Dio lança `DioException`, cubit trata como erro de rede |

---

## 21. Guia de Navegação do Código por Tipo de Tarefa

### "Preciso mudar o que aparece na home"
→ `lib/presentation/home/home_page.dart` (métodos `_buildHomeContent`, `_buildCircularProgress`, etc.)

### "Preciso mudar a lógica de adicionar água"
→ `lib/presentation/home/cubit/home_cubit.dart` método `addWater()`
→ `lib/data/services/water_service.dart` método `addWater()`
→ `backend/src/water.ts` função `addWater()`

### "Preciso adicionar um campo novo nas configurações"
1. `backend/prisma/schema.prisma` → adiciona campo no model User
2. `backend/src/settings.ts` → adiciona no `select` do `getSettings` e no `data` do `updateSettings`
3. `lib/presentation/home/cubit/settings_cubit.dart` → adiciona no `SettingsState` + `copyWith` + `loadSettings` + `updateSetting`
4. `lib/presentation/home/widgets/settings_view.dart` → adiciona na UI

### "Preciso mudar como as notificações são agendadas"
→ `lib/core/services/notification_service.dart` (métodos `_hydrationSlotsUnified`, `_scheduleHydrationRemindersImpl`)
→ `lib/core/models/notification_preferences.dart` (modelo de dados das prefs)
→ `lib/presentation/home/widgets/alerts_view.dart` (UI de configuração)
→ `lib/presentation/home/cubit/notification_cubit.dart` (coordena carga + agendamento)

### "Preciso adicionar um novo endpoint no backend"
1. `backend/src/<feature>.ts` → cria função handler tipada com `AuthRequest`
2. `backend/src/routes.ts` → registra rota com `authMiddleware` se precisar de auth
3. `lib/data/services/<feature>_service.dart` → cria método com Dio
4. Cubit correspondente → chama o service

### "Preciso entender por que X está aparecendo errado no histórico"
→ `backend/src/water.ts` função `history()` (cálculo de semana e timezone)
→ `lib/presentation/home/widgets/history_view.dart` classe `_ChartSectionState` (agrupa logs por dia local)
→ `lib/core/models/notification_preferences.dart` `fromJson` (mapeamento de dias da semana)
