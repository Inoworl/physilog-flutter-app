import 'package:flutter/material.dart';

/// Displays a plan upgrade prompt and returns whether the user chose to view
/// the available plans.
Future<bool> showUpgradePromptDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final shouldViewPlans = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('プランを見る'),
        ),
      ],
    ),
  );

  return shouldViewPlans ?? false;
}
