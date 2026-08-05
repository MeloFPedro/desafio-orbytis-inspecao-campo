import 'package:equatable/equatable.dart';

import '../domain/user.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Ainda não sabemos — estado da primeira fração de segundo.
class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.errorMessage});

  /// Preenchido quando a tentativa anterior falhou.
  final String? errorMessage;

  @override
  List<Object?> get props => [errorMessage];
}
