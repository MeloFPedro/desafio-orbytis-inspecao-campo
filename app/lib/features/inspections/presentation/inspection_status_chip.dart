import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

/// Selo do estado local de uma inspeção.
///
/// Compartilhado entre o histórico e a lista de ordens de serviço: duas
/// cópias da mesma tabela de cores divergem com o tempo.
class InspectionStatusChip extends StatelessWidget {
  const InspectionStatusChip({required this.status, this.prefix, super.key});

  final SyncStatus status;

  /// Prefixo opcional, para contextos onde o selo aparece ao lado de outros
  /// que falam de coisas diferentes — na lista de OS, por exemplo, onde
  /// prioridade e status pertencem ao servidor e este é local.
  ///
  /// Nulo no histórico, onde a tela inteira já é sobre inspeções.
  final String? prefix;

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
            prefix == null ? status.label : '$prefix: ${status.label}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
