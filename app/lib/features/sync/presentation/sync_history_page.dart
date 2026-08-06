import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/app_database.dart';
import '../../inspections/data/inspections_repository.dart';
import '../data/sync_service.dart';
import 'sync_bloc.dart';
import 'sync_event.dart';
import 'sync_state.dart';

/// Sem bloc próprio de propósito.
///
/// O Drift já expõe a lista como Stream reativo, e o StreamBuilder cancela a
/// assinatura anterior ao trocar de stream — que é exatamente o comportamento
/// necessário na mudança de filtro. Um bloc aqui seria repasse sem lógica, e
/// precisaria do transformador `restartable()` para não deixar duas
/// assinaturas ativas.
class SyncHistoryPage extends StatefulWidget {
  const SyncHistoryPage({super.key});

  @override
  State<SyncHistoryPage> createState() => _SyncHistoryPageState();
}

class _SyncHistoryPageState extends State<SyncHistoryPage> {
  /// Nulo significa "todas".
  SyncStatus? _filter;

  @override
  void initState() {
    super.initState();
    // Abrir o histórico é um bom momento para tentar esvaziar a fila.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SyncBloc>().add(const SyncAutoTriggered());
    });
  }

  Stream<List<Inspection>> _stream(BuildContext context) {
    final repository = context.read<InspectionsRepository>();
    final filter = _filter;
    return filter == null
        ? repository.watchAll()
        : repository.watchByStatus(filter);
  }

  String _resultMessage(SyncResult result) {
    if (result.skipped) return 'Sincronização já em andamento.';
    if (result.sessionExpired) return 'Sessão expirada. Faça login novamente.';
    if (result.processed == 0) return 'Nada a sincronizar.';

    final parts = <String>[
      if (result.synced > 0) '${result.synced} enviada(s)',
      if (result.retryScheduled > 0) '${result.retryScheduled} adiada(s)',
      if (result.failed > 0) '${result.failed} com falha',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SyncBloc, SyncState>(
      // Só execuções manuais avisam: sincronização automática que não achou
      // nada não deveria interromper o técnico.
      listenWhen: (previous, current) =>
          !current.isRunning &&
          current.lastRunWasManual &&
          current.lastResult != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_resultMessage(state.lastResult!))),
          );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Histórico de inspeções'),
          actions: [
            BlocBuilder<SyncBloc, SyncState>(
              builder: (context, state) => state.isRunning
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.sync),
                      tooltip: 'Sincronizar agora',
                      onPressed: () =>
                          context.read<SyncBloc>().add(const SyncRequested()),
                    ),
            ),
          ],
        ),
        body: Column(
          children: [
            _FilterBar(
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<Inspection>>(
                stream: _stream(context),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = snapshot.data!;
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma inspeção neste filtro.'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, index) =>
                        _InspectionCard(inspection: items[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final SyncStatus? selected;
  final ValueChanged<SyncStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Todas'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          for (final status in SyncStatus.values) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: Text(status.label),
              selected: selected == status,
              onSelected: (_) => onChanged(status),
            ),
          ],
        ],
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({required this.inspection});

  final Inspection inspection;

  /// Quantas idas à rede este registro custou.
  ///
  /// Omitido quando sincronizou de primeira — nesse caso o número não informa
  /// nada que o selo verde já não diga.
  String? get _attemptsLabel {
    if (inspection.retryCount <= 0) return null;

    if (inspection.syncStatus == SyncStatus.synced) {
      return inspection.retryCount > 1
          ? 'Enviada após ${inspection.retryCount} tentativas'
          : null;
    }

    return '${inspection.retryCount} tentativa(s)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFailed = inspection.syncStatus == SyncStatus.failed;

    // Lido para uma local: getters não sofrem promoção de tipo em Dart.
    final attemptsLabel = _attemptsLabel;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusBadge(status: inspection.syncStatus),
                const Spacer(),
                Text(inspection.workOrderId, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              inspection.observation.isEmpty
                  ? '(sem observação)'
                  : inspection.observation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (inspection.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                inspection.lastError!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            if (attemptsLabel != null) ...[
              const SizedBox(height: 4),
              Text(attemptsLabel, style: theme.textTheme.bodySmall),
            ],
            if (isFailed) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                  onPressed: () async {
                    await context
                        .read<InspectionsRepository>()
                        .retry(inspection.clientId);
                    if (context.mounted) {
                      context.read<SyncBloc>().add(const SyncRequested());
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SyncStatus.draft => Colors.grey.shade600,
      SyncStatus.pending => Colors.orange.shade700,
      SyncStatus.synced => Colors.green.shade700,
      SyncStatus.failed => Colors.red.shade700,
    };

    final icon = switch (status) {
      SyncStatus.draft => Icons.edit_note,
      SyncStatus.pending => Icons.schedule,
      SyncStatus.synced => Icons.cloud_done,
      SyncStatus.failed => Icons.error_outline,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
