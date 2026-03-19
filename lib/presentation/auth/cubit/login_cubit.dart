import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/auth_service.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  final AuthService _authService;

  LoginCubit(this._authService) : super(LoginInitial());

  Future<void> login(String email, String password) async {
    emit(LoginLoading());
    try {
      await _authService.login(email, password);
      // Aqui o token já está salvo localmente
      emit(LoginSuccess());
    } catch (e) {
      emit(LoginFailure(e.toString().replaceAll("Exception: ", "")));
    }
  }
}
