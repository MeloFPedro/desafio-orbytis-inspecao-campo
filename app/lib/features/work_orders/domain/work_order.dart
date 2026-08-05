import 'package:equatable/equatable.dart';

enum WorkOrderPriority {
  high('high', 'Alta'),
  medium('medium', 'Média'),
  low('low', 'Baixa'),
  unknown('', 'Não informada');

  const WorkOrderPriority(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Valor desconhecido não derruba o parsing: vira [unknown].
  static WorkOrderPriority fromApi(String? value) => values.firstWhere(
        (item) => item.apiValue == value,
        orElse: () => unknown,
      );
}

enum WorkOrderStatus {
  open('open', 'Aberta'),
  inProgress('in_progress', 'Em andamento'),
  done('done', 'Concluída'),
  unknown('', 'Desconhecido');

  const WorkOrderStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static WorkOrderStatus fromApi(String? value) => values.firstWhere(
        (item) => item.apiValue == value,
        orElse: () => unknown,
      );
}

class WorkOrder extends Equatable {
  const WorkOrder({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.address,
    required this.priority,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.scheduledAt,
    this.notes,
  });

  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    return WorkOrder(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      priority: WorkOrderPriority.fromApi(json['priority'] as String?),
      status: WorkOrderStatus.fromApi(json['status'] as String?),
      // num aceita int e double: JSON não distingue -7 de -7.0.
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? ''),
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String code;
  final String title;
  final String description;
  final String address;
  final WorkOrderPriority priority;
  final WorkOrderStatus status;
  final double latitude;
  final double longitude;
  final DateTime? scheduledAt;
  final String? notes;

  /// Apenas o que define identidade e o que muda na tela.
  @override
  List<Object?> get props => [id, code, title, status, priority];
}
