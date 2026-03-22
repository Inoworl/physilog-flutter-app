import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/app/router.dart';
import 'package:physi_log/app/theme/app_theme.dart';
import 'package:physi_log/providers/app_providers.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dataStoreModeProvider).name;
    final userId = ref.watch(currentUserIdProvider) ?? 'null';

    return MaterialApp.router(
      title: 'PhysiLog',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final body = child ?? const SizedBox.shrink();
        if (!kDebugMode) {
          return body;
        }

        return Stack(
          children: [
            body,
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      'store=$mode uid=$userId',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
