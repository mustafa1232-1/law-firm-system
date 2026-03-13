import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveBytesAsFile({
  required Uint8List bytes,
  required String suggestedName,
}) async {
  final targetPath = await FilePicker.platform.saveFile(
    dialogTitle: 'حفظ الملف المصدر',
    fileName: suggestedName,
  );

  if (targetPath == null || targetPath.trim().isEmpty) {
    return null;
  }

  final file = File(targetPath);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
