import 'package:equatable/equatable.dart';

import '../../../core/database/app_database.dart';

enum InspectionFormStatus {
  loading,
  ready,
  saving,
  draftSaved,
  completed,
  invalid,
}

/// Estado único com campo de status, e não estados separados.
///
/// O critério: estados separados quando os dados são disjuntos; estado único
/// quando os mesmos dados persistem através das transições. Aqui `clientId` e
/// `draft` existem em todos os momentos do formulário.
class InspectionFormState extends Equatable {
  const InspectionFormState({
    this.status = InspectionFormStatus.loading,
    this.clientId,
    this.draft,
    this.errors = const {},
  });

  final InspectionFormStatus status;

  /// Nulo até o primeiro salvamento de uma inspeção nova.
  final String? clientId;

  /// Rascunho carregado do banco, usado para preencher os campos.
  final Inspection? draft;

  /// Mesmo formato que a API devolve em um 400: campo -> mensagens.
  final Map<String, List<String>> errors;

  bool get isBusy =>
      status == InspectionFormStatus.loading ||
      status == InspectionFormStatus.saving;

  InspectionFormState copyWith({
    InspectionFormStatus? status,
    String? clientId,
    Inspection? draft,
    Map<String, List<String>>? errors,
  }) {
    return InspectionFormState(
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      draft: draft ?? this.draft,
      errors: errors ?? this.errors,
    );
  }

  @override
  List<Object?> get props => [status, clientId, draft, errors];
}
