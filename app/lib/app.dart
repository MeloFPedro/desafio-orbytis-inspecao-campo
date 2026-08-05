import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/user.dart';
import 'features/auth/presentation/auth_bloc.dart';
import 'features/auth/presentation/auth_event.dart';
import 'features/auth/presentation/auth_state.dart';
import 'features/auth/presentation/login_page.dart';

class InspecaoCampoApp extends StatelessWidget {
  const InspecaoCampoApp({
    required this.dio,
    required this.authRepository,
    required this.sessionExpired,
    super.key,
  });

  /// Mesma instância usada por todas as features — carrega o interceptor.
  final Dio dio;
  final AuthRepository authRepository;
  final Stream<void> sessionExpired;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: authRepository,
      child: BlocProvider(
        create: (_) => AuthBloc(authRepository, sessionExpired: sessionExpired)
          ..add(const AuthStatusChecked()),
        child: MaterialApp(
          title: 'Inspeção de Campo',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: Colors.indigo),
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

/// Decide a tela raiz a partir do estado de autenticação.
/// É o que atende ao requisito "bloquear rotas autenticadas sem token".
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => switch (state) {
        AuthInitial() => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        AuthLoading() || AuthUnauthenticated() => const LoginPage(),
        AuthAuthenticated(:final user) => _HomePlaceholder(user: user),
      },
    );
  }
}

/// Temporário — substituído pela lista de ordens de serviço no dia 2.
class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordens de serviço'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(user.name, style: Theme.of(context).textTheme.titleLarge),
            Text(user.email),
            Text(user.role),
          ],
        ),
      ),
    );
  }
}
