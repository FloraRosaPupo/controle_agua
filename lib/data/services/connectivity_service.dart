import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final _connectivity = Connectivity();

  //stream ele serve pra monitorar a conexão em segundo plano e disparar eventos quando a conexão muda
  static Stream<List<ConnectivityResult>>
  get onConnectivityChanged => //pega o stream de conexão
      _connectivity.onConnectivityChanged;

  static Future<bool> isConnected() async {
    final results = await _connectivity
        .checkConnectivity(); //verifica a conexão
    return !results.contains(
      ConnectivityResult.none,
    ); //se não estiver conectado, retorna false
  }
}
