/// Indica se o texto de um erro **parece** falha de rede/transporte (DNS, socket, timeout).
///
/// Usa palavras-chave típicas das stacks Dart/HTTP em inglês — não traduzir esses
/// trechos, senão deixa de reconhecer as exceções reais.
bool messageSuggestsNetworkFailure(String message) {
  final m = message.toLowerCase();
  return m.contains('socketexception') || // falha de socket
      m.contains('clientexception') || // cliente HTTP (ex.: Dio/http)
      m.contains('failed host lookup') || // DNS não resolveu
      m.contains('network') || // mensagens genéricas com "network"
      m.contains('connection refused') || // porta fechada / serviço indisponível
      m.contains('connection reset') || // ligação cortada
      m.contains('connection timed out') || // TCP expirou
      m.contains('timed out') ||
      m.contains('timeout') || // expiração de pedido
      m.contains('sem internet') || // texto em PT que possamos lançar no app
      m.contains('no address associated') || // host sem IP
      m.contains('unreachable'); // rede/rota inacessível
}
