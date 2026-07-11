import 'dart:io';

/// Opens [folderPath] in the system file manager.
Future<void> openFolderInExplorer(String folderPath) async {
  if (Platform.isWindows) {
    await Process.start('explorer', <String>[folderPath]);
  }
}

/// Reveals [filePath] in the system file manager (selected when supported).
Future<void> showFileInExplorer(String filePath) async {
  if (Platform.isWindows) {
    await Process.start('explorer', <String>['/select,$filePath']);
  }
}
