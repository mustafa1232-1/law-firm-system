import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.io) 'file_download_io.dart'
    as impl;

Future<String?> saveBytesAsFile({
  required Uint8List bytes,
  required String suggestedName,
}) {
  return impl.saveBytesAsFile(bytes: bytes, suggestedName: suggestedName);
}
