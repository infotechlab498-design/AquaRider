import 'dart:typed_data';

Future<void> deliverDispatchManifest(
  Uint8List bytes,
  String filename, {
  required bool download,
}) async {
  throw UnsupportedError('PDF delivery is not available on this platform.');
}
