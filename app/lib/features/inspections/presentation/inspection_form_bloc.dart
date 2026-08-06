import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../data/inspections_repository.dart';
import 'inspection_form_event.dart';
import 'inspection_form_state.dart';

class InspectionFormBloc
    extends Bloc<InspectionFormEvent, InspectionFormState> {
  InspectionFormBloc(this._repository, this.workOrderId)
      : super(const InspectionFormState()) {
    on<InspectionFormOpened>(_onOpened);
    on<InspectionDraftSaved>(_onDraftSaved);
    on<InspectionCompleteRequested>(_onCompleteRequested);
  }

  final InspectionsRepository _repository;
  final String workOrderId;

  Future<void> _onOpened(
    InspectionFormOpened event,
    Emitter<InspectionFormState> emit,
  ) async {
    final draft = await _repository.findDraftForWorkOrder(workOrderId);

    emit(
      InspectionFormState(
        status: InspectionFormStatus.ready,
        clientId: draft?.clientId,
        draft: draft,
      ),
    );
  }

  Future<void> _onDraftSaved(
    InspectionDraftSaved event,
    Emitter<InspectionFormState> emit,
  ) async {
    emit(state.copyWith(status: InspectionFormStatus.saving));

    final clientId = await _persist(
      observation: event.observation,
      condition: event.condition,
    );

    emit(
      state.copyWith(
        status: InspectionFormStatus.draftSaved,
        clientId: clientId,
      ),
    );
  }

  Future<void> _onCompleteRequested(
    InspectionCompleteRequested event,
    Emitter<InspectionFormState> emit,
  ) async {
    emit(state.copyWith(status: InspectionFormStatus.saving));

    // Grava o texto atual antes de validar: a validação lê do banco, e o que
    // está na tela ainda não chegou lá.
    final clientId = await _persist(
      observation: event.observation,
      condition: event.condition,
    );

    try {
      await _repository.complete(clientId);
      emit(
        state.copyWith(
          status: InspectionFormStatus.completed,
          clientId: clientId,
          errors: const {},
        ),
      );
    } on ValidationFailure catch (failure) {
      emit(
        InspectionFormState(
          status: InspectionFormStatus.invalid,
          clientId: clientId,
          draft: state.draft,
          errors: failure.errors,
        ),
      );
    }
  }

  /// Repassa foto e coordenadas do rascunho: sem isso, cada salvamento
  /// apagaria o que já foi capturado, porque saveDraft grava o registro todo.
  Future<String> _persist({
    required String observation,
    String? condition,
  }) {
    return _repository.saveDraft(
      clientId: state.clientId,
      workOrderId: workOrderId,
      observation: observation,
      condition: condition,
      photoPath: state.draft?.photoPath,
      latitude: state.draft?.latitude,
      longitude: state.draft?.longitude,
    );
  }
}
