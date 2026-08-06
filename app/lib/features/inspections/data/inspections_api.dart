import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/error/error_mapper.dart';

class InspectionsApi {
  const InspectionsApi(this._dio);

  final Dio _dio;

  /// POST /inspections em multipart.
  ///
  /// Multipart e não JSON com base64: evita inflar a foto em ~33% e é a forma
  /// marcada como recomendada no contrato.
  ///
  /// Devolve o corpo da resposta. Lança [Failure] em erro.
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
    try {
      final formData = FormData.fromMap({
        'clientId': clientId,
        'workOrderId': workOrderId,
        'observation': observation,
        // ?valor: omite a entrada quando o valor é nulo.
        'condition': ?condition,
        'latitude': latitude,
        'longitude': longitude,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: p.basename(photo.path),
        ),
      });

      final response = await _dio.post<dynamic>('/inspections', data: formData);
      final status = response.statusCode ?? 0;

      // 201 = criada. 200 = já existia com este clientId.
      //
      // Os dois são sucesso. O contrato define idempotência por clientId, e
      // tratar apenas 201 faria todo reenvio parecer falha — o app retentaria,
      // receberia 200 de novo, e nunca sairia do lugar.
      if (status == 200 || status == 201) {
        return response.data as Map<String, dynamic>;
      }

      throw mapHttpError(status, response.data);
    } on DioException catch (e) {
      throw mapTransportError(e);
    }
  }
}
