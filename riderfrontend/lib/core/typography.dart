import 'package:flutter/material.dart';

/// The only typography control for AquaRider.
///
/// Screens ask for a size and a weight. The numbers they receive come from
/// [sizes] and [weightFor] in this file. Edit those two places to change
/// headings, values, labels, and body text on every screen.
class AppType {
  static const family = 'Noto Sans';

  /// Requested size, in pixels, to the size that is actually drawn.
  ///
  /// Taglines (10–12) and headings step down again so the page reads lighter.
  static const sizes = <int, double>{
    9: 9,
    10: 10,
    11: 10,
    12: 11,
    13: 12,
    14: 12,
    15: 13,
    16: 14,
    18: 15,
    20: 16,
    22: 17,
    24: 18,
    26: 20,
    28: 20,
    32: 24,
  };

  static double sizeFor(double requested) {
    return sizes[requested.round()] ??
        (requested >= 16 ? requested - 2 : requested);
  }

  /// Tracked taglines stay medium. Large headings and values stay semi-bold
  /// at most, and the biggest titles drop to medium.
  static FontWeight weightFor(
    double requestedSize,
    FontWeight weight, {
    double letterSpacing = 0,
  }) {
    final heavy = weight.value >= FontWeight.w700.value;
    if (letterSpacing >= 0.2 && requestedSize <= 13) return FontWeight.w500;
    if (heavy && requestedSize >= 22) return FontWeight.w500;
    if (heavy) return FontWeight.w600;
    if (weight == FontWeight.w600 && requestedSize >= 22) {
      return FontWeight.w500;
    }
    return weight;
  }

  /// Uppercase taglines were tracked widely. Keep a little air, not a shout.
  static double trackingFor(double letterSpacing, double requestedSize) {
    if (letterSpacing >= 0.4 && requestedSize <= 13) return 0.3;
    return letterSpacing;
  }

  static TextStyle style(
    double size,
    FontWeight weight,
    Color color, {
    double? lineHeight,
    double? height,
    double letterSpacing = 0,
  }) {
    final next = sizeFor(size);
    return TextStyle(
      fontFamily: family,
      fontSize: next,
      fontWeight: weightFor(size, weight, letterSpacing: letterSpacing),
      color: color,
      height: height ?? (lineHeight == null ? null : lineHeight / size),
      letterSpacing: trackingFor(letterSpacing, size),
    );
  }

  /// Material styles for dialogs, buttons, fields, lists, and app bars.
  /// Each role still passes through [sizes] and [weightFor].
  static TextTheme textTheme(Color ink) {
    TextStyle role(double size, FontWeight weight, double line) {
      return style(size, weight, ink, height: line);
    }

    return TextTheme(
      displaySmall: role(28, FontWeight.w700, 1.2),
      headlineMedium: role(26, FontWeight.w700, 1.22),
      headlineSmall: role(22, FontWeight.w700, 1.25),
      titleLarge: role(18, FontWeight.w700, 1.3),
      titleMedium: role(16, FontWeight.w600, 1.3),
      titleSmall: role(14, FontWeight.w600, 1.3),
      bodyLarge: role(14, FontWeight.w400, 1.4),
      bodyMedium: role(13, FontWeight.w400, 1.4),
      bodySmall: role(12, FontWeight.w400, 1.35),
      labelLarge: role(14, FontWeight.w600, 1.2),
      labelMedium: role(12, FontWeight.w500, 1.2),
      labelSmall: role(11, FontWeight.w500, 1.2),
    );
  }
}

TextStyle routeType(
  double size,
  FontWeight weight,
  Color color,
  double lineHeight, [
  double tracking = 0,
]) {
  return AppType.style(
    size,
    weight,
    color,
    lineHeight: lineHeight,
    letterSpacing: tracking,
  );
}
