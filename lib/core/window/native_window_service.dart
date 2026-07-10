import 'dart:async';

import 'package:forkumentos/core/window/window_service.dart';
import 'package:window_manager/window_manager.dart';

final class NativeWindowService implements WindowService {
  final List<Future<void> Function()> _closeListeners =
      <Future<void> Function()>[];

  _ForwardingWindowListener? _listener;

  @override
  Future<void> setTitle(String title) => windowManager.setTitle(title);

  @override
  Future<void> setPreventClose(bool value) =>
      windowManager.setPreventClose(value);

  @override
  void addCloseListener(Future<void> Function() onCloseRequested) {
    _closeListeners.add(onCloseRequested);
    _listener ??= _ForwardingWindowListener(_notifyCloseListeners)
      ..registerWith(windowManager);
  }

  @override
  Future<void> destroy() => windowManager.destroy();

  Future<void> _notifyCloseListeners() async {
    for (final listener in _closeListeners) {
      await listener();
    }
  }
}

final class _ForwardingWindowListener extends WindowListener {
  _ForwardingWindowListener(this._onWindowClose);

  final Future<void> Function() _onWindowClose;

  void registerWith(WindowManager manager) => manager.addListener(this);

  @override
  void onWindowClose() {
    unawaited(_onWindowClose());
  }
}
