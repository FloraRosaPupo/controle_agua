# 💧 bebeu?

Aplicativo mobile para controle de consumo diário de água.

O **bebeu?** ajuda o usuário a registrar a quantidade de água ingerida ao longo do dia, acompanhar o progresso em relação à meta diária, receber lembretes para se hidratar e visualizar o histórico dos últimos 7 dias.

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

`lib/features/auth` e `lib/features/hydration` agrupam cada funcionalidade; `lib/core` contém integrações compartilhadas. `backend` e `supabase/functions` são implementações de servidor.

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



## Desenvolvimento e validação

O aplicativo está em `.`. Use Flutter 3.41.1. Na pasta do aplicativo, execute:

```sh
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter run
```

A CI valida análise e testes em pushes e pull requests. Serviços externos precisam de configuração própria.


### Backend

Em `backend`, copie `.env.example` para `.env` e configure PostgreSQL e um segredo JWT próprio. Execute `npm ci`, `npm run build`, `npm test` e `npm run dev` (tsx). Para produção, `npm start` usa a saída gerada em `dist`. O esquema está em `backend/prisma/schema.prisma`; aplique as migrações existentes ao seu banco conforme o ambiente.

O arquivo `.env` antigo foi removido do versionamento, mas permanece no histórico: rotacione as credenciais que estavam nele. Não reutilize os exemplos como segredos reais.


### Testes visuais

As referências em `test/goldens` correspondem às telas atuais, estado carregado com intervalo de 120 minutos, dias úteis e notificações ativadas, em Flutter 3.41.1 no Windows. A CI Flutter usa Windows para evitar diferenças de rasterização entre sistemas. As imagens anteriores representavam layouts antigos. As novas imagens foram comparadas visualmente antes da atualização. Não atualize referências automaticamente na CI; revise cada diferença antes de aceitar um novo baseline. Os blocos de texto nas imagens são a fonte Ahem padrão dos testes Flutter.


## Licença

Não há licença de distribuição definida neste repositório. Os direitos de terceiros e as atribuições existentes devem ser respeitados; esta revisão não concede permissão de redistribuição.


## Organização e manutenção

Auth e hidratação reúnem apresentação, dados e modelos em features; integrações compartilhadas permanecem em core. Cubits coordenam estado; serviços tratam dados. O backend separa rotas, autenticação e handlers, e a projeção pública do usuário remove hashes de senha.

Veja [a revisão de desenvolvimento](docs/REVISAO.md) para decisões, testes e limites, e [o guia de contribuição](CONTRIBUTING.md) para o fluxo de manutenção.
