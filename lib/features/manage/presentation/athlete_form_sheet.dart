import 'package:flutter/material.dart';
import 'package:physi_log/app/theme/app_colors.dart';
import 'package:physi_log/app/theme/app_text_styles.dart';

class AthleteFormSheet extends StatefulWidget {
  const AthleteFormSheet({super.key, this.existingName});

  final String? existingName;

  static Future<void> show(BuildContext context, {String? name}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AthleteFormSheet(existingName: name),
    );
  }

  @override
  State<AthleteFormSheet> createState() => _AthleteFormSheetState();
}

class _AthleteFormSheetState extends State<AthleteFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;

  bool get _isEditing => widget.existingName != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingName);
    _ageController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _submit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('この機能は準備中です')),
    );
    Navigator.pop(context);
  }

  void _delete() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('この機能は準備中です')),
    );
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
            _isEditing ? '選手を編集' : '選手を追加',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '選手名'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ageController,
            decoration: const InputDecoration(labelText: '年齢'),
            keyboardType: TextInputType.number,
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
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
              child: const Text('この選手を削除'),
            ),
          ],
        ],
      ),
    );
  }
}
