import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/location/location_service.dart';
import 'core/media/photo_service.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_bloc.dart';
import 'features/auth/presentation/auth_event.dart';
import 'features/auth/presentation/auth_state.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/inspections/data/inspections_repository.dart';
import 'features/sync/data/sync_service.dart';
import 'features/sync/presentation/sync_bloc.dart';
import 'features/sync/presentation/sync_event.dart';
import 'features/work_orders/data/work_orders_repository.dart';
import 'features/work_orders/presentation/work_orders_bloc.dart';
import 'features/work_orders/presentation/work_orders_event.dart';
import 'features/work_orders/presentation/work_orders_page.dart';

/// Necessário para desempilhar rotas de fora da árvore do Navigator.
final _navigatorKey = GlobalKey<NavigatorState>();

class InspecaoCampoApp extends StatelessWidget {
  const InspecaoCampoApp({
    required this.authRepository,
    required this.workOrdersRepository,
    required this.inspectionsRepository,
    required this.photoService,
    required this.locationService,
    required this.syncService,
    required this.connectivity,
    required this.sessionExpired,
    super.key,
  });

  final AuthRepository authRepository;
  final WorkOrdersRepository workOrdersRepository;
  final InspectionsRepository inspectionsRepository;
  final PhotoService photoService;
  final LocationService locationService;
  final SyncService syncService;
  final Stream<List<ConnectivityResult>> connectivity;
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
        RepositoryProvider.value(value: photoService),
        RepositoryProvider.value(value: locationService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                AuthBloc(authRepository, sessionExpired: sessionExpired)
                  ..add(const AuthStatusChecked()),
          ),
          // Na raiz, e não no ramo autenticado: o ouvinte de conectividade
          // precisa continuar vivo enquanto o app estiver aberto, senão a
          // fila deixaria de reagir ao retorno da rede.
          BlocProvider(
            create: (_) => SyncBloc(syncService, connectivity: connectivity),
          ),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            switch (state) {
              // Ao cair a sessão, desempilha tudo. Sem isto, o _AuthGate troca
              // o conteúdo da rota raiz mas as telas abertas por
              // Navigator.push permanecem por cima — o técnico veria o
              // histórico sobre um login.
              case AuthUnauthenticated():
                _navigatorKey.currentState?.popUntil((route) => route.isFirst);

              // Entrar é sinal novo, do mesmo tipo que a rede voltando: as
              // inspeções que esperavam por token sobem sozinhas.
              case AuthAuthenticated():
                context.read<SyncBloc>().add(const SyncSessionStarted());

              case _:
                break;
            }
          },
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Inspeção de Campo',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(colorSchemeSeed: Colors.indigo),
            home: const _AuthGate(),
          ),
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
