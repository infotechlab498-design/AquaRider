import 'package:flutter/material.dart';

import 'typography.dart';

class AquaColors {
  static const primary = Color(0xFF1565C0);
  static const navy = Color(0xFF0A2540);
  static const background = Color(0xFFF4F8FC);
  static const card = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF536579);
  static const border = Color(0xFFDCE6F0);
  static const success = Color(0xFF1E9E5A);
  static const warning = Color(0xFFF5A623);
  static const error = Color(0xFFD64545);
  static const tint = Color(0xFFE7F2FC);
  static const successTint = Color(0xFFE5F6EC);
  static const warningTint = Color(0xFFFFF6E6);
  static const errorTint = Color(0xFFFDECEC);
}

const aquaShadow = [
  BoxShadow(color: Color(0x140A2540), blurRadius: 12, offset: Offset(0, 3)),
];

TextStyle aquaText(
  double size,
  FontWeight weight,
  Color color, {
  double height = 1.25,
  double? letterSpacing,
}) {
  return AppType.style(
    size,
    weight,
    color,
    height: height,
    letterSpacing: letterSpacing ?? 0,
  );
}

TextStyle urduText(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
}) {
  return AppType.style(size, weight, color, height: 1.35).copyWith(
    fontFamilyFallback: const [
      'Noto Nastaliq Urdu',
      'Noto Sans Arabic',
      'Noto Naskh Arabic',
    ],
  );
}

BoxDecoration aquaCard({Color? color, Color? borderColor}) {
  return BoxDecoration(
    color: color ?? AquaColors.card,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: borderColor ?? AquaColors.border),
    boxShadow: aquaShadow,
  );
}

ThemeData buildAquaTheme() {
  final text = AppType.textTheme(AquaColors.navy);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppType.family,
    scaffoldBackgroundColor: AquaColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AquaColors.primary,
      primary: AquaColors.primary,
      surface: AquaColors.card,
      error: AquaColors.error,
    ),
    textTheme: text,
  );
  final button = AppType.style(14, FontWeight.w600, Colors.white, height: 1.2);
  return base.copyWith(
    primaryTextTheme: text,
    appBarTheme: AppBarTheme(
      titleTextStyle: text.titleLarge,
      toolbarTextStyle: text.bodyMedium,
    ),
    dialogTheme: DialogThemeData(
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
    ),
    chipTheme: base.chipTheme.copyWith(labelStyle: text.labelMedium),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: text.labelMedium,
      floatingLabelStyle: text.labelMedium,
      hintStyle: text.bodyMedium?.copyWith(color: AquaColors.secondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(textStyle: button),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: AppType.style(
          13,
          FontWeight.w600,
          AquaColors.primary,
          height: 1.2,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
    ),
  );
}
