import 'package:flutter/material.dart';

/// Locked V1 colors for the enterprise admin workspace.
class AdminTokens {
  static const primary = Color(0xFF1565C0);
  static const button = Color(0xFF1673D1);
  static const secondary = Color(0xFF37474F);
  static const background = Color(0xFFF4F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF17212B);
  static const textSecondary = Color(0xFF475569);
  static const border = Color(0xFF64748B);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFF8A4B00);
  static const warningBg = Color(0xFFFFF4D6);
  static const error = Color(0xFFC62828);
  static const errorBg = Color(0xFFFFF1F0);

  /// Login left panel — deep navy matching the design (not flat black).
  static const navy = Color(0xFF0B1C30);
  /// Top-left wash of the login promo gradient.
  static const navyGlow = Color(0xFF1B3A5C);
  static const navyDeep = Color(0xFF07131F);
  static const navyRaised = Color(0xFF152536);
  static const line = Color(0xFFD8E0EA);
  static const field = Color(0xFFF8FAFC);
  static const page = Color(0xFFF4F7FB);
  static const promoMuted = Color(0xFF8B9BB0);
  static const promoTitle = Color(0xFFB8C4D4);

  static const loginPromoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyGlow, navy, navyDeep],
    stops: [0.0, 0.48, 1.0],
  );
  static const successSoft = Color(0xFFE7F6EC);
  static const primarySoft = Color(0xFFE8F2FC);
  static const sidebar = Color(0xFF0E1726);
  static const sidebarMuted = Color(0xFF93A4B8);

  static const cardShadow = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 40, offset: Offset(0, 18)),
  ];

  static const softShadow = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, 6)),
  ];
}

TextStyle adminType(
  double size,
  FontWeight weight,
  Color color, {
  double height = 1.35,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

ButtonStyle adminPrimaryButton({
  Color color = AdminTokens.button,
  double radius = 10,
}) {
  return FilledButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFFB9D4F2),
    disabledForegroundColor: Colors.white,
    elevation: 0,
    minimumSize: const Size.fromHeight(48),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    textStyle: adminType(14.5, FontWeight.w600, Colors.white, height: 1.2),
  );
}

void showAdminNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: adminType(13, FontWeight.w500, Colors.white, height: 1.3),
      ),
    ),
  );
}

ButtonStyle adminOutlineButton() {
  return OutlinedButton.styleFrom(
    foregroundColor: AdminTokens.text,
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    side: const BorderSide(color: AdminTokens.line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: adminType(13, FontWeight.w600, AdminTokens.text, height: 1.2),
  );
}
