import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_service.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthService _authService;

  LoginCubit(this._authService)
    : super(
        LoginInitial(),
      ); //padrao do cubit é LoginInitial, é o estado inicial da aplicação
  // super é usado para chamar o construtor da classe pai

  Future<void> login(String email, String password) async {
    emit(LoginLoading()); // emit é usado para atualizar o estado da aplicação
    try {
      await _authService.login(email, password);
      // Aqui o token já está salvo localmente
      emit(LoginSuccess());
    } catch (e) {
      //e é usado para capturar o erro, é o retorno da estado
      emit(LoginFailure(e.toString().replaceAll("Exception: ", "")));
    }
  }
}
