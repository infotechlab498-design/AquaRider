import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'odometer_reading.dart';

class OdometerShot {
  const OdometerShot({required this.bytes, required this.reading});

  final Uint8List bytes;
  final int? reading;
}

Future<Uint8List?> takeInspectionPhoto() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
    maxWidth: 1280,
    imageQuality: 70,
  );
  if (file == null) return null;
  return file.readAsBytes();
}

Future<OdometerShot?> takeOdometerPhoto(int? previous) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.rear,
    maxWidth: 1600,
    imageQuality: 70,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(
      InputImage.fromFilePath(file.path),
    );
    return OdometerShot(
      bytes: bytes,
      reading: chooseOdometerReading(result.text, previous),
    );
  } finally {
    await recognizer.close();
  }
}
