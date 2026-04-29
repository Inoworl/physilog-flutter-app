import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:physi_log/models/measurement_record.dart';

class RecordListTile extends StatelessWidget {
  const RecordListTile({super.key, required this.record, this.onDismissed});

  final MeasurementRecord record;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = record.athleteName.trim().isEmpty
        ? '未登録'
        : record.athleteName.trim();
    final avatarLetter = displayName.isEmpty
        ? '未'
        : String.fromCharCodes(displayName.runes.take(1));
    final dateFormat = DateFormat('yyyy/MM/dd');
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.pushNamed(
          'recordDetail',
          pathParameters: {'id': record.id},
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: Text(
                      avatarLetter,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.eventType.isEmpty ? '種目未設定' : record.eventType,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dateFormat.format(record.measuredAt)} ${timeFormat.format(record.measuredAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        record.formattedRecordValue,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (record.accuracyInfo != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          record.accuracyInfo!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _RecordSheetPreview(record: record),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordSheetPreview extends StatelessWidget {
  const _RecordSheetPreview({required this.record});

  final MeasurementRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Table(
      border: TableBorder.all(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(0.8),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          children: const [
            _TableCell('日付 / 種目名', isHeader: true),
            _TableCell('選手名', isHeader: true),
            _TableCell('記録', isHeader: true, alignRight: true),
          ],
        ),
        TableRow(
          children: [
            _TableCell(
              '${dateFormat.format(record.measuredAt)}\n${record.eventType.isEmpty ? '未設定' : record.eventType}',
            ),
            _TableCell(record.athleteName.isEmpty ? '未登録' : record.athleteName),
            _TableCell(
              record.formattedRecordValue,
              alignRight: true,
              isValue: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(
    this.text, {
    this.isHeader = false,
    this.alignRight = false,
    this.isValue = false,
  });

  final String text;
  final bool isHeader;
  final bool alignRight;
  final bool isValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = isHeader
        ? theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)
        : isValue
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: theme.colorScheme.primary,
          )
        : theme.textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: style,
      ),
    );
  }
}
