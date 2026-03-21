import 'package:flutter/material.dart';
import './notification_settings_view.dart';

class AlertsView extends StatelessWidget {
  const AlertsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final alerts = [
      {
        "title": "Quase lá!",
        "message": "Falta muito pouco! Apenas 300ml para atingir sua meta.",
        "icon": Icons.battery_charging_full_rounded,
        "color": Colors.orange,
      },
      {
        "title": "Bebeu água hoje?",
        "message": "Bom dia! Ainda não registrou nenhuma água hoje. Que tal começar?",
        "icon": Icons.wb_sunny_rounded,
        "color": Colors.yellow.shade700,
      },
      {
        "title": "Ritmo Lento",
        "message": "Seu ritmo está um pouco lento hoje. Vamos hidratar?",
        "icon": Icons.trending_down_rounded,
        "color": Colors.redAccent,
      },
      {
        "title": "Meta Atingida!",
        "message": "Parabéns! Você atingiu sua meta diária de 2500ml.",
        "icon": Icons.emoji_events_rounded,
        "color": Colors.green,
      },
      {
        "title": "Lembrete de Hidratação",
        "message": "Hora de beber água! Mantenha seu corpo hidratado.",
        "icon": Icons.notifications_active_rounded,
        "color": colors.primary,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            floating: true,
            title: Text(
              "Meus Alertas",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationSettingsView(),
                    ),
                  );
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.settings_outlined, color: colors.primary),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final alert = alerts[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.onSurface.withValues(alpha: 0.05),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (alert["color"] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            alert["icon"] as IconData,
                            color: alert["color"] as Color,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert["title"] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                alert["message"] as String,
                                style: TextStyle(
                                  color: colors.onSurface.withValues(alpha: 0.6),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                childCount: alerts.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
