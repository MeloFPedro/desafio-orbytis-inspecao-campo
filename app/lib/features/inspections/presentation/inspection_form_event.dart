import 'package:equatable/equatable.dart';

sealed class InspectionFormEvent extends Equatable {
  const InspectionFormEvent();

  @override
  List<Object?> get props => [];
}

/// Tela abriu: carrega rascunho existente desta OS, se houver.
class InspectionFormOpened extends InspectionFormEvent {
  const InspectionFormOpened();
}

/// Ações que carregam o conteúdo atual da tela.
///
/// Qualquer uma delas grava no banco, então precisa levar junto o que o
/// técnico digitou — caso contrário a escrita apagaria o texto não salvo.
sealed class InspectionFormAction extends InspectionFormEvent {
  const InspectionFormAction({required this.observation, this.condition});

  final String observation;
  final String? condition;

  @override
  List<Object?> get props => [observation, condition];
}

class InspectionDraftSaved extends InspectionFormAction {
  const InspectionDraftSaved({required super.observation, super.condition});
}

class InspectionCompleteRequested extends InspectionFormAction {
  const InspectionCompleteRequested({
    required super.observation,
    super.condition,
  });
}

class InspectionPhotoRequested extends InspectionFormAction {
  const InspectionPhotoRequested({required super.observation, super.condition});
}

class InspectionLocationRequested extends InspectionFormAction {
  const InspectionLocationRequested({
    required super.observation,
    super.condition,
  });
}
