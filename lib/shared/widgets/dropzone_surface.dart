import 'package:flutter/material.dart';
import 'package:forkumentos/core/theme/app_colors.dart';

/// A dashed rounded-rect border, drawn flush with the child's own bounds.
///
/// Reused by [DropzoneSurface] and the window-level drag overlay
/// (`AppDropTarget`) so both "drop a file here" surfaces share one visual
/// language instead of two hand-rolled borders.
final class DashedBorder extends StatelessWidget {
  const DashedBorder({
    required this.color,
    required this.borderRadius,
    this.strokeWidth = 1.4,
    this.child,
    super.key,
  });

  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        strokeWidth: strokeWidth,
        radius: borderRadius,
      ),
      child: child,
    );
  }
}

final class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;

  static const _dashWidth = 6.0;
  static const _dashGap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}

/// The empty-state "import a file" dropzone: click-to-pick, sized and
/// bordered to read as the dominant element on screen while no resource is
/// loaded yet. Shared by the template and datasource empty states so both
/// import flows (DOCX / CSV·XLSX) look and behave identically.
final class DropzoneSurface extends StatefulWidget {
  const DropzoneSurface({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.onImport,
    this.actionTooltip,
    super.key,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final IconData actionIcon;

  /// Null disables both the button and the whole-surface tap target.
  final VoidCallback? onImport;
  final String? actionTooltip;

  static const double minHeight = 220;

  @override
  State<DropzoneSurface> createState() => _DropzoneSurfaceState();
}

final class _DropzoneSurfaceState extends State<DropzoneSurface> {
  var _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = widget.onImport != null;
    final highlighted = enabled && _isHovered;

    Widget button = FilledButton.icon(
      onPressed: widget.onImport,
      icon: Icon(widget.actionIcon),
      label: Text(widget.actionLabel),
    );
    final tooltip = widget.actionTooltip;
    if (tooltip != null) {
      button = Tooltip(message: tooltip, child: button);
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onImport,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: DropzoneSurface.minHeight,
          ),
          decoration: BoxDecoration(
            color: highlighted
                ? Color.alphaBlend(
                    colors.accent.withValues(alpha: 0.06),
                    colors.backgroundSecondary,
                  )
                : colors.backgroundSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DashedBorder(
            color: highlighted ? colors.accent : colors.border,
            borderRadius: 12,
            strokeWidth: highlighted ? 1.6 : 1.2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(widget.icon, size: 44, color: colors.accent),
                      const SizedBox(height: 16),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      button,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
