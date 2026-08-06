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
  }) : super(const SyncState()) {
    on<SyncRequested>((event, emit) => _run(emit, manual: true));
    on<SyncAutoTriggered>((event, emit) => _run(emit, manual: false));

    _connectivitySubscription = connectivity?.listen((results) {
      final hasNetwork =
          results.any((result) => result != ConnectivityResult.none);

      // Gatilho, não garantia: "tem Wi-Fi" não é "tem internet". Se a
      // tentativa falhar, o backoff cuida do resto.
      if (hasNetwork) add(const SyncAutoTriggered());
    });
  }

  final SyncService _service;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<void> _run(Emitter<SyncState> emit, {required bool manual}) async {
    emit(state.copyWith(isRunning: true));

    // A proteção real contra execução dupla é o mutex do serviço: se já
    // houver uma passada em curso, esta volta com skipped.
    final result = await _service.syncNow();

    emit(SyncState(lastResult: result, lastRunWasManual: manual));
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
