import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../work_orders/domain/work_order.dart';
import '../data/inspections_repository.dart';
import 'inspection_form_bloc.dart';
import 'inspection_form_event.dart';
import 'inspection_form_state.dart';

const _conditions = ['bom', 'regular', 'ruim', 'crítico'];

class InspectionFormPage extends StatelessWidget {
  const InspectionFormPage({required this.workOrder, super.key});

  final WorkOrder workOrder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InspectionFormBloc(
        context.read<InspectionsRepository>(),
        workOrder.id,
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

  void _saveDraft(BuildContext context) {
    context.read<InspectionFormBloc>().add(
          InspectionDraftSaved(
            observation: _observationController.text,
            condition: _condition,
          ),
        );
  }

  void _complete(BuildContext context) {
    context.read<InspectionFormBloc>().add(
          InspectionCompleteRequested(
            observation: _observationController.text,
            condition: _condition,
          ),
        );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _firstError(InspectionFormState state, String field) {
    final messages = state.errors[field];
    return (messages == null || messages.isEmpty) ? null : messages.join(', ');
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

          switch (state.status) {
            case InspectionFormStatus.draftSaved:
              _showMessage(context, 'Rascunho salvo.');
            case InspectionFormStatus.completed:
              // Pop antes da mensagem: assim quem a exibe é o ScaffoldMessenger
              // da tela de baixo, e ela não some junto com esta.
              Navigator.of(context).pop();
              _showMessage(context, 'Inspeção concluída e na fila de envio.');
            case InspectionFormStatus.invalid:
              _showMessage(context, 'Inspeção incompleta. Revise os campos.');
            case _:
              break;
          }
        },
        builder: (context, state) {
          if (state.status == InspectionFormStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

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
                value: state.draft?.photoPath,
                emptyLabel: 'Nenhuma foto capturada',
                error: _firstError(state, 'photo'),
              ),
              _CaptureTile(
                icon: Icons.my_location_outlined,
                label: 'Localização',
                value: state.draft?.latitude == null
                    ? null
                    : '${state.draft!.latitude}, ${state.draft!.longitude}',
                emptyLabel: 'Nenhuma localização capturada',
                error: _firstError(state, 'location'),
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
          ],
        ),
      ),
    );
  }
}

/// Foto e localização ganham captura no próximo passo.
class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    required this.icon,
    required this.label,
    required this.emptyLabel,
    this.value,
    this.error,
  });

  final IconData icon;
  final String label;
  final String emptyLabel;
  final String? value;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = error != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: hasError ? theme.colorScheme.error : null),
      title: Text(label),
      subtitle: Text(
        error ?? value ?? emptyLabel,
        style: hasError ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      enabled: false,
    );
  }
}
