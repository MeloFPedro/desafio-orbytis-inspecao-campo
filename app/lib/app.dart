import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_bloc.dart';
import 'features/auth/presentation/auth_event.dart';
import 'features/auth/presentation/auth_state.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/inspections/data/inspections_repository.dart';
import 'features/work_orders/data/work_orders_repository.dart';
import 'features/work_orders/presentation/work_orders_bloc.dart';
import 'features/work_orders/presentation/work_orders_event.dart';
import 'features/work_orders/presentation/work_orders_page.dart';

class InspecaoCampoApp extends StatelessWidget {
  const InspecaoCampoApp({
    required this.authRepository,
    required this.workOrdersRepository,
    required this.inspectionsRepository,
    required this.sessionExpired,
    super.key,
  });

  final AuthRepository authRepository;
  final WorkOrdersRepository workOrdersRepository;
  final InspectionsRepository inspectionsRepository;
  final Stream<void> sessionExpired;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: workOrdersRepository),
        // Acima do MaterialApp de propósito: telas abertas por Navigator.push
        // nascem sob o Navigator e só enxergam providers acima dele.
        RepositoryProvider.value(value: inspectionsRepository),
      ],
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
        // O bloc nasce aqui dentro: é fechado no logout, junto com os dados
        // da sessão anterior.
        AuthAuthenticated() => BlocProvider(
            create: (context) =>
                WorkOrdersBloc(context.read<WorkOrdersRepository>())
                  ..add(const WorkOrdersRequested()),
            child: const WorkOrdersPage(),
          ),
      },
    );
  }
}
