import 'package:flutter/material.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';

class EventFormSheet extends StatefulWidget {
  const EventFormSheet({super.key, this.existingName});

  final String? existingName;

  static Future<void> show(BuildContext context, {String? name}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventFormSheet(existingName: name),
    );
  }

  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  late final TextEditingController _nameController;

  bool get _isEditing => widget.existingName != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('この機能は準備中です')));
    Navigator.pop(context);
  }

  void _delete() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('この機能は準備中です')));
    Navigator.pop(context);
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
            _isEditing ? '種目を編集' : '種目を追加',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '種目名'),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            child: Text(_isEditing ? '更新する' : '登録する'),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('この種目を削除'),
            ),
          ],
        ],
      ),
    );
  }
}
