import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Bridges workbench view tools to DocumentViewerScreen zoom/fit actions.
final class DocumentViewerController extends ChangeNotifier {
  VoidCallback? _zoomIn;
  VoidCallback? _zoomOut;
  VoidCallback? _fitWidth;
  VoidCallback? _fitPage;
  void Function(double scale)? _setScale;
  int _zoomPercentage = 100;
  bool _isFitWidth = false;
  bool _isFitPage = false;
  bool _attached = false;
  bool _notifyScheduled = false;
  bool _disposed = false;

  int get zoomPercentage => _zoomPercentage;
  bool get isFitWidth => _isFitWidth;
  bool get isFitPage => _isFitPage;
  bool get isAttached => _attached;

  void attach({
    required VoidCallback zoomIn,
    required VoidCallback zoomOut,
    required VoidCallback fitWidth,
    required VoidCallback fitPage,
    required void Function(double scale) setScale,
  }) {
    if (_disposed) {
      return;
    }
    _zoomIn = zoomIn;
    _zoomOut = zoomOut;
    _fitWidth = fitWidth;
    _fitPage = fitPage;
    _setScale = setScale;
    _attached = true;
    _safeNotify();
  }

  void detach() {
    _zoomIn = null;
    _zoomOut = null;
    _fitWidth = null;
    _fitPage = null;
    _setScale = null;
    _attached = false;
    if (!_disposed) {
      _safeNotify();
    }
  }

  void updateViewState({
    required int zoomPercentage,
    required bool isFitWidth,
    required bool isFitPage,
  }) {
    if (_disposed) {
      return;
    }
    if (_zoomPercentage == zoomPercentage &&
        _isFitWidth == isFitWidth &&
        _isFitPage == isFitPage) {
      return;
    }
    _zoomPercentage = zoomPercentage;
    _isFitWidth = isFitWidth;
    _isFitPage = isFitPage;
    _safeNotify();
  }

  void zoomIn() => _zoomIn?.call();
  void zoomOut() => _zoomOut?.call();
  void fitWidth() => _fitWidth?.call();
  void fitPage() => _fitPage?.call();
  void setScale(double scale) => _setScale?.call(scale);

  @override
  void dispose() {
    _disposed = true;
    _zoomIn = null;
    _zoomOut = null;
    _fitWidth = null;
    _fitPage = null;
    _setScale = null;
    _attached = false;
    super.dispose();
  }

  /// Defers listener notification when the widget tree is mid-build
  /// (viewer attach runs from initState under the workbench).
  void _safeNotify() {
    if (_disposed) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }
}
