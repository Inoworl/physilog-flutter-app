import 'package:flutter/material.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  const DeleteConfirmationDialog({super.key, required this.athleteName});

  final String athleteName;

  static Future<bool?> show(BuildContext context, String athleteName) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DeleteConfirmationDialog(athleteName: athleteName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('記録を削除'),
      content: Text('$athleteNameの記録を削除しますか？\nこの操作は取り消せません。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('削除'),
        ),
      ],
    );
  }
}
