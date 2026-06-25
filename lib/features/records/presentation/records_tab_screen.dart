import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/features/records/presentation/daily_sheet_view.dart';
import 'package:physi_log/features/records/presentation/manual_record_form.dart';
import 'package:physi_log/features/records/presentation/record_sheet_view.dart';
import 'package:physi_log/features/records/presentation/widgets/record_filter_sheet.dart';

enum RecordsViewMode { daily, sheet }

class RecordsTabScreen extends ConsumerStatefulWidget {
  const RecordsTabScreen({
    super.key,
    this.initialViewMode = RecordsViewMode.daily,
    this.initialAthleteId,
  });

  final RecordsViewMode initialViewMode;
  final String? initialAthleteId;

  @override
  ConsumerState<RecordsTabScreen> createState() => _RecordsTabScreenState();
}

class _RecordsTabScreenState extends ConsumerState<RecordsTabScreen> {
  late RecordsViewMode _viewMode;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
  }

  @override
  void didUpdateWidget(covariant RecordsTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialViewMode != oldWidget.initialViewMode ||
        widget.initialAthleteId != oldWidget.initialAthleteId) {
      _viewMode = widget.initialViewMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('記録'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('検索機能は準備中です')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => RecordFilterSheet.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: SegmentedButton<RecordsViewMode>(
              segments: const [
                ButtonSegment(
                  value: RecordsViewMode.daily,
                  label: Text('日別'),
                  icon: Icon(Icons.event_note),
                ),
                ButtonSegment(
                  value: RecordsViewMode.sheet,
                  label: Text('シート'),
                  icon: Icon(Icons.table_chart),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (selected) {
                setState(() => _viewMode = selected.first);
              },
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: switch (_viewMode) {
                RecordsViewMode.daily => const DailySheetView(
                  key: ValueKey(RecordsViewMode.daily),
                ),
                RecordsViewMode.sheet => RecordSheetView(
                  key: ValueKey(
                    '${RecordsViewMode.sheet.name}-${widget.initialAthleteId ?? ''}',
                  ),
                  initialAthleteId: widget.initialAthleteId,
                ),
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ManualRecordForm.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
