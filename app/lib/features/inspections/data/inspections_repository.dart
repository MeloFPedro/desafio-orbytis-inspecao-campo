import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/error/failures.dart';
import 'inspections_dao.dart';

class InspectionsRepository {
  const InspectionsRepository(this._dao, [this._uuid = const Uuid()]);

  final InspectionsDao _dao;
  final Uuid _uuid;

  Stream<List<Inspection>> watchAll() => _dao.watchAll();

  Stream<List<Inspection>> watchByStatus(SyncStatus status) =>
      _dao.watchByStatus(status);

  Stream<List<Inspection>> watchByWorkOrder(String workOrderId) =>
      _dao.watchByWorkOrder(workOrderId);

  Future<Inspection?> findByClientId(String clientId) =>
      _dao.findByClientId(clientId);

  Future<Inspection?> findDraftForWorkOrder(String workOrderId) =>
      _dao.findDraftForWorkOrder(workOrderId);

  /// Cria ou atualiza um rascunho. Devolve o `clientId`.
  ///
  /// Rascunho não valida nada: o técnico pode salvar o que tiver e voltar
  /// depois. Rascunhos nunca vão para a API.
  Future<String> saveDraft({
    required String workOrderId,
    required String observation,
    String? clientId,
    String? condition,
    String? photoPath,
    double? latitude,
    double? longitude,
  }) async {
    final now = DateTime.now();
    final id = clientId ?? _uuid.v4();

    final existing = clientId == null ? null : await _dao.findByClientId(id);

    await _dao.save(
      InspectionsCompanion(
        clientId: Value(id),
        workOrderId: Value(workOrderId),
        observation: Value(observation),
        condition: Value(condition),
        photoPath: Value(photoPath),
        latitude: Value(latitude),
        longitude: Value(longitude),
        syncStatus: const Value(SyncStatus.draft),
        createdAt: Value(existing?.createdAt ?? now),
        updatedAt: Value(now),
      ),
    );

    return id;
  }

  /// Devolve uma inspeção `failed` para a fila.
  ///
  /// Zera o contador de tentativas: é uma nova decisão do técnico, não a
  /// continuação da sequência anterior de falhas.
  Future<void> retry(String clientId) {
    return _dao.updateFields(
      clientId,
      InspectionsCompanion(
        syncStatus: const Value(SyncStatus.pending),
        retryCount: const Value(0),
        nextAttemptAt: const Value<DateTime?>(null),
        lastError: const Value<String?>(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Marca a inspeção como pronta para envio.
  ///
  /// Lança [ValidationFailure] se estiver incompleta — as mesmas regras que a
  /// API aplicaria, verificadas antes de a inspeção entrar na fila. Assim o
  /// técnico descobre o problema com o ativo ainda na frente dele, e não
  /// horas depois, quando recuperar o sinal.
  Future<void> complete(String clientId) async {
    final inspection = await _dao.findByClientId(clientId);
    if (inspection == null) {
      throw const NotFoundFailure('Inspeção não encontrada.');
    }

    final errors = <String, List<String>>{};

    if (inspection.observation.trim().length < 10) {
      errors['observation'] = ['mínimo de 10 caracteres'];
    }
    if (inspection.photoPath == null) {
      errors['photo'] = ['foto obrigatória'];
    }
    if (inspection.latitude == null || inspection.longitude == null) {
      errors['location'] = ['localização obrigatória'];
    }

    if (errors.isNotEmpty) {
      throw ValidationFailure('Inspeção incompleta.', errors: errors);
    }

    final now = DateTime.now();
    await _dao.updateFields(
      clientId,
      InspectionsCompanion(
        syncStatus: const Value(SyncStatus.pending),
        capturedAt: Value(inspection.capturedAt ?? now),
        // Entra na fila limpa, mesmo vindo de uma falha anterior.
        lastError: const Value<String?>(null),
        retryCount: const Value(0),
        nextAttemptAt: const Value<DateTime?>(null),
        updatedAt: Value(now),
      ),
    );
  }
}
