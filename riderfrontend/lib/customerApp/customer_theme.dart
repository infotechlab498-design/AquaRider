import 'package:flutter/material.dart';

const customerPrimary = Color(0xFF2563EB);
const customerNavy = Color(0xFF0F172A);
const customerPage = Color(0xFFF4F7FB);
const customerSurface = Color(0xFFFFFFFF);
const customerSuccess = Color(0xFF15803D);
const customerWarning = Color(0xFFB45309);
const customerError = Color(0xFFB91C1C);
const customerLine = Color(0xFFD8E0EA);
const customerMuted = Color(0xFF475569);

TextStyle customerType(double size, FontWeight weight, Color color, {double height = 1.35}) {
  return TextStyle(
    fontFamily: 'Noto Sans',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

ButtonStyle customerPrimaryButton() {
  return FilledButton.styleFrom(
    backgroundColor: customerPrimary,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 48),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: customerType(15, FontWeight.w700, Colors.white),
  );
}

BoxDecoration customerCardDecoration() {
  return BoxDecoration(
    color: customerSurface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: customerLine),
    boxShadow: const [
      BoxShadow(color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, 6)),
    ],
  );
}

class CustomerCard extends StatelessWidget {
  const CustomerCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: customerCardDecoration(),
      child: child,
    );
  }
}

InputDecoration customerField(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: customerSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: customerLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: customerLine),
    ),
  );
}

Color customerStatusColor(String status) {
  return switch (status) {
    'Delivered' || 'Paid' || 'Applied' || 'Approved' || 'Active' => customerSuccess,
    'Paused' || 'Pending' || 'UnderReview' || 'MoreInformationRequired' || 'Partially Paid' || 'Unpaid' || 'Recorded' => customerWarning,
    'Cancelled' || 'Rejected' || 'Missed' || 'Suspended' || 'Failed' => customerError,
    _ => customerPrimary,
  };
}
