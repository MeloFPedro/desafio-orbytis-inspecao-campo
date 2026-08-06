import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/presentation/auth_bloc.dart';
import '../../auth/presentation/auth_event.dart';
import '../domain/work_order.dart';
import 'work_orders_bloc.dart';
import 'work_orders_event.dart';
import 'work_orders_state.dart';

class WorkOrdersPage extends StatelessWidget {
  const WorkOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordens de serviço'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: BlocBuilder<WorkOrdersBloc, WorkOrdersState>(
        builder: (context, state) => switch (state) {
          WorkOrdersInitial() ||
          WorkOrdersLoading() =>
            const Center(child: CircularProgressIndicator()),
          WorkOrdersError(:final message) => _ErrorView(message: message),
          WorkOrdersLoaded(:final items) => _LoadedView(items: items),
        },
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.items});

  final List<WorkOrder> items;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        final completer = Completer<void>();
        context
            .read<WorkOrdersBloc>()
            .add(WorkOrdersRefreshed(completer: completer));
        return completer.future;
      },
      child: items.isEmpty
          ? ListView(
              // Necessário para permitir o gesto numa lista sem conteúdo.
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: Text('Nenhuma ordem de serviço atribuída.')),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _WorkOrderCard(order: items[index]),
            ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context
                  .read<WorkOrdersBloc>()
                  .add(const WorkOrdersRequested()),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkOrderCard extends StatelessWidget {
  const _WorkOrderCard({required this.order});

  final WorkOrder order;

  Color _priorityColor(BuildContext context) => switch (order.priority) {
        WorkOrderPriority.high => Colors.red.shade700,
        WorkOrderPriority.medium => Colors.orange.shade700,
        WorkOrderPriority.low => Colors.green.shade700,
        WorkOrderPriority.unknown => Theme.of(context).disabledColor,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(order.title, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(order.address),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(order.priority.label),
                  labelStyle: TextStyle(color: _priorityColor(context)),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(order.status.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
