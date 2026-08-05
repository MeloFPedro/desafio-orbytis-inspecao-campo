import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/network/auth_interceptor.dart';
import 'core/network/dio_client.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';

void main() {
  // Canal por onde o interceptor anuncia que a sessão morreu.
  // broadcast: mais de um ouvinte (a fila de sync também vai querer saber).
  final sessionExpired = StreamController<void>.broadcast();

  final dio = createDioClient();
  final authRepository = AuthRepository(
    AuthApi(dio),
    const FlutterSecureStorage(),
  );

  // Registrado depois do repositório: é o que quebra a dependência circular.
  dio.interceptors.add(
    AuthInterceptor(
      readToken: authRepository.readToken,
      onUnauthorized: () => sessionExpired.add(null),
    ),
  );

  runApp(
    InspecaoCampoApp(
      dio: dio,
      authRepository: authRepository,
      sessionExpired: sessionExpired.stream,
    ),
  );
}
