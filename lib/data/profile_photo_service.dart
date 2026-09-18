import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies a picked profile photo into the app's own documents directory so
/// it survives independently of wherever the source picker file lives, then
/// hands back the stored absolute path for saving on the user record.
class ProfilePhotoService {
  ProfilePhotoService._();

  static Future<String> save(XFile picked) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(picked.path).isEmpty
        ? '.jpg'
        : p.extension(picked.path);
    // Fixed name (not per-user) — this app only ever has one logged-in
    // account's data on disk at a time, so overwriting is correct: it
    // replaces the previous photo and avoids leaking old files.
    final dest = File(p.join(dir.path, 'profile_pic$ext'));
    await dest.writeAsBytes(await picked.readAsBytes());
    return dest.path;
  }

  static Future<void> delete(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
