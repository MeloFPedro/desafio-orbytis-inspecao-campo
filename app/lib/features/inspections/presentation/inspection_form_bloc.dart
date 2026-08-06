import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../../../core/location/location_service.dart';
import '../../../core/media/photo_service.dart';
import '../data/inspections_repository.dart';
import 'inspection_form_event.dart';
import 'inspection_form_state.dart';

class InspectionFormBloc
    extends Bloc<InspectionFormEvent, InspectionFormState> {
  InspectionFormBloc(
    this._repository,
    this._photoService,
    this._locationService, {
    required this.workOrderId,
  }) : super(const InspectionFormState()) {
    on<InspectionFormOpened>(_onOpened);
    on<InspectionDraftSaved>(_onDraftSaved);
    on<InspectionCompleteRequested>(_onCompleteRequested);
    on<InspectionPhotoRequested>(_onPhotoRequested);
    on<InspectionLocationRequested>(_onLocationRequested);
  }

  final InspectionsRepository _repository;
  final PhotoService _photoService;
  final LocationService _locationService;
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

    await _persistAndReload(
      emit,
      observation: event.observation,
      condition: event.condition,
      finalStatus: InspectionFormStatus.draftSaved,
    );
  }

  Future<void> _onCompleteRequested(
    InspectionCompleteRequested event,
    Emitter<InspectionFormState> emit,
  ) async {
    emit(state.copyWith(status: InspectionFormStatus.saving));

    // Grava o texto atual antes de validar: a validação lê do banco, e o que
    // está na tela ainda não chegou lá.
    final clientId = await _persistAndReload(
      emit,
      observation: event.observation,
      condition: event.condition,
      finalStatus: InspectionFormStatus.ready,
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

  Future<void> _onPhotoRequested(
    InspectionPhotoRequested event,
    Emitter<InspectionFormState> emit,
  ) async {
    emit(state.copyWith(status: InspectionFormStatus.saving));

    try {
      final captured = await _photoService.capture();

      // Nulo significa que o técnico cancelou a câmera: não é erro.
      if (captured == null) {
        emit(state.copyWith(status: InspectionFormStatus.ready));
        return;
      }

      final previous = state.draft?.photoPath;

      await _persistAndReload(
        emit,
        observation: event.observation,
        condition: event.condition,
        photoPath: captured,
      );

      // Só apaga a anterior depois que a nova está gravada. Invertendo, uma
      // falha de escrita deixaria a inspeção sem foto nenhuma.
      if (previous != null && previous != captured) {
        await _photoService.delete(previous);
      }
    } catch (error) {
      emit(
        state.copyWith(
          status: InspectionFormStatus.captureFailed,
          captureFailure: error is Failure
              ? error
              : const UnknownFailure('Não foi possível capturar a foto.'),
        ),
      );
    }
  }

  Future<void> _onLocationRequested(
    InspectionLocationRequested event,
    Emitter<InspectionFormState> emit,
  ) async {
    emit(state.copyWith(status: InspectionFormStatus.saving));

    try {
      final position = await _locationService.current();

      await _persistAndReload(
        emit,
        observation: event.observation,
        condition: event.condition,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(
          status: InspectionFormStatus.captureFailed,
          captureFailure: failure,
        ),
      );
    }
  }

  /// Grava e recarrega do banco, devolvendo o `clientId`.
  ///
  /// O recarregamento importa: sem ele, `state.draft` ficaria com os valores
  /// antigos e a próxima gravação apagaria o que acabou de ser capturado.
  Future<String> _persistAndReload(
    Emitter<InspectionFormState> emit, {
    required String observation,
    String? condition,
    String? photoPath,
    double? latitude,
    double? longitude,
    InspectionFormStatus finalStatus = InspectionFormStatus.ready,
  }) async {
    final clientId = await _repository.saveDraft(
      clientId: state.clientId,
      workOrderId: workOrderId,
      observation: observation,
      condition: condition,
      photoPath: photoPath ?? state.draft?.photoPath,
      latitude: latitude ?? state.draft?.latitude,
      longitude: longitude ?? state.draft?.longitude,
    );

    final draft = await _repository.findByClientId(clientId);

    emit(
      state.copyWith(
        status: finalStatus,
        clientId: clientId,
        draft: draft,
        errors: const {},
      ),
    );

    return clientId;
  }
}
