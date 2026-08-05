import '../domain/work_order.dart';
import 'work_orders_api.dart';

class WorkOrdersRepository {
  const WorkOrdersRepository(this._api);

  final WorkOrdersApi _api;

  Future<List<WorkOrder>> fetchAll() async {
    final raw = await _api.fetchAll();
    return raw.map(WorkOrder.fromJson).toList();
  }
}
