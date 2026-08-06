import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../data/work_orders_repository.dart';
import 'work_orders_event.dart';
import 'work_orders_state.dart';

class WorkOrdersBloc extends Bloc<WorkOrdersEvent, WorkOrdersState> {
  WorkOrdersBloc(this._repository) : super(const WorkOrdersInitial()) {
    on<WorkOrdersRequested>(_onRequested);
    on<WorkOrdersRefreshed>(_onRefreshed);
  }

  final WorkOrdersRepository _repository;

  Future<void> _onRequested(
    WorkOrdersRequested event,
    Emitter<WorkOrdersState> emit,
  ) async {
    emit(const WorkOrdersLoading());
    await _fetch(emit);
  }

  Future<void> _onRefreshed(
    WorkOrdersRefreshed event,
    Emitter<WorkOrdersState> emit,
  ) async {
    // Sem Loading: o RefreshIndicator já sinaliza, e a lista segue na tela.
    try {
      await _fetch(emit);
    } finally {
      // Sempre completa, inclusive quando não houve mudança de estado.
      event.completer?.complete();
    }
  }

  Future<void> _fetch(Emitter<WorkOrdersState> emit) async {
    try {
      emit(WorkOrdersLoaded(await _repository.fetchAll()));
    } on Failure catch (failure) {
      emit(WorkOrdersError(failure.message));
    }
  }
}
