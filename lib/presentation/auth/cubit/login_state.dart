abstract class LoginState {}  

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {}

class LoginFailure extends LoginState {
  final String error;
  LoginFailure(this.error); // this.error é usado para capturar o erro, é o retorno da estado
}
