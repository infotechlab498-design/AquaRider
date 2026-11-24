import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> deliverDispatchManifest(
  Uint8List bytes,
  String filename, {
  required bool download,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(file.path, mimeType: 'application/pdf', name: filename),
      ],
      title: download ? 'Dispatch manifest' : 'Print dispatch manifest',
      subject: filename,
    ),
  );
}
