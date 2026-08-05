import 'package:dio/dio.dart';

import '../../../core/error/error_mapper.dart';

class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  /// POST /auth/login
  ///
  /// Devolve o corpo cru da resposta em caso de sucesso.
  /// Lança [Failure] em qualquer outro caso.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );

      final status = response.statusCode ?? 0;
      if (status == 200) {
        return response.data as Map<String, dynamic>;
      }

      throw mapHttpError(status, response.data);
    } on DioException catch (e) {
      throw mapTransportError(e);
    }
  }
}
