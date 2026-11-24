import 'package:flutter/material.dart';

import '../../data/admin_format.dart';
import '../../data/admin_login_preview.dart';
import '../../theme/admin_tokens.dart';

/// Left promo pane for enterprise login. KPI cards bind to live ledger totals.
class EnterprisePromoPanel extends StatelessWidget {
  const EnterprisePromoPanel({this.preview, this.loading = false, super.key});

  final AdminLoginPreview? preview;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final billed = preview?.todaysBilledSales ?? 0;
    final cash = preview?.cashReconciled ?? 0;
    final change = preview?.billedChangePercent;
    final dropsBalanced = preview?.dropsBalanced ?? 0;
    final dropsTotal = preview?.dropsTotal ?? 0;
    final changeNote = change == null
        ? (preview == null
            ? 'Waiting for ledger…'
            : 'No billed sales recorded yesterday')
        : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% vs yesterday route';
    final changeColor = change == null
        ? AdminTokens.promoMuted
        : change >= 0
        ? const Color(0xFF4ADE80)
        : const Color(0xFFF87171);

    return Stack(
      children: [
        // Soft radial wash at top-left (matches design glow over navy).
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.92, -0.95),
                  radius: 1.35,
                  colors: [
                    const Color(0xFF2A4A6E).withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 40, 36, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC5CED8).withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ENTERPRISE CLOUD SUITE',
                      style: adminType(
                        10,
                        FontWeight.w600,
                        const Color(0xFFD0D8E0),
                        height: 1.2,
                        letterSpacing: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text.rich(
                TextSpan(
                  style: adminType(
                    38,
                    FontWeight.w700,
                    Colors.white,
                    height: 1.15,
                    letterSpacing: -0.7,
                  ),
                  children: const [
                    TextSpan(text: 'Your Entire Delivery\nOperation.\n'),
                    TextSpan(
                      text: 'Under Control.',
                      style: TextStyle(
                        color: AdminTokens.promoTitle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  'Monitor your riders, customers, doorstep deliveries, collections, and automated multi-stop reconciliation from one rugged, intelligent workspace.',
                  style: adminType(
                    14.5,
                    FontWeight.w400,
                    AdminTokens.promoMuted,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: "TODAY'S BILLED SALES",
                        value: formatPkr(billed),
                        note: changeNote,
                        noteColor: changeColor,
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        label: 'CASH RECONCILED',
                        value: formatPkr(cash),
                        note: dropsTotal == 0
                            ? 'No route drops scheduled today'
                            : '$dropsBalanced of $dropsTotal Drops Balanced',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 28),
              Text(
                preview?.scopeNote.isNotEmpty == true
                    ? preview!.scopeNote
                    : 'Login preview uses the same sales, cash collection and route-stop ledgers as Sales / Collections / Day Close.',
                style: adminType(
                  11.5,
                  FontWeight.w400,
                  AdminTokens.promoMuted.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AdminTokens.promoMuted.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Encrypted Cloud Ledger',
                    style: adminType(
                      12,
                      FontWeight.w500,
                      AdminTokens.promoMuted,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Icon(
                    Icons.sync_rounded,
                    size: 14,
                    color: AdminTokens.promoMuted.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Field Synced',
                    style: adminType(
                      12,
                      FontWeight.w500,
                      AdminTokens.promoMuted,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    this.noteColor = AdminTokens.promoMuted,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color noteColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AdminTokens.navyRaised.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: adminType(
                    10,
                    FontWeight.w600,
                    AdminTokens.promoMuted,
                    height: 1.2,
                    letterSpacing: 0.55,
                  ),
                ),
              ),
              Icon(icon, size: 15, color: const Color(0xFFE8EEF5)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: adminType(22, FontWeight.w700, Colors.white, height: 1.1),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: adminType(12, FontWeight.w500, noteColor, height: 1.3),
          ),
        ],
      ),
    );
  }
}
