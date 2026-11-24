import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

Future<void> deliverDispatchManifest(
  Uint8List bytes,
  String filename, {
  required bool download,
}) async {
  final blob = Blob(
    [bytes.toJS].toJS,
    BlobPropertyBag(type: 'application/pdf'),
  );
  final url = URL.createObjectURL(blob);
  if (download) {
    final anchor = HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';
    document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return;
  }
  window.open(url, '_blank');
}
