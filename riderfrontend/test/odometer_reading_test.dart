import 'package:flutter_test/flutter_test.dart';
import 'package:riderfrontend/core/odometer_reading.dart';

void main() {
  test('reads a plain odometer line', () {
    expect(chooseOdometerReading('45820 KM', 45820), 45820);
  });

  test('joins digits that the camera splits', () {
    expect(chooseOdometerReading('4 5 8 2 1', 45820), 45821);
  });

  test('prefers the number nearest the last meter', () {
    expect(chooseOdometerReading('2026\n45830', 45820), 45830);
  });

  test('ignores short numbers', () {
    expect(chooseOdometerReading('KM 12', 45820), isNull);
  });
}
