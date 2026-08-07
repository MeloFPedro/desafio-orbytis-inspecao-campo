import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/sync_service.dart';
import 'sync_event.dart';
import 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  SyncBloc(
    this._service, {
    Stream<List<ConnectivityResult>>? connectivity,
    Duration tickInterval = const Duration(minutes: 1),
  }) : super(const SyncState()) {
    on<SyncRequested>((event, emit) => _run(emit, manual: true));
    on<SyncAutoTriggered>((event, emit) => _run(emit));
    on<SyncConnectivityRestored>((event, emit) => _run(emit, force: true));
    on<SyncSessionStarted>((event, emit) => _run(emit, force: true));

    _connectivitySubscription = connectivity?.listen((results) {
      final hasNetwork =
          results.any((result) => result != ConnectivityResult.none);

      // Gatilho, não garantia: "tem Wi-Fi" não é "tem internet". Se a
      // tentativa falhar, o backoff cuida do resto.
      if (hasNetwork) add(const SyncConnectivityRestored());
    });

    // Sem isto, `nextAttemptAt` seria respeitado mas nunca executado: o
    // adiamento só valeria se outro gatilho aparecesse por acaso depois dele.
    // O tique não força o backoff — apenas dá a ele a chance de vencer.
    _ticker = Timer.periodic(
      tickInterval,
      (_) => add(const SyncAutoTriggered()),
    );
  }

  final SyncService _service;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _ticker;

  /// [manual] governa o retorno visual; [force] governa o backoff. São eixos
  /// independentes: a execução por conectividade força, mas é silenciosa.
  Future<void> _run(
    Emitter<SyncState> emit, {
    bool manual = false,
    bool force = false,
  }) async {
    emit(state.copyWith(isRunning: true));

    // A proteção real contra execução dupla é o mutex do serviço: se já
    // houver uma passada em curso, esta volta com skipped.
    final result = await _service.syncNow(force: force || manual);

    emit(SyncState(lastResult: result, lastRunWasManual: manual));
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    _ticker?.cancel();
    return super.close();
  }
}
