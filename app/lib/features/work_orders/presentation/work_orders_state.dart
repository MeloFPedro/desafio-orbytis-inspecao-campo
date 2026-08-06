import 'package:equatable/equatable.dart';

import '../domain/work_order.dart';

sealed class WorkOrdersState extends Equatable {
  const WorkOrdersState();

  @override
  List<Object?> get props => [];
}

class WorkOrdersInitial extends WorkOrdersState {
  const WorkOrdersInitial();
}

class WorkOrdersLoading extends WorkOrdersState {
  const WorkOrdersLoading();
}

/// Lista vazia é um Loaded válido — a tela decide como exibir.
class WorkOrdersLoaded extends WorkOrdersState {
  const WorkOrdersLoaded(this.items);

  final List<WorkOrder> items;

  @override
  List<Object?> get props => [items];
}

class WorkOrdersError extends WorkOrdersState {
  const WorkOrdersError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
