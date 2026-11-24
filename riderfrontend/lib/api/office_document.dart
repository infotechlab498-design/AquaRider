import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import 'package:riderfrontend/customerApp/customer_models.dart';

Future<void> shareOfficeDocument(OfficeDocument file) {
  if (file.contentBase64.isEmpty) {
    throw StateError('The document was empty.');
  }
  return SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          base64Decode(file.contentBase64),
          mimeType: file.contentType,
          name: file.fileName,
        ),
      ],
      text: file.fileName,
    ),
  );
}
