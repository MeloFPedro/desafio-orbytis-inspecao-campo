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

class InspectionDraftSaved extends InspectionFormEvent {
  const InspectionDraftSaved({required this.observation, this.condition});

  final String observation;
  final String? condition;

  @override
  List<Object?> get props => [observation, condition];
}

class InspectionCompleteRequested extends InspectionFormEvent {
  const InspectionCompleteRequested({
    required this.observation,
    this.condition,
  });

  final String observation;
  final String? condition;

  @override
  List<Object?> get props => [observation, condition];
}
