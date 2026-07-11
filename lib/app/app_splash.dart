import 'package:flutter/material.dart';
import 'package:forkumentos/shared/widgets/forkumentos_logo.dart';

/// Brief startup gate with theme-aware logo. Not a route.
/// Keeps [child] mounted under the overlay so the router is not remounted.
final class AppSplash extends StatefulWidget {
  const AppSplash({
    required this.child,
    this.duration = const Duration(milliseconds: 900),
    super.key,
  });

  final Widget child;
  final Duration duration;

  @override
  State<AppSplash> createState() => _AppSplashState();
}

final class _AppSplashState extends State<AppSplash> {
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    // Skip the gate under widget tests so pumpAndSettle sees the real app.
    final skipDelay = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    _showSplash = !skipDelay && widget.duration > Duration.zero;
    if (!_showSplash) {
      return;
    }
    Future<void>.delayed(widget.duration, () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: const Center(child: ForkumentosLogo(height: 120)),
        ),
      ],
    );
  }
}
