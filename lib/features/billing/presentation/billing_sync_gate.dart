import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:physi_log/features/billing/application/billing_controller.dart';
import 'package:physi_log/providers/app_providers.dart';

class BillingSyncGate extends ConsumerStatefulWidget {
  const BillingSyncGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BillingSyncGate> createState() => _BillingSyncGateState();
}

class _BillingSyncGateState extends ConsumerState<BillingSyncGate>
    with WidgetsBindingObserver {
  BillingController? _controller;

  bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller?.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(useFirestoreProvider);
    if (enabled) {
      ref.watch(billingControllerProvider);
    }
    final controller = enabled
        ? ref.read(billingControllerProvider.notifier)
        : null;
    if (!identical(_controller, controller)) {
      _controller?.setForeground(false);
      _controller = controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_controller, controller)) {
          controller?.setForeground(_isForeground);
        }
      });
    }
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.setForeground(false);
    super.dispose();
  }
}
