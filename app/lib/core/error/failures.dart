import 'package:equatable/equatable.dart';

/// Erro de domínio: algo que a UI pode exibir e a fila de sync pode classificar.
abstract class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  /// Erro permanente: reenviar o mesmo payload produz o mesmo resultado.
  /// Erro transiente: vale retentar mais tarde.
  bool get isPermanent;

  @override
  List<Object?> get props => [message];
}

/// Sem conexão, DNS, timeout, servidor fora do ar.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sem conexão com o servidor.']);

  @override
  bool get isPermanent => false;
}

/// 5xx — o servidor falhou, mas o payload pode estar correto.
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erro no servidor. Tente novamente.']);

  @override
  bool get isPermanent => false;
}

/// 401 — credenciais inválidas no login, ou token expirado nas rotas protegidas.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Credenciais inválidas.']);

  @override
  bool get isPermanent => true;
}

/// 400 — o payload está errado. Reenviar igual não adianta.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.errors = const {}});

  /// Mapa campo -> mensagens, como a API devolve em `errors`.
  final Map<String, List<String>> errors;

  @override
  bool get isPermanent => true;

  @override
  List<Object?> get props => [message, errors];
}

/// 409 — workOrderId inexistente no servidor.
class ConflictFailure extends Failure {
  const ConflictFailure([super.message = 'Registro em conflito no servidor.']);

  @override
  bool get isPermanent => true;
}

/// Qualquer coisa não prevista.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Ocorreu um erro inesperado.']);

  @override
  bool get isPermanent => false;
}