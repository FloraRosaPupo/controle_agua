import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/auth_service.dart';
import 'register_state.dart';

class RegisterCubit extends Cubit<RegisterState> {
  final AuthService _authService;

  RegisterCubit(this._authService) : super(RegisterInitial());

  Future<void> registerAndLogin(
    String name,
    String email,
    String password,
    double dailyGoal,
  ) async {
    emit(RegisterLoading());
    try {
      await _authService.register(name, email, password, dailyGoal);
      // Aqui, se deu certo, o usuário foi cadastrado e logado.
      emit(RegisterSuccess());
    } catch (e) {
      emit(RegisterFailure(e.toString().replaceAll("Exception: ", "")));
    }
  }
}
