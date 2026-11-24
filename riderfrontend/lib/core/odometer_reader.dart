import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads a mileage from an odometer photo. The phone recognizes the digits;
/// the shift stores both that reading and the picture.
class OdometerReader {
  static Future<int?> Function(String path)? override;

  static Future<int?> read(String path) async {
    final replacement = override;
    if (replacement != null) return replacement(path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return pickReading(recognized.text);
    } finally {
      await recognizer.close();
    }
  }

  /// Chooses the digit group that looks like a vehicle odometer.
  static int? pickReading(String raw) {
    final groups = RegExp(r'\d+')
        .allMatches(raw)
        .map((match) => match.group(0)!)
        .where((group) => group.length >= 4 && group.length <= 7)
        .toList();
    if (groups.isNotEmpty) {
      groups.sort((a, b) => _score(b).compareTo(_score(a)));
      return int.tryParse(groups.first);
    }

    final compact = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (compact.length >= 4 && compact.length <= 7) {
      return int.tryParse(compact);
    }
    return null;
  }

  static int _score(String digits) {
    if (digits.length == 5 || digits.length == 6) return digits.length + 10;
    return digits.length;
  }
}
