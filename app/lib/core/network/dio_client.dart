import 'package:dio/dio.dart';

class ApiConfig {
  const ApiConfig._();

  /// Padrão: emulador Android, onde 10.0.2.2 é o alias para o localhost da
  /// máquina hospedeira. Esse endereço não existe fora do emulador.
  ///
  /// Em device físico, sobrescreva na linha de comando:
  ///
  /// ```
  /// adb reverse tcp:3000 tcp:3000
  /// flutter run --dart-define=API_BASE_URL=http://localhost:3000
  /// ```
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}

Dio createDioClient() {
  return Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Accept': 'application/json'},
      // Nunca lançar exceção por causa do status HTTP.
      // Assim: DioException = problema de transporte (rede, timeout).
      //        response.statusCode = resposta do servidor, inclusive erro.
      validateStatus: (_) => true,
    ),
  );
}
