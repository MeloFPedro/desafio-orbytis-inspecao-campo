import 'package:equatable/equatable.dart';

import '../data/sync_service.dart';

class SyncState extends Equatable {
  const SyncState({
    this.isRunning = false,
    this.lastResult,
    this.lastRunWasManual = false,
  });

  final bool isRunning;
  final SyncResult? lastResult;

  /// Só execuções manuais geram mensagem na tela — uma sincronização
  /// automática que não achou nada não deveria interromper o técnico.
  final bool lastRunWasManual;

  SyncState copyWith({
    bool? isRunning,
    SyncResult? lastResult,
    bool? lastRunWasManual,
  }) {
    return SyncState(
      isRunning: isRunning ?? this.isRunning,
      lastResult: lastResult ?? this.lastResult,
      lastRunWasManual: lastRunWasManual ?? this.lastRunWasManual,
    );
  }

  @override
  List<Object?> get props => [isRunning, lastResult, lastRunWasManual];
}
