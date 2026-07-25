import 'dart:io';

/// Deletes only app-created temporary image files after they have reached the
/// backend. Gallery originals are never touched.
class TemporaryImageCleanup {
  TemporaryImageCleanup._();

  static Future<void> deleteIfManaged(File image) async {
    final filePath = image.absolute.path.replaceAll(r'\', '/');
    final isTemporary =
        filePath.contains('/cache/') ||
        filePath.contains('/tmp/') ||
        filePath.contains('/temporary/');
    if (!isTemporary) return;

    try {
      if (await image.exists()) await image.delete();
    } catch (_) {
      // Storage cleanup must never affect an upload or UI flow.
    }
  }
}
