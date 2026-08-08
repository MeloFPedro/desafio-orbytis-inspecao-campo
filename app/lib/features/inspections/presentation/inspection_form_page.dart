import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failures.dart';
import '../../../core/location/location_service.dart';
import '../../../core/media/photo_service.dart';
import '../../sync/presentation/sync_bloc.dart';
import '../../sync/presentation/sync_event.dart';
import '../../work_orders/domain/work_order.dart';
import '../data/inspections_repository.dart';
import 'inspection_form_bloc.dart';
import 'inspection_form_event.dart';
import 'inspection_form_state.dart';

const _conditions = ['bom', 'regular', 'ruim', 'crítico'];

/// Raio do geofence opcional: avisa, não bloqueia.
const _geofenceRadiusMeters = 200.0;

class InspectionFormPage extends StatelessWidget {
  const InspectionFormPage({required this.workOrder, super.key});

  final WorkOrder workOrder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InspectionFormBloc(
        context.read<InspectionsRepository>(),
        context.read<PhotoService>(),
        context.read<LocationService>(),
        workOrderId: workOrder.id,
      )..add(const InspectionFormOpened()),
      child: _InspectionFormView(workOrder: workOrder),
    );
  }
}

class _InspectionFormView extends StatefulWidget {
  const _InspectionFormView({required this.workOrder});

  final WorkOrder workOrder;

  @override
  State<_InspectionFormView> createState() => _InspectionFormViewState();
}

class _InspectionFormViewState extends State<_InspectionFormView> {
  final _observationController = TextEditingController();
  String? _condition;

  /// Trava de preenchimento: o listener roda a cada mudança de estado, e
  /// reescrever o controlador apagaria o que o técnico está digitando.
  bool _prefilled = false;

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  void _dispatch(BuildContext context, InspectionFormAction Function() build) {
    context.read<InspectionFormBloc>().add(build());
  }

  void _saveDraft(BuildContext context) => _dispatch(
        context,
        () => InspectionDraftSaved(
          observation: _observationController.text,
          condition: _condition,
        ),
      );

  void _complete(BuildContext context) => _dispatch(
        context,
        () => InspectionCompleteRequested(
          observation: _observationController.text,
          condition: _condition,
        ),
      );

  void _capturePhoto(BuildContext context) => _dispatch(
        context,
        () => InspectionPhotoRequested(
          observation: _observationController.text,
          condition: _condition,
        ),
      );

  void _captureLocation(BuildContext context) => _dispatch(
        context,
        () => InspectionLocationRequested(
          observation: _observationController.text,
          condition: _condition,
        ),
      );

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _firstError(InspectionFormState state, String field) {
    final messages = state.errors[field];
    return (messages == null || messages.isEmpty) ? null : messages.join(', ');
  }

  /// Rótulo da localização, incluindo o aviso de geofence.
  ///
  /// O cálculo fica na tela porque é puramente informativo: um aviso de que o
  /// técnico pode estar longe do ativo, derivado de dados que a tela já tem.
  String? _locationLabel(BuildContext context, InspectionFormState state) {
    final lat = state.draft?.latitude;
    final lng = state.draft?.longitude;
    if (lat == null || lng == null) return null;

    final coords = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

    final distance = context.read<LocationService>().distanceBetween(
          widget.workOrder.latitude,
          widget.workOrder.longitude,
          lat,
          lng,
        );

    if (distance > _geofenceRadiusMeters) {
      return '$coords — ${distance.toStringAsFixed(0)} m do ponto da OS';
    }
    return coords;
  }

