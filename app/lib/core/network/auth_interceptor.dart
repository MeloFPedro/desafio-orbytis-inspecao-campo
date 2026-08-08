import 'package:dio/dio.dart';

/// Anexa o token nas rotas protegidas e anuncia expiração de sessão.
///
/// Não conhece o AuthBloc: comunica por callback, o que quebra a dependência
/// circular entre Dio, repositório e bloc.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.readToken, required this.onUnauthorized});

  final Future<String?> Function() readToken;
  final void Function() onUnauthorized;

  bool _isPublicRoute(String path) => path.startsWith('/auth/login');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicRoute(options.path)) {
      final token = await readToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // Chega aqui, e não em onError, porque validateStatus aceita todo status.
    final isSessionDead =
        response.statusCode == 401 &&
        !_isPublicRoute(response.requestOptions.path);

    if (isSessionDead) onUnauthorized();

    handler.next(response);
  }
}
