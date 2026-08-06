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

/// Conectividade voltou ou a tela abriu. Silencioso.
class SyncAutoTriggered extends SyncEvent {
  const SyncAutoTriggered();
}
