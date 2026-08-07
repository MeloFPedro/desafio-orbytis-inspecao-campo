import 'dart:async';
import 'dart:io';

// Sem importar drift: ele exporta um `isNull` para consultas SQL que colide
// com o `isNull` do matcher. InspectionsCompanion vem do app_database.
import 'package:flutter_test/flutter_test.dart';
import 'package:inspecao_campo/core/database/app_database.dart';
import 'package:inspecao_campo/core/error/failures.dart';
import 'package:inspecao_campo/core/media/photo_service.dart';
import 'package:inspecao_campo/features/inspections/data/inspections_api.dart';
import 'package:inspecao_campo/features/inspections/data/inspections_dao.dart';
import 'package:inspecao_campo/features/sync/data/sync_service.dart';

void main() {
  late Directory tempDir;
  late _FakeApi api;
  late _FakeDao dao;
  late _FakePhotoService photos;
  late SyncService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('inspecoes_test');
    // A foto precisa existir de fato: o serviço checa antes de enviar.
    File('${tempDir.path}/foto.jpg').writeAsBytesSync([0, 1, 2]);

    api = _FakeApi();
    dao = _FakeDao();
    photos = _FakePhotoService(tempDir.path);
    service = SyncService(api, dao, photos);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('sucesso marca synced, guarda o serverId e conta a tentativa', () async {
    dao.queue = [_inspection()];
    api.response = {'id': 'insp_9001'};

    final result = await service.syncNow();

    expect(result.synced, 1);
    expect(dao.lastUpdate!.syncStatus.value, SyncStatus.synced);
    expect(dao.lastUpdate!.serverId.value, 'insp_9001');
    expect(dao.lastUpdate!.retryCount.value, 1);
    expect(dao.lastUpdate!.lastError.value, isNull);
  });

  test('erro permanente vai para failed sem reagendar', () async {
    dao.queue = [_inspection()];
    api.error = const ValidationFailure('Payload inválido');

    final result = await service.syncNow();

    expect(result.failed, 1);
    expect(dao.lastUpdate!.syncStatus.value, SyncStatus.failed);
    expect(dao.lastUpdate!.lastError.value, 'Payload inválido');
    expect(dao.lastUpdate!.nextAttemptAt.value, isNull);
  });

  test('erro transiente continua pending e agenda nova tentativa', () async {
    dao.queue = [_inspection()];
    api.error = const NetworkFailure('Sem conexão');

    final result = await service.syncNow();

    expect(result.retryScheduled, 1);
    expect(dao.lastUpdate!.syncStatus.value, SyncStatus.pending);
    expect(dao.lastUpdate!.retryCount.value, 1);
    expect(
      dao.lastUpdate!.nextAttemptAt.value!.isAfter(DateTime.now()),
      isTrue,
    );
  });

  test('401 interrompe a fila sem marcar nada', () async {
    dao.queue = [_inspection(clientId: 'a'), _inspection(clientId: 'b')];
    api.error = const UnauthorizedFailure();

    final result = await service.syncNow();

    expect(result.sessionExpired, isTrue);
    expect(dao.lastUpdate, isNull, reason: 'nenhuma inspeção foi alterada');
    expect(api.calls, 1, reason: 'a segunda nem chegou a ser tentada');
  });

  test('teto de tentativas transforma transiente em failed', () async {
    dao.queue = [_inspection(retryCount: 4)];
    api.error = const NetworkFailure('Sem conexão');

    final result = await service.syncNow();

    expect(result.failed, 1);
    expect(dao.lastUpdate!.syncStatus.value, SyncStatus.failed);
    expect(dao.lastUpdate!.retryCount.value, 5);
    expect(dao.lastUpdate!.lastError.value, contains('5 tentativas'));
  });

  test('reenvio reutiliza o mesmo clientId', () async {
    dao.queue = [_inspection(clientId: 'uuid-fixo', retryCount: 2)];
    api.response = {'id': 'insp_9002'};

    await service.syncNow();

    expect(api.lastClientId, 'uuid-fixo');
  });

  test('foto ausente no dispositivo é erro permanente', () async {
    dao.queue = [_inspection(photoPath: 'nao-existe.jpg')];

    final result = await service.syncNow();

    expect(result.failed, 1);
    expect(dao.lastUpdate!.syncStatus.value, SyncStatus.failed);
    expect(api.calls, 0, reason: 'nem tentou enviar');
  });

  test('chamada concorrente é descartada pelo mutex', () async {
    dao.queue = [_inspection()];
    api.response = {'id': 'insp_9003'};
    api.gate = Completer<void>();

    final first = service.syncNow();
    final second = await service.syncNow();

    expect(second.skipped, isTrue);

    api.gate!.complete();
    await first;
  });
}

Inspection _inspection({
  String clientId = 'uuid-1',
  String photoPath = 'foto.jpg',
  int retryCount = 0,
}) {
  final now = DateTime(2026, 8, 10, 9);

  return Inspection(
    clientId: clientId,
    workOrderId: 'wo_1001',
    observation: 'Poste com oxidação na base.',
    condition: 'regular',
    photoPath: photoPath,
    latitude: -7.1195,
    longitude: -34.8450,
    capturedAt: now,
    syncStatus: SyncStatus.pending,
    retryCount: retryCount,
    createdAt: now,
    updatedAt: now,
  );
}

/// Dublês parciais: `noSuchMethod` permite implementar só o que é usado, e
/// qualquer chamada inesperada estoura em vez de devolver silêncio.
class _FakeApi implements InspectionsApi {
  Map<String, dynamic>? response;
  Failure? error;
  Completer<void>? gate;

  int calls = 0;
  String? lastClientId;

  @override
  Future<Map<String, dynamic>> create({
    required String clientId,
    required String workOrderId,
    required String observation,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
    required File photo,
    String? condition,
  }) async {
    calls++;
    lastClientId = clientId;

    if (gate != null) await gate!.future;
    if (error != null) throw error!;

    return response!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeDao implements InspectionsDao {
  List<Inspection> queue = [];
  InspectionsCompanion? lastUpdate;

  @override
  Future<List<Inspection>> dueForSync(
    DateTime now, {
    bool ignoreBackoff = false,
  }) async =>
      queue;

  @override
  Future<void> updateFields(
    String clientId,
    InspectionsCompanion changes,
  ) async {
    lastUpdate = changes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakePhotoService implements PhotoService {
  _FakePhotoService(this.root);

  final String root;

  @override
  String resolve(String relativePath) => '$root/$relativePath';

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
