import 'package:flutter/material.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/manage/presentation/athlete_form_sheet.dart';
import 'package:physi_log/features/manage/presentation/event_form_sheet.dart';

class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  static const _athletes = ['田中太郎', '鈴木花子', '佐藤一郎'];
  static const _events = ['50m走', '100m走', '立ち幅跳び', '20mシャトルラン'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: '選手',
                onAdd: () => AthleteFormSheet.show(context),
              ),
              const SizedBox(height: 8),
              const _AthleteList(athletes: _athletes),
              const SizedBox(height: 32),
              _SectionHeader(
                title: '種目',
                onAdd: () => EventFormSheet.show(context),
              ),
              const SizedBox(height: 8),
              const _EventList(events: _events),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        const Spacer(),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('追加'),
        ),
      ],
    );
  }
}

class _AthleteList extends StatelessWidget {
  const _AthleteList({required this.athletes});

  final List<String> athletes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < athletes.length; i++) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                child: Text(athletes[i].characters.first),
              ),
              title: Text(athletes[i], style: AppTextStyles.cardTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => AthleteFormSheet.show(context, name: athletes[i]),
            ),
            if (i < athletes.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events});

  final List<String> events;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++) ...[
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: Text(events[i], style: AppTextStyles.cardTitle),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    EventFormSheet.show(context, name: events[i]);
                  } else if (value == 'delete') {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('この機能は準備中です')));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('編集')),
                  PopupMenuItem(value: 'delete', child: Text('削除')),
                ],
              ),
            ),
            if (i < events.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