  void _handleStatus(BuildContext context, InspectionFormState state) {
    switch (state.status) {
      case InspectionFormStatus.draftSaved:
        _showMessage(context, 'Rascunho salvo.');
      case InspectionFormStatus.completed:
        // Momento mais natural para tentar enviar: o trabalho acabou de ser
        // feito. Não força o backoff — concluir não é informação nova sobre a
        // rede. Despachado antes do pop, enquanto o contexto ainda é válido.
        context.read<SyncBloc>().add(const SyncAutoTriggered());

        // Pop antes da mensagem: assim quem a exibe é o ScaffoldMessenger da
        // tela de baixo, e ela não some junto com esta.
        Navigator.of(context).pop();
        _showMessage(context, 'Inspeção concluída e na fila de envio.');
      case InspectionFormStatus.invalid:
        _showMessage(context, 'Inspeção incompleta. Revise os campos.');
      case InspectionFormStatus.captureFailed:
        final failure = state.captureFailure;
        final canOpenSettings =
            failure is LocationFailure && failure.canOpenSettings;

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(failure?.message ?? 'Falha na captura.'),
              action: canOpenSettings
                  ? SnackBarAction(
                      label: 'Configurações',
                      onPressed: context.read<LocationService>().openSettings,
                    )
                  : null,
            ),
          );
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.workOrder.code)),
      body: BlocConsumer<InspectionFormBloc, InspectionFormState>(
        listener: (context, state) {
          if (!_prefilled && state.status == InspectionFormStatus.ready) {
            _prefilled = true;
            _observationController.text = state.draft?.observation ?? '';
            setState(() => _condition = state.draft?.condition);
          }

          _handleStatus(context, state);
        },
        builder: (context, state) {
          if (state.status == InspectionFormStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final photoPath = state.draft?.photoPath;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _WorkOrderHeader(workOrder: widget.workOrder),
              const SizedBox(height: 24),
              TextField(
                controller: _observationController,
                enabled: !state.isBusy,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Observação',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  errorText: _firstError(state, 'observation'),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _condition,
                decoration: const InputDecoration(
                  labelText: 'Condição do ativo',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final item in _conditions)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: state.isBusy
                    ? null
                    : (value) => setState(() => _condition = value),
              ),
              const SizedBox(height: 16),
              _CaptureTile(
                icon: Icons.photo_camera_outlined,
                label: 'Foto da evidência',
                emptyLabel: 'Toque para capturar',
                value: photoPath == null ? null : 'Foto capturada',
                error: _firstError(state, 'photo'),
                onTap: state.isBusy ? null : () => _capturePhoto(context),
                leadingPreview: photoPath == null
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(context.read<PhotoService>().resolve(photoPath)),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              _CaptureTile(
                icon: Icons.my_location_outlined,
                label: 'Localização',
                emptyLabel: 'Toque para capturar',
                value: _locationLabel(context, state),
                error: _firstError(state, 'location'),
                onTap: state.isBusy ? null : () => _captureLocation(context),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: state.isBusy ? null : () => _saveDraft(context),
                child: const Text('Salvar rascunho'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: state.isBusy ? null : () => _complete(context),
                child: const Text('Concluir inspeção'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WorkOrderHeader extends StatelessWidget {
  const _WorkOrderHeader({required this.workOrder});

  final WorkOrder workOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = workOrder.notes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workOrder.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(workOrder.address, style: theme.textTheme.bodyMedium),
            if (workOrder.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(workOrder.description, style: theme.textTheme.bodySmall),
            ],
            // Observações do backoffice costumam trazer alerta de segurança
            // ("área com pedestres") ou contexto que muda a leitura do ativo
            // ("retorno de visita anterior"). Destacadas por isso.
            if (notes != null && notes.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Observações da OS',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notes,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    required this.icon,
    required this.label,
    required this.emptyLabel,
    required this.onTap,
    this.value,
    this.error,
    this.leadingPreview,
  });

  final IconData icon;
  final String label;
  final String emptyLabel;
  final VoidCallback? onTap;
  final String? value;
  final String? error;
  final Widget? leadingPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = error != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: leadingPreview ??
          Icon(icon, color: hasError ? theme.colorScheme.error : null),
      title: Text(label),
      subtitle: Text(
        error ?? value ?? emptyLabel,
        style: hasError ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
