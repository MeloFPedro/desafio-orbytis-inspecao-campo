import 'package:dio/dio.dart';

class ApiConfig {
  const ApiConfig._();

  /// O emulador Android alcança o localhost da máquina hospedeira por 10.0.2.2.
  /// Em device físico, trocar pelo IP da máquina na LAN.
  static const String baseUrl = 'http://10.0.2.2:3000';

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