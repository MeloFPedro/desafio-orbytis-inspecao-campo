import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Ciclo de vida de uma inspeção no dispositivo.
enum SyncStatus {
  /// Rascunho: incompleto, nunca vai para a API.
  draft,

  /// Pronta e aguardando envio.
  pending,

  /// Aceita pelo servidor.
  synced,

  /// Rejeitada por erro permanente.
  failed,
}

extension SyncStatusLabel on SyncStatus {
  String get label => switch (this) {
    SyncStatus.draft => 'Rascunho',
    SyncStatus.pending => 'Pendente',
    SyncStatus.synced => 'Sincronizada',
    SyncStatus.failed => 'Falhou',
  };
}

class Inspections extends Table {
  /// UUID gerado no dispositivo. É a chave de idempotência do contrato:
  /// reenvios usam o mesmo valor e o servidor não duplica.
  TextColumn get clientId => text()();

  TextColumn get workOrderId => text()();

  TextColumn get observation => text().withDefault(const Constant(''))();
  TextColumn get condition => text().nullable()();

  /// Caminho *relativo* ao diretório de documentos do app.
  /// Absoluto quebraria entre reinstalações, quando o container muda.
  TextColumn get photoPath => text().nullable()();

  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  /// Momento da coleta no dispositivo, preenchido ao concluir.
  DateTimeColumn get capturedAt => dateTime().nullable()();

  TextColumn get syncStatus => textEnum<SyncStatus>()();

  /// `id` devolvido pelo servidor após sincronizar.
  TextColumn get serverId => text().nullable()();

  /// Mensagem legível da última falha, exibida no histórico.
  TextColumn get lastError => text().nullable()();

  /// Estado do backoff — persistido para sobreviver ao fechamento do app.
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Campos anuláveis não são descuido: um rascunho é legitimamente
  /// incompleto. A validação acontece na transição para `pending`, não aqui.
  @override
  Set<Column> get primaryKey => {clientId};
}

@DriftDatabase(tables: [Inspections])
class AppDatabase extends _$AppDatabase {
  /// Sem argumento, abre o arquivo real no diretório do app.
  /// Testes passam `NativeDatabase.memory()`.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'inspecao_campo'));

  @override
  int get schemaVersion => 1;
}
