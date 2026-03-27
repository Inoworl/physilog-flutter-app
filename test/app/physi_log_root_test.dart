import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:physi_log/app/physi_log_root.dart';
import 'package:physi_log/providers/app_providers.dart';

void main() {
  testWidgets('PhysiLogRootはprovider overrideを子孫へ伝播できる', (tester) async {
    await tester.pumpWidget(
      PhysiLogRoot(
        overrides: [
          currentUserIdProvider.overrideWithValue('integration-user'),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            final userId = ref.watch(currentUserIdProvider);
            return MaterialApp(home: Scaffold(body: Text(userId ?? 'null')));
          },
        ),
      ),
    );

    await tester.pump();

    expect(find.text('integration-user'), findsOneWidget);
  });
}
