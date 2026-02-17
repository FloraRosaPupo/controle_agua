
# 💧 BEBEU?

Aplicativo mobile para controle de consumo diário de água.

O **BEBEU?** ajuda o usuário a registrar a quantidade de água ingerida ao longo do dia, acompanhar o progresso em relação à meta diária, receber lembretes para se hidratar e visualizar o histórico dos últimos 7 dias.

Simples, direto e funcional. Se não bebeu… ele pergunta. 😅

---

## 📱 Funcionalidades

### ✅ Registro de Consumo
- Adicionar quantidade de água ingerida (em ml)
- Atualização automática do progresso diário
- Soma acumulada em tempo real

### 🎯 Meta Diária
- Definição de meta personalizada (ex: 2000 ml)
- Indicador visual de progresso (barra ou círculo)
- Feedback ao atingir 100% da meta

### 🔔 Notificações
- Lembretes periódicos para beber água
- Intervalo configurável
- Possibilidade de ativar/desativar notificações

### 📊 Histórico (Últimos 7 Dias)
- Visualização do consumo diário
- Comparação simples entre dias
- Exclusão automática de dados com mais de 7 dias

---

## 🧠 Regras de Negócio

- O consumo é contabilizado por dia.
- A cada novo dia, o contador é reiniciado.
- Apenas os últimos 7 dias ficam armazenados.
- Dados com mais de 7 dias são automaticamente removidos.
- A meta diária pode ser personalizada pelo usuário.

---

## 🗂 Estrutura Base do Projeto



lib/
├── models/
│    └── water_entry_model.dart
│
├── services/
│    ├── storage_service.dart
│    └── notification_service.dart
│
├── controllers/
│    └── water_controller.dart
│
├── screens/
│    ├── home_screen.dart
│    ├── history_screen.dart
│    └── settings_screen.dart
│
└── main.dart



---

## 🛠 Tecnologias Utilizadas

- Flutter
- Dart
- Armazenamento local (SharedPreferences ou SQLite)
- Notificações locais

---

## 📌 Objetivo do Projeto

Criar um aplicativo simples e eficiente para incentivar a hidratação diária, com foco em:

- Usabilidade
- Feedback visual claro
- Controle de dados limitado a 7 dias
- Experiência leve e objetiva

---

## 🚀 Melhorias Futuras

- Integração com smartwatch
- Estatísticas semanais e médias
- Sistema de conquistas
- Backup em nuvem

