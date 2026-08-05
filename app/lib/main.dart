import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'core/network/dio_client.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';

void main() {
  // Grafo de dependências montado uma única vez.
  // Um teste pode montar o app com um repositório falso trocando esta linha.
  final authRepository = AuthRepository(
    AuthApi(createDioClient()),
    const FlutterSecureStorage(),
  );

  runApp(InspecaoCampoApp(authRepository: authRepository));
}
