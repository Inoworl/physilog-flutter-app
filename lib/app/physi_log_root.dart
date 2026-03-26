import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/app/app.dart';

class PhysiLogRoot extends StatelessWidget {
  const PhysiLogRoot({super.key, this.overrides = const [], this.child});

  final List<Override> overrides;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(overrides: overrides, child: child ?? const App());
  }
}
