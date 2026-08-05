import 'package:dio/dio.dart';

import '../../../core/error/error_mapper.dart';

class WorkOrdersApi {
  const WorkOrdersApi(this._dio);

  final Dio _dio;

  /// GET /work-orders
  ///
  /// O header Authorization é injetado pelo AuthInterceptor.
  /// Lança [Failure] em erro.
  Future<List<Map<String, dynamic>>> fetchAll() async {
    try {
      final response = await _dio.get<dynamic>('/work-orders');

      final status = response.statusCode ?? 0;
      if (status == 200) {
        return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
      }

      throw mapHttpError(status, response.data);
    } on DioException catch (e) {
      throw mapTransportError(e);
    }
  }
}
