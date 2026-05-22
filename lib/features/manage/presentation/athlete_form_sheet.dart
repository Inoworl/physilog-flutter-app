import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/manage/application/athlete_list_notifier.dart';
import 'package:physi_log/features/records/application/record_list_notifier.dart';
import 'package:physi_log/models/athlete.dart';
import 'package:physi_log/shared/constants/app_constants.dart';

class AthleteFormSheet extends ConsumerStatefulWidget {
  const AthleteFormSheet({super.key, this.athlete});

  final Athlete? athlete;

  static Future<void> show(BuildContext context, {Athlete? athlete}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AthleteFormSheet(athlete: athlete),
    );
  }

  @override
  ConsumerState<AthleteFormSheet> createState() => _AthleteFormSheetState();
}

class _AthleteFormSheetState extends ConsumerState<AthleteFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  bool _isSubmitting = false;

  bool get _isEditing => widget.athlete != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.athlete?.name);
    _ageController = TextEditingController(
      text: widget.athlete?.age?.toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);

    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('選手名を入力してください')));
      return;
    }
    if (name.length > AppConstants.maxAthleteNameLength) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('${AppConstants.maxAthleteNameLength}文字以内で入力してください'),
        ),
      );
      return;
    }
    if (ageText.isNotEmpty && age == null) {
      messenger.showSnackBar(const SnackBar(content: Text('年齢は数値で入力してください')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isEditing) {
        await ref
            .read(athleteListNotifierProvider.notifier)
            .updateAthlete(athleteId: widget.athlete!.id, name: name, age: age);
      } else {
        await ref
            .read(athleteListNotifierProvider.notifier)
            .addAthlete(name, age: age);
      }
      ref.invalidate(recordListNotifierProvider);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_isEditing ? '選手を更新しました' : '選手を登録しました')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _delete() async {
    final target = widget.athlete;
    if (target == null || _isSubmitting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選手を削除'),
        content: Text('${target.name}を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(athleteListNotifierProvider.notifier)
          .deleteAthlete(target.id);
      ref.invalidate(recordListNotifierProvider);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('選手を削除しました')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? '選手を編集' : '選手を追加',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '選手名'),
            textInputAction: TextInputAction.next,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ageController,
            decoration: const InputDecoration(labelText: '年齢（任意）'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? '更新する' : '登録する'),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isSubmitting ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('この選手を削除'),
            ),
          ],
        ],
      ),
    );
  }
}
