import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// True when running as a desktop (non-mobile) target.
bool get isDesktop =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Pick a single existing file. Returns its absolute path, or null if cancelled.
Future<String?> pickOpenFilePath({
  List<String>? allowedExtensions,
  String? dialogTitle,
}) async {
  final result = await FilePicker.pickFiles(
    type: allowedExtensions == null ? FileType.any : FileType.custom,
    allowedExtensions: allowedExtensions,
    dialogTitle: dialogTitle,
    allowMultiple: false,
    withData: false,
  );
  if (result == null || result.files.isEmpty) {
    return null;
  }
  return result.files.single.path;
}

/// Save [data] to a user-chosen location.
///
/// On desktop, [FilePicker.saveFile] returns a path; we write the bytes there.
/// Returns the saved path, or null if the user cancelled.
Future<String?> saveBytesToPickedFile({
  required String fileName,
  required Uint8List data,
  String? dialogTitle,
}) async {
  if (isDesktop) {
    final path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
    );
    if (path == null) {
      return null;
    }
    final file = File(path);
    await file.writeAsBytes(data, flush: true);
    return file.path;
  }

  // Mobile: still go through file_picker when available.
  final path = await FilePicker.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    bytes: data,
  );
  return path;
}

/// Prefer the user's Downloads folder on desktop; fall back to documents.
Future<String> defaultDownloadDirectory() async {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home != null) {
      final downloads = Directory(p.join(home, 'Downloads'));
      if (await downloads.exists()) {
        return downloads.path;
      }
    }
  }
  final docs = await getApplicationDocumentsDirectory();
  return docs.path;
}
