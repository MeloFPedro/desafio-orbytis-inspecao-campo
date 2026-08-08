import 'package:dio/dio.dart';

import 'failures.dart';

/// Problema de transporte: a requisição não chegou a receber resposta.
/// Sempre transiente.
Failure mapTransportError(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkFailure('Tempo de conexão esgotado.');
    case DioExceptionType.connectionError:
      return const NetworkFailure('Não foi possível alcançar o servidor.');
    default:
      return NetworkFailure(e.message ?? 'Falha de comunicação.');
  }
}

/// Houve resposta, mas com status de erro. O status decide se é permanente.
Failure mapHttpError(int status, dynamic body) {
  final message = _extractMessage(body);

  if (status == 400) {
    return ValidationFailure(
      message ?? 'Dados inválidos.',
      errors: _extractFieldErrors(body),
    );
  }
  if (status == 401) return UnauthorizedFailure(message ?? 'Não autorizado.');
  if (status == 404) {
    return NotFoundFailure(message ?? 'Registro não encontrado.');
  }
  if (status == 409) return ConflictFailure(message ?? 'Conflito no servidor.');
  if (status >= 500) return ServerFailure(message ?? 'Erro no servidor.');

  return UnknownFailure(message ?? 'Erro inesperado (HTTP $status).');
}

String? _extractMessage(dynamic body) {
  if (body is Map && body['message'] is String) {
    return body['message'] as String;
  }
  return null;
}

Map<String, List<String>> _extractFieldErrors(dynamic body) {
  if (body is! Map || body['errors'] is! Map) return const {};

  final raw = body['errors'] as Map;
  return raw.map(
    (key, value) => MapEntry(
      key.toString(),
      value is List
          ? value.map((item) => item.toString()).toList()
          : [value.toString()],
    ),
  );
}
