import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/features/records/presentation/widgets/delete_confirmation_dialog.dart';
import 'package:physi_log/features/records/presentation/widgets/record_filter_sheet.dart';
import 'package:physi_log/features/records/presentation/widgets/record_list_tile.dart';
import 'package:physi_log/models/measurement_record.dart';
import 'package:physi_log/shared/widgets/empty_state.dart';
import 'package:physi_log/shared/widgets/error_state.dart';
import 'package:physi_log/shared/widgets/loading_state.dart';

class RecordListScreen extends ConsumerStatefulWidget {
  const RecordListScreen({super.key});

  @override
  ConsumerState<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends ConsumerState<RecordListScreen> {
  HomeContentTab _selectedTab = HomeContentTab.top;
  int _navigationIndex = 0;

  Future<void> _refresh() async {
    await ref.read(recordListNotifierProvider.notifier).refresh();
  }

  void _handleShortcut(BuildContext context, _ShortcutAction action) {
    switch (action) {
      case _ShortcutAction.measure:
        context.pushNamed('videoImport');
        break;
      case _ShortcutAction.records:
        RecordFilterSheet.show(context);
        break;
    }
  }

  void _handleNavigationTap(BuildContext context, int index) {
    if (_navigationIndex == index) return;

    setState(() {
      _navigationIndex = index;
    });

    switch (index) {
      case 0:
        _selectedTab = HomeContentTab.top;
        break;
      case 1:
        context.pushNamed('videoImport').whenComplete(() {
          if (mounted) {
            setState(() {
              _navigationIndex = 0;
              _selectedTab = HomeContentTab.top;
            });
          }
        });
        break;
      case 2:
        setState(() {
          _selectedTab = HomeContentTab.records;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PhysiLog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => RecordFilterSheet.show(context),
          ),
        ],
      ),
      body: state.when(
        loading: () => const LoadingState(message: '記録を読み込み中...'),
        error: (message) => ErrorState(message: message, onRetry: _refresh),
        loaded: (records, hasMore, isLoadingMore) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<HomeContentTab>(
                  segments: const [
                    ButtonSegment(
                      value: HomeContentTab.top,
                      label: Text('トップ'),
                      icon: Icon(Icons.home),
                    ),
                    ButtonSegment(
                      value: HomeContentTab.records,
                      label: Text('記録'),
                      icon: Icon(Icons.list_alt),
                    ),
                    ButtonSegment(
                      value: HomeContentTab.measure,
                      label: Text('計測'),
                      icon: Icon(Icons.timer_outlined),
                    ),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (value) {
                    setState(() {
                      _selectedTab = value.first;
                    });
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildTabContent(
                      context,
                      records,
                      hasMore,
                      isLoadingMore,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.pushNamed('videoImport'),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navigationIndex,
        onDestinationSelected: (index) => _handleNavigationTap(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_call_outlined),
            selectedIcon: Icon(Icons.video_call),
            label: '計測',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '記録',
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    List<MeasurementRecord> records,
    bool hasMore,
    bool isLoadingMore,
  ) {
    switch (_selectedTab) {
      case HomeContentTab.top:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _HomeShortcutSection(
              onTap: (action) => _handleShortcut(context, action),
            ),
            const SizedBox(height: 16),
            if (records.isEmpty)
              const _EmptyRecordPlaceholder()
            else ...[
              Text('最新の記録', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...records
                  .take(3)
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RecordListTile(record: record),
                    ),
                  ),
              if (records.length > 3)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _selectedTab = HomeContentTab.records;
                    }),
                    child: const Text('もっと見る'),
                  ),
                ),
            ],
          ],
        );
      case HomeContentTab.records:
        return _RecordListView(
          records: records,
          hasMore: hasMore,
          isLoadingMore: isLoadingMore,
          onLoadMore: () =>
              ref.read(recordListNotifierProvider.notifier).loadMore(),
          onDelete: (id) =>
              ref.read(recordListNotifierProvider.notifier).deleteRecord(id),
        );
      case HomeContentTab.measure:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [_MeasurePlaceholder()],
        );
    }
  }
}

enum _ShortcutAction { measure, records }

enum HomeContentTab { top, records, measure }

class _ShortcutItem {
  const _ShortcutItem(this.label, this.action, this.description, this.icon);

  final String label;
  final _ShortcutAction action;
  final String description;
  final IconData icon;
}

class _HomeShortcutSection extends StatelessWidget {
  const _HomeShortcutSection({required this.onTap});

  final void Function(_ShortcutAction action) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const items = [
      _ShortcutItem(
        '測定する',
        _ShortcutAction.measure,
        '動画から開始/終了フレームを決めて計測',
        Icons.videocam_outlined,
      ),
      _ShortcutItem(
        '記録を絞り込む',
        _ShortcutAction.records,
        '記録一覧のフィルタと並び順を設定します',
        Icons.filter_list,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'フィジログ',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'よく使う操作',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onTap(item.action),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              foregroundColor:
                                  theme.colorScheme.onPrimaryContainer,
                              child: Icon(item.icon),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordListView extends StatelessWidget {
  const _RecordListView({
    required this.records,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onDelete,
  });

  final List<MeasurementRecord> records;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _EmptyRecordPlaceholder();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: records.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == records.length) {
          if (!isLoadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onLoadMore();
            });
          }
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final record = records[index];
        return Dismissible(
          key: ValueKey(record.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Theme.of(context).colorScheme.error,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) =>
              DeleteConfirmationDialog.show(context, record.athleteName),
          onDismissed: (_) {
            onDelete(record.id);
          },
          child: RecordListTile(record: record),
        );
      },
    );
  }
}

class _MeasurePlaceholder extends StatelessWidget {
  const _MeasurePlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '計測をはじめる',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '動画を読み込んで計測画面に進みます。測定を繰り返したい場合は下のボタンからアクセスしてください。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.pushNamed('videoImport'),
              icon: const Icon(Icons.videocam),
              label: const Text('動画を読み込む'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.pushNamed('measurement'),
              icon: const Icon(Icons.timer_outlined),
              label: const Text('記録フォームを開く'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecordPlaceholder extends StatelessWidget {
  const _EmptyRecordPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.timer_off,
      title: '記録がありません',
      subtitle: '動画を取り込んで計測し、最初の記録を作成してください',
    );
  }
}
