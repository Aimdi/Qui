import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// The folder media is auto-saved into, addressed as an Android document tree
/// rather than a filesystem path.
///
/// Writing to a shared-storage path with `File` stopped being allowed in
/// Android 11: the app can be told a folder's name without being given access
/// to it, which is why saving used to fail with
/// `PathAccessException … Operation not permitted, errno = 1` no matter which
/// permissions were granted. A document tree carries the grant with it.
///
/// Android-only: the `browser_resolver` channel is implemented by the Android
/// embedding alone. Desktop uses a plain directory path (`optionDownloadPath`)
/// picked via `pickDirectoryPath` in `desktop_files.dart` and never calls this.
class DownloadDirectory {
  static const MethodChannel _channel = MethodChannel('browser_resolver');

  /// Lets tests exercise the channel calls on a host platform; the guards
  /// otherwise short-circuit everywhere the Android embedding is absent.
  @visibleForTesting
  static bool debugTreatAsAndroid = false;

  static bool get _isAndroid => debugTreatAsAndroid || Platform.isAndroid;

  /// Opens the system folder picker and keeps write access to the result.
  /// Returns the tree URI, or null when the user backed out.
  static Future<String?> pick() async {
    if (!_isAndroid) {
      return null;
    }
    return _channel.invokeMethod<String>('pickDownloadDirectory');
  }

  /// Whether [treeUri] is still writable — the folder can be deleted, or the
  /// grant revoked, long after it was chosen.
  static Future<bool> hasAccess(String? treeUri) async {
    if (!_isAndroid) {
      return false;
    }
    if (treeUri == null || treeUri.isEmpty) {
      return false;
    }
    final granted = await _channel.invokeMethod<bool>('hasDownloadDirectoryAccess', {'treeUri': treeUri});
    return granted ?? false;
  }

  /// Writes [bytes] into the chosen folder. Returns the saved document's URI.
  static Future<String?> save({
    required String treeUri,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!_isAndroid) {
      throw UnsupportedError('SAF document trees only exist on Android; write to a filesystem path instead');
    }
    return _channel.invokeMethod<String>('saveToDownloadDirectory', {
      'treeUri': treeUri,
      'fileName': fileName,
      'mimeType': mimeTypeFor(fileName),
      'bytes': bytes,
    });
  }

  /// A readable folder name for the settings row: a tree URI ends in a document
  /// id like `primary:Pictures/QuaX`, which is the part worth showing.
  static String displayName(String treeUri) {
    // The document id must be taken as a whole path segment before decoding:
    // it encodes its own separators (`primary%3APictures%2FQuaX`), so decoding
    // first and splitting on "/" would throw away the parent folder.
    final uri = Uri.tryParse(treeUri);
    final documentId =
        uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : Uri.decodeFull(treeUri);

    final withoutVolume = documentId.contains(':') ? documentId.split(':').last : documentId;
    return withoutVolume.isEmpty ? documentId : withoutVolume;
  }
}

/// Content type from the file's extension. Android stores this with the
/// document, and it decides whether the gallery shows the file at all.
String mimeTypeFor(String fileName) {
  switch (p.extension(fileName).toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    case '.mp4':
      return 'video/mp4';
    case '.m4v':
      return 'video/x-m4v';
    case '.mov':
      return 'video/quicktime';
    case '.webm':
      return 'video/webm';
    case '.mp3':
      return 'audio/mpeg';
    case '.m4a':
      return 'audio/mp4';
    default:
      return 'application/octet-stream';
  }
}
