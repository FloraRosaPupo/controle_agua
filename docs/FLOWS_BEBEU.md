# Fluxos principais — Bebeu

Diagramas em [Mermaid](https://mermaid.js.org/) (GitHub, Notion ou [mermaid.live](https://mermaid.live) renderizam automaticamente).

---

## 1) Arranque do app (`main.dart`)

```mermaid
flowchart TD
  A[main: WidgetsFlutterBinding] --> B{Android?}
  B -->|sim| C[MidnightWidgetAlarm.ensureInitialized]
  B -->|não| D[ignora alarme]
  C --> E[Supabase, tema, JWT, etc.]
  D --> E
  E --> F[HomeWidget.registerInteractivityCallback]
  F --> G[NotificationService.initialize]
  G --> H[configureQuickAddAction: onQuickAdd]
  H --> I[_syncWidgetWithLatestData]
  I --> J[runApp + MyApp]
  J --> K{Android?}
  K -->|sim| L[Listener AppJwt: agenda ou cancela alarme meia-noite]
```

---

## 2) Toque no “+” da **notificação** (lembrete)

O handler em `NotificationService` reage à **ação** `quick_add_water`. Antes exigia também `payload == hydration_recurring`; em alguns OEMs o `payload` vinha vazio e o “+” não fazia nada.

```mermaid
flowchart TD
  A[Utilizador toca na ação + da notificação] --> B[NotificationService._onNotificationResponse]
  B --> C{actionId == quick_add_water?}
  C -->|não| Z[Fim]
  C -->|sim| D[Resolver ml: SettingsService ou fallback]
  D --> E[onQuickAdd em main.dart]
  E --> F[fallbackGoal: UserGoalCache e/ou API]
  F --> G[WaterService.addWater]
  G -->|sucesso| H[getTodayData + showProgressNotification]
  G -->|erro| I{Falha de rede? connectivity + heurística}
  I -->|sim| J[persistQuickAddWaterOffline: SQLite + widget]
  I -->|não| K[Notificação: abrir app / tentar de novo]
```

---

## 3) Toque no “+” do **widget** Android (background)

Callback: `lib/core/home_widget_interactive.dart` (`@pragma('vm:entry-point')`).

> **Nota:** no código atual `fallbackGoal` inicia em `2000` se não houver `getSettings`; existe `UserGoalCache` (SharedPreferences) usado noutros fluxos — alinhar aqui evita meta errada offline só no widget.

```mermaid
flowchart TD
  A[Broadcast homeWidget addwater] --> B[homeWidgetInteractiveCallback]
  B --> C[Binding + plugins + env + JWT]
  C --> D{JWT válido?}
  D -->|não| Z[Log / fim]
  D -->|sim| E[fallbackGoal inicial - ver nota acima]
  E --> F{ConnectivityService.isConnected?}
  F -->|não| G[persistQuickAddWaterOffline]
  F -->|sim| H[SettingsService.getSettings]
  H --> I[WaterService.addWater]
  I -->|sucesso| J[getTodayData + notificação + WidgetService]
  I -->|erro| K{Falha de rede?}
  K -->|sim| G
  K -->|não| L[Notificação: erro API]
```

---

## 4) Home — carregar o dia (`HomeCubit.loadTodayData`)

```mermaid
flowchart TD
  A[loadTodayData] --> B[emit HomeLoading]
  B --> C{ConnectivityService.isConnected?}
  C -->|não| D[_emitOfflineFromCache SQLite]
  C -->|sim| E[WaterService.getTodayData]
  E -->|dados| F[_emitLoadedFromModel: HomeLoaded + cache + widget]
  E -->|null| G[HomeError]
  E -->|exceção| H[HomeError com mensagem]
```

---

## 5) Meia-noite — widget na launcher (`MidnightWidgetAlarm`)

```mermaid
flowchart TD
  A[AlarmManager dispara] --> B[midnightWidgetAlarmCallback]
  B --> C[Lê goal guardado no HomeWidget]
  C --> D[WidgetService: intake 0, progress 0, meta mantida]
  D --> E[Reagendar próxima 00h local]
  E --> F[Abrir app depois: API repõe totais reais]
```

---

## 6) Erro na UI — rede vs API (`network_error_heuristics`)

Usado em `alerts_view`, `history_view`, `settings_view` para não mostrar “sem Wi‑Fi” em todo erro.

```mermaid
flowchart TD
  A[Catch na chamada API] --> B[Estado de erro com message]
  B --> C[messageSuggestsNetworkFailure]
  C -->|sim| D[Ícone / texto orientados a rede]
  C -->|não| E[Ícone erro + texto da exceção]
```

---

## 7) Mapa de ficheiros (referência rápida)

| Área | Ficheiros principais |
|------|----------------------|
| Arranque + quick add notificação | `lib/main.dart` |
| Lembretes + ação + | `lib/core/services/notification_service.dart` |
| Widget “+” em background | `lib/core/home_widget_interactive.dart` |
| Offline quick add partilhado | `lib/core/services/quick_add_offline_persist.dart` |
| Meta em prefs (quando integrado) | `lib/data/local/user_goal_cache.dart` |
| Home online/offline | `lib/presentation/home/cubit/home_cubit.dart` |
| Ajustes | `lib/presentation/home/cubit/settings_cubit.dart` |
| Alarme meia-noite | `lib/core/services/midnight_widget_alarm.dart` |
| Manifest Android (alarme + widget) | `android/app/src/main/AndroidManifest.xml` |

---

*Última atualização: fluxos alinhados à estrutura atual do repositório bebeu.*
