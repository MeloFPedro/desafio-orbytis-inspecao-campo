import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/network/auth_interceptor.dart';
import 'core/network/dio_client.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/inspections/data/inspections_dao.dart';
import 'features/inspections/data/inspections_repository.dart';
import 'features/work_orders/data/work_orders_api.dart';
import 'features/work_orders/data/work_orders_repository.dart';

void main() {
  // Canal por onde o interceptor anuncia que a sessão morreu.
  // broadcast: mais de um ouvinte (a fila de sync também vai querer saber).
  final sessionExpired = StreamController<void>.broadcast();

  final dio = createDioClient();
  final database = AppDatabase();

  final authRepository = AuthRepository(
    AuthApi(dio),
    const FlutterSecureStorage(),
  );
  final workOrdersRepository = WorkOrdersRepository(WorkOrdersApi(dio));
  final inspectionsRepository = InspectionsRepository(InspectionsDao(database));

  // Registrado depois do repositório: é o que quebra a dependência circular.
  dio.interceptors.add(
    AuthInterceptor(
      readToken: authRepository.readToken,
      onUnauthorized: () => sessionExpired.add(null),
    ),
  );

  runApp(
    InspecaoCampoApp(
      authRepository: authRepository,
      workOrdersRepository: workOrdersRepository,
      inspectionsRepository: inspectionsRepository,
      sessionExpired: sessionExpired.stream,
    ),
  );
}
