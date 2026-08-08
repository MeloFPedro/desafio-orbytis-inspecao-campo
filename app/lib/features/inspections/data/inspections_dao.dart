import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class InspectionsDao {
  const InspectionsDao(this._db);

  final AppDatabase _db;

  /// Stream reativo: a tela de histórico se atualiza sozinha quando a fila
  /// muda o status de qualquer registro.
  Stream<List<Inspection>> watchAll() {
    return (_db.select(
      _db.inspections,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  }

  Stream<List<Inspection>> watchByStatus(SyncStatus status) {
    return (_db.select(_db.inspections)
          ..where((t) => t.syncStatus.equalsValue(status))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Stream<List<Inspection>> watchByWorkOrder(String workOrderId) {
    return (_db.select(_db.inspections)
          ..where((t) => t.workOrderId.equals(workOrderId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<Inspection?> findByClientId(String clientId) {
    return (_db.select(
      _db.inspections,
    )..where((t) => t.clientId.equals(clientId))).getSingleOrNull();
  }

  /// Rascunho aberto de uma OS, se houver. O técnico retoma de onde parou
  /// em vez de criar uma inspeção nova a cada visita à tela.
  Future<Inspection?> findDraftForWorkOrder(String workOrderId) {
    return (_db.select(_db.inspections)
          ..where(
            (t) =>
                t.workOrderId.equals(workOrderId) &
                t.syncStatus.equalsValue(SyncStatus.draft),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Estado local mais relevante por ordem de serviço.
  ///
  /// Quando há mais de uma inspeção para a mesma OS, prevalece a que exige
  /// atenção — o técnico precisa ver a que falhou, não a que já subiu.
  ///
  /// A agregação fica em Dart e não em SQL: um GROUP BY com ordenação
  /// customizada por prioridade de status seria bem mais difícil de ler, e a
  /// tabela tem dezenas de linhas, não centenas de milhares.
  Stream<Map<String, SyncStatus>> watchStatusByWorkOrder() {
    return _db.select(_db.inspections).watch().map((rows) {
      final result = <String, SyncStatus>{};

      for (final row in rows) {
        final current = result[row.workOrderId];
        if (current == null ||
            _attentionRank(row.syncStatus) > _attentionRank(current)) {
          result[row.workOrderId] = row.syncStatus;
        }
      }

      return result;
    });
  }

  int _attentionRank(SyncStatus status) => switch (status) {
    SyncStatus.synced => 0,
    SyncStatus.draft => 1,
    SyncStatus.pending => 2,
    SyncStatus.failed => 3,
  };

  /// Insere ou substitui — usado para gravar rascunho.
  Future<void> save(InspectionsCompanion entry) {
    return _db.into(_db.inspections).insertOnConflictUpdate(entry);
  }

  /// Atualiza apenas as colunas presentes no companion.
  Future<void> updateFields(String clientId, InspectionsCompanion changes) {
    return (_db.update(
      _db.inspections,
    )..where((t) => t.clientId.equals(clientId))).write(changes);
  }

  /// A fila: apenas `pending` cujo backoff já venceu.
  ///
  /// `failed` fica de fora de propósito — é erro permanente e só volta à fila
  /// por ação explícita do usuário, que devolve o registro para `pending`.
  ///
  /// [ignoreBackoff] é usado pela sincronização manual: o adiamento existe
  /// para conter a fila automática, não para bloquear uma decisão do usuário.
  ///
  /// Ordena por `createdAt` para preservar a cronologia do trabalho de campo.
  Future<List<Inspection>> dueForSync(
    DateTime now, {
    bool ignoreBackoff = false,
  }) {
    return (_db.select(_db.inspections)
          ..where((t) {
            final isPending = t.syncStatus.equalsValue(SyncStatus.pending);
            if (ignoreBackoff) return isPending;

            return isPending &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(now));
          })
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }
}
