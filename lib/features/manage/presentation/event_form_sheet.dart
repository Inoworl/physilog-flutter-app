import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';
import 'package:physi_log/features/manage/application/event_list_notifier.dart';
import 'package:physi_log/models/event.dart';
import 'package:physi_log/shared/constants/app_constants.dart';

class EventFormSheet extends ConsumerStatefulWidget {
  const EventFormSheet({super.key, this.event});

  final Event? event;

  static Future<void> show(BuildContext context, {Event? event}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventFormSheet(event: event),
    );
  }

  @override
  ConsumerState<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends ConsumerState<EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSubmitting = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event?.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    final notifier = ref.read(eventListNotifierProvider.notifier);
    try {
      if (_isEditing) {
        await notifier.updateEvent(
          eventId: widget.event!.id,
          name: _nameController.text.trim(),
        );
      } else {
        await notifier.addEvent(_nameController.text.trim());
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.event == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(eventListNotifierProvider.notifier)
          .deleteEvent(widget.event!.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('削除に失敗しました: $e')));
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? '種目を編集' : '種目を追加',
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '種目名'),
              textInputAction: TextInputAction.done,
              maxLength: AppConstants.maxEventTypeLength,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return '種目名を入力してください';
                }
                if (trimmed.length > AppConstants.maxEventTypeLength) {
                  return '${AppConstants.maxEventTypeLength}文字以内で入力してください';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isEditing ? '更新する' : '登録する'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('この種目を削除'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
