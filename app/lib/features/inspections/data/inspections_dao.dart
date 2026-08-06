import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class InspectionsDao {
  const InspectionsDao(this._db);

  final AppDatabase _db;

  /// Stream reativo: a tela de histórico se atualiza sozinha quando a fila
  /// muda o status de qualquer registro.
  Stream<List<Inspection>> watchAll() {
    return (_db.select(_db.inspections)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
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
    return (_db.select(_db.inspections)
          ..where((t) => t.clientId.equals(clientId)))
        .getSingleOrNull();
  }

  /// Insere ou substitui — usado para gravar rascunho.
  Future<void> save(InspectionsCompanion entry) {
    return _db.into(_db.inspections).insertOnConflictUpdate(entry);
  }

  /// Atualiza apenas as colunas presentes no companion.
  Future<void> updateFields(String clientId, InspectionsCompanion changes) {
    return (_db.update(_db.inspections)
          ..where((t) => t.clientId.equals(clientId)))
        .write(changes);
  }

  /// A fila: apenas `pending` cujo backoff já venceu.
  ///
  /// `failed` fica de fora de propósito — é erro permanente e só volta à fila
  /// por ação explícita do usuário, que devolve o registro para `pending`.
  ///
  /// Ordena por `createdAt` para preservar a cronologia do trabalho de campo.
  Future<List<Inspection>> dueForSync(DateTime now) {
    return (_db.select(_db.inspections)
          ..where(
            (t) =>
                t.syncStatus.equalsValue(SyncStatus.pending) &
                (t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(now)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }
}
