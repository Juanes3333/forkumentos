import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forkumentos/features/document_viewer/presentation/document_viewer_controller.dart';

final documentViewerControllerProvider = Provider<DocumentViewerController>((
  ref,
) {
  final controller = DocumentViewerController();
  ref.onDispose(controller.dispose);
  return controller;
});
