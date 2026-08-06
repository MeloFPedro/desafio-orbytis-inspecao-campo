import 'dart:async';

import 'package:equatable/equatable.dart';

sealed class WorkOrdersEvent extends Equatable {
  const WorkOrdersEvent();

  @override
  List<Object?> get props => [];
}

/// Carga inicial: mostra spinner de tela cheia.
class WorkOrdersRequested extends WorkOrdersEvent {
  const WorkOrdersRequested();
}

/// Pull-to-refresh: mantém a lista atual visível.
class WorkOrdersRefreshed extends WorkOrdersEvent {
  const WorkOrdersRefreshed({this.completer});

  /// Completado quando a atualização termina, com ou sem sucesso.
  ///
  /// O RefreshIndicator precisa saber quando a *operação* acabou, e isso não é
  /// o mesmo que "o estado mudou": um refresh que traz dados idênticos não
  /// produz emissão nenhuma, porque o bloc descarta estados iguais.
  final Completer<void>? completer;

  @override
  List<Object?> get props => [completer];
}
