import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/error/failures.dart';
import '../../../core/media/photo_service.dart';
import '../../inspections/data/inspections_api.dart';
import '../../inspections/data/inspections_dao.dart';

/// Resultado de uma passada da fila.
class SyncResult {
  const SyncResult({
    this.synced = 0,
    this.failed = 0,
    this.retryScheduled = 0,
    this.skipped = false,
    this.sessionExpired = false,
  });

  final int synced;
  final int failed;
  final int retryScheduled;

  /// Já havia uma sincronização em curso.
  final bool skipped;

  /// A fila parou porque o token não vale mais.
  final bool sessionExpired;

  int get processed => synced + failed + retryScheduled;
}

/// Percorre a fila de inspeções `pending` e as envia à API.
///
/// Vive fora da árvore de widgets de propósito: a fila precisa rodar quando a
/// conexão volta, independentemente da tela em que o técnico esteja.
class SyncService {
  SyncService(this._api, this._dao, this._photoService);

  final InspectionsApi _api;
  final InspectionsDao _dao;
  final PhotoService _photoService;

  /// Espera inicial do backoff; dobra a cada tentativa.
  static const _baseDelay = Duration(seconds: 30);
  static const _maxDelay = Duration(hours: 1);

  /// Teto de tentativas. Sem ele, um erro transiente que nunca resolve
  /// retentaria indefinidamente.
  static const _maxAttempts = 5;

  /// Mutex. Botão manual e retorno de conectividade podem disparar juntos.
  bool _running = false;

  bool get isRunning => _running;

  Future<SyncResult> syncNow() async {
    // Retorna de imediato em vez de aguardar: enfileirar chamadas produziria
    // uma cascata de sincronizações quando a primeira terminasse.
    if (_running) return const SyncResult(skipped: true);
    _running = true;

    try {
      final due = await _dao.dueForSync(DateTime.now());

      var synced = 0;
      var failed = 0;
      var retried = 0;

      for (final inspection in due) {
        final outcome = await _send(inspection);

        switch (outcome) {
          case _Outcome.synced:
            synced++;
          case _Outcome.failed:
            failed++;
          case _Outcome.retry:
            retried++;
          case _Outcome.sessionExpired:
            // Interrompe a fila inteira: sem token válido as próximas
            // falhariam igual, e marcá-las como erro seria mentira.
            return SyncResult(
              synced: synced,
              failed: failed,
              retryScheduled: retried,
              sessionExpired: true,
            );
        }
      }

      return SyncResult(
        synced: synced,
        failed: failed,
        retryScheduled: retried,
      );
    } finally {
      _running = false;
    }
  }

  Future<_Outcome> _send(Inspection inspection) async {
    final photoPath = inspection.photoPath;
    final latitude = inspection.latitude;
    final longitude = inspection.longitude;
    final capturedAt = inspection.capturedAt;

    // Não deveria acontecer: a validação local barra antes de virar pending.
    if (photoPath == null ||
        latitude == null ||
        longitude == null ||
        capturedAt == null) {
      await _markFailed(inspection, 'Inspeção incompleta no dispositivo.');
      return _Outcome.failed;
    }

    final photo = File(_photoService.resolve(photoPath));
    if (!photo.existsSync()) {
      // Reenviar não vai trazer o arquivo de volta: erro permanente.
      await _markFailed(inspection, 'Arquivo da foto não encontrado.');
      return _Outcome.failed;
    }

    try {
      final result = await _api.create(
        clientId: inspection.clientId,
        workOrderId: inspection.workOrderId,
        observation: inspection.observation,
        condition: inspection.condition,
        latitude: latitude,
        longitude: longitude,
        capturedAt: capturedAt,
        photo: photo,
      );

      await _markSynced(inspection, result['id'] as String?);
      return _Outcome.synced;
    } on UnauthorizedFailure {
      // Sessão expirada não é falha da inspeção. Nada é marcado.
      return _Outcome.sessionExpired;
    } on Failure catch (failure) {
      if (failure.isPermanent) {
        await _markFailed(inspection, failure.message);
        return _Outcome.failed;
      }

      final attempts = inspection.retryCount + 1;
      if (attempts >= _maxAttempts) {
        await _markFailed(
          inspection,
          '${failure.message} (após $attempts tentativas)',
        );
        return _Outcome.failed;
      }

      await _scheduleRetry(inspection, attempts, failure.message);
      return _Outcome.retry;
    }
  }

  Future<void> _markSynced(Inspection inspection, String? serverId) {
    return _dao.updateFields(
      inspection.clientId,
      InspectionsCompanion(
        syncStatus: const Value(SyncStatus.synced),
        serverId: Value(serverId),
        lastError: const Value<String?>(null),
        nextAttemptAt: const Value<DateTime?>(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _markFailed(Inspection inspection, String message) {
    return _dao.updateFields(
      inspection.clientId,
      InspectionsCompanion(
        syncStatus: const Value(SyncStatus.failed),
        lastError: Value(message),
        nextAttemptAt: const Value<DateTime?>(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Continua `pending`, com a próxima tentativa adiada.
  ///
  /// O adiamento vive na linha, não num timer em memória: se o app for
  /// encerrado, a fila retoma exatamente de onde parou.
  Future<void> _scheduleRetry(
    Inspection inspection,
    int attempts,
    String message,
  ) {
    return _dao.updateFields(
      inspection.clientId,
      InspectionsCompanion(
        syncStatus: const Value(SyncStatus.pending),
        retryCount: Value(attempts),
        nextAttemptAt: Value(DateTime.now().add(_delayFor(attempts))),
        lastError: Value(message),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 30s, 1min, 2min, 4min — com teto de uma hora.
  Duration _delayFor(int attempts) {
    final seconds = _baseDelay.inSeconds * pow(2, attempts - 1);
    return Duration(seconds: min(seconds.toInt(), _maxDelay.inSeconds));
  }
}

enum _Outcome { synced, failed, retry, sessionExpired }
