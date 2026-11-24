import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/onboarding_models.dart';

import '../../theme/admin_tokens.dart';

class OnboardingReadinessBanner extends StatelessWidget {
  const OnboardingReadinessBanner({
    required this.readiness,
    required this.onSkip,
    super.key,
  });

  final OnboardingReadiness? readiness;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final ready = readiness?.ready == true;
    final title = (readiness?.title.isNotEmpty ?? false)
        ? readiness!.title
        : 'Operational day readiness';
    final body = (readiness?.body.isNotEmpty ?? false)
        ? readiness!.body
        : 'The server did not return a readiness report.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ready ? AdminTokens.successSoft : AdminTokens.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ready ? const Color(0xFFB7DFC0) : const Color(0xFFD3E4F6),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            ready ? Icons.verified_outlined : Icons.event_note_outlined,
            color: ready ? AdminTokens.success : AdminTokens.primary,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRE-FLIGHT CHECKLIST',
                  style: adminType(
                    11,
                    FontWeight.w700,
                    AdminTokens.primary,
                    height: 1.2,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: adminType(
                    18,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: adminType(
                    13.5,
                    FontWeight.w400,
                    AdminTokens.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onSkip,
            style: adminOutlineButton().copyWith(
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
            ),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Skip to Admin Dashboard'),
          ),
        ],
      ),
    );
  }
}

class OnboardingInfoCards extends StatelessWidget {
  const OnboardingInfoCards({required this.overview, super.key});

  final OnboardingOverview? overview;

  @override
  Widget build(BuildContext context) {
    final facility = overview?.facility;
    final compliance = overview?.compliance;
    final device = overview?.device;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 900;
        final cards = [
          _InfoCard(
            icon: Icons.warehouse_outlined,
            title: 'Registered facility',
            status: facility?.status,
            lines: [
              _line(facility?.name),
              _line(facility?.address),
              facility?.assignedItems == null
                  ? 'Assigned items not reported'
                  : 'Assigned items: ${facility!.assignedItems}',
            ],
          ),
          _InfoCard(
            icon: Icons.account_balance_outlined,
            title: 'Fiscal compliance',
            status: compliance?.status,
            lines: [
              _line(compliance?.entityName),
              compliance?.taxId == null
                  ? 'Tax id not reported'
                  : compliance!.taxId!,
              _flag(
                compliance?.autoTax,
                'Auto tax deductions on',
                'Auto tax deductions off',
              ),
              _flag(
                compliance?.fiscalDevice,
                'Fiscal device enabled',
                'Fiscal device off',
              ),
            ],
          ),
          _InfoCard(
            icon: Icons.smartphone_outlined,
            title: 'Driver handhelds',
            status: device?.status,
            lines: [
              device?.build == null ? 'Build not reported' : device!.build!,
              _line(device?.companion),
              _flag(device?.smsReady, 'SMS link ready', 'SMS link not ready'),
            ],
          ),
        ];
        if (stacked) {
          return Column(
            children: [
              for (final card in cards) ...[card, const SizedBox(height: 12)],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }

  static String _line(String? value) =>
      (value == null || value.isEmpty) ? 'Not reported' : value;

  static String _flag(bool? value, String yes, String no) {
    if (value == null) return 'Not reported';
    return value ? yes : no;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.lines,
    this.status,
  });

  final IconData icon;
  final String title;
  final String? status;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AdminTokens.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: adminType(
                    13,
                    FontWeight.w700,
                    AdminTokens.text,
                    height: 1.2,
                  ),
                ),
              ),
              if (status != null && status!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AdminTokens.successSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status!,
                    style: adminType(
                      11,
                      FontWeight.w700,
                      AdminTokens.success,
                      height: 1.1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            Text(
              line,
              style: adminType(
                13,
                FontWeight.w500,
                AdminTokens.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class OnboardingSupportBar extends StatelessWidget {
  const OnboardingSupportBar({
    required this.onVideo,
    required this.onCall,
    required this.onChat,
    super.key,
  });

  final VoidCallback onVideo;
  final VoidCallback onCall;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            'Need assistance with setup?',
            style: adminType(
              14,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.2,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onVideo,
                style: adminOutlineButton(),
                icon: const Icon(Icons.play_circle_outline, size: 16),
                label: const Text('Setup video'),
              ),
              OutlinedButton.icon(
                onPressed: onCall,
                style: adminOutlineButton(),
                icon: const Icon(Icons.event_available_outlined, size: 16),
                label: const Text('Schedule a call'),
              ),
              FilledButton.icon(
                onPressed: onChat,
                style: adminPrimaryButton(color: AdminTokens.primary),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Live chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardingActivityCard extends StatelessWidget {
  const OnboardingActivityCard({required this.items, super.key});

  final List<OnboardingActivity> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent activity',
            style: adminType(
              15,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              'No onboarding activity recorded.',
              style: adminType(
                13,
                FontWeight.w500,
                AdminTokens.textSecondary,
                height: 1.3,
              ),
            )
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  item.at == null
                      ? item.message
                      : '${_stamp(item.at!)} · ${item.message}',
                  style: adminType(
                    13,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  static String _stamp(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${months[value.month - 1]} ${value.day}, $hour:$minute';
  }
}

class OnboardingMessageBanner extends StatelessWidget {
  const OnboardingMessageBanner({
    required this.message,
    required this.onRetry,
    this.error = false,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? AdminTokens.errorBg : AdminTokens.warningBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline : Icons.info_outline,
            color: error ? AdminTokens.error : AdminTokens.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: adminType(
                13,
                FontWeight.w600,
                error ? AdminTokens.error : AdminTokens.warning,
                height: 1.35,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
