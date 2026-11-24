int? chooseOdometerReading(String text, int? previous) {
  final candidates = <int>{};
  for (final line in text.split(RegExp(r'[\r\n]+'))) {
    final compact = line.replaceAll(RegExp(r'[\s,]'), '');
    for (final match in RegExp(r'\d{4,7}').allMatches(compact)) {
      candidates.add(int.parse(match.group(0)!));
    }
    final digits = line.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4 && digits.length <= 7) {
      candidates.add(int.parse(digits));
    }
  }
  if (candidates.isEmpty) return null;
  final values = candidates.toList();
  if (previous != null && previous > 0) {
    final near =
        values.where((value) => (value - previous).abs() <= 2000).toList()
          ..sort(
            (a, b) => (a - previous).abs().compareTo((b - previous).abs()),
          );
    if (near.isNotEmpty) return near.first;
  }
  values.sort((a, b) => b.toString().length.compareTo(a.toString().length));
  return values.first;
}
