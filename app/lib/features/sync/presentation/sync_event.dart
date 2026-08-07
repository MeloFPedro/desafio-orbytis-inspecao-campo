import 'package:equatable/equatable.dart';

sealed class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

/// Técnico apertou o botão. Produz retorno visual.
class SyncRequested extends SyncEvent {
  const SyncRequested();
}

/// A tela de histórico abriu. Silencioso e respeita o backoff.
class SyncAutoTriggered extends SyncEvent {
  const SyncAutoTriggered();
}

/// Conectividade voltou. Silencioso, mas **ignora o backoff**.
///
/// O adiamento foi calculado sob a premissa de que a rede estava ruim, e uma
/// interface voltando é informação nova que invalida essa premissa. A proteção
/// não se perde: se o servidor estiver fora do ar com a rede de pé, nenhum
/// evento de conectividade é emitido e o backoff segue valendo.
class SyncConnectivityRestored extends SyncEvent {
  const SyncConnectivityRestored();
}

/// Usuário autenticou. Silencioso e ignora o backoff.
///
/// Cobre o caso de sessão expirada: as inspeções que ficaram em espera por
/// falta de token sobem assim que o técnico entra de novo, sem que ele
/// precise procurar o botão de sincronizar.
class SyncSessionStarted extends SyncEvent {
  const SyncSessionStarted();
}
