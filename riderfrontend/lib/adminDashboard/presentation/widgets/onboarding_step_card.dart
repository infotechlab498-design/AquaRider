import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/onboarding_models.dart';

import '../../theme/admin_tokens.dart';

class OnboardingStepCard extends StatelessWidget {
  const OnboardingStepCard({
    required this.step,
    required this.onOpen,
    super.key,
  });

  final OnboardingStep step;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final current = step.status == OnboardingStepStatus.inProgress;
    return Container(
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: current ? AdminTokens.primary : AdminTokens.line,
          width: current ? 1.6 : 1,
        ),
        boxShadow: AdminTokens.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 680;
            final copy = _StepCopy(step: step);
            final action = _StepAction(step: step, onOpen: onOpen);
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [copy, const SizedBox(height: 12), action],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 12),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StepCopy extends StatelessWidget {
  const _StepCopy({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final number = step.order.toString().padLeft(2, '0');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepIcon(status: step.status),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'TASK $number',
                    style: adminType(
                      11,
                      FontWeight.w700,
                      AdminTokens.border,
                      height: 1.2,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    step.title,
                    style: adminType(
                      15,
                      FontWeight.w700,
                      AdminTokens.text,
                      height: 1.2,
                    ),
                  ),
                  _StatusPill(status: step.status),
                  if (step.recommended) const _RecommendPill(),
                ],
              ),
              if (step.summary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  step.summary,
                  style: adminType(
                    13,
                    FontWeight.w400,
                    AdminTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              if (step.badges.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final badge in step.badges) _MiniBadge(badge),
                  ],
                ),
              ],
              if (step.checks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final check in step.checks)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check,
                            size: 14,
                            color: AdminTokens.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            check,
                            style: adminType(
                              12,
                              FontWeight.w500,
                              AdminTokens.textSecondary,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
              if (step.note != null) ...[
                const SizedBox(height: 6),
                Text(
                  step.note!,
                  style: adminType(
                    12,
                    FontWeight.w500,
                    AdminTokens.warning,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.status});

  final OnboardingStepStatus status;

  @override
  Widget build(BuildContext context) {
    final done = status == OnboardingStepStatus.completed;
    final current = status == OnboardingStepStatus.inProgress;
    final color = done
        ? AdminTokens.success
        : (current ? AdminTokens.primary : AdminTokens.secondary);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done
            ? AdminTokens.successSoft
            : (current ? AdminTokens.primarySoft : AdminTokens.background),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
        size: 18,
        color: color,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final OnboardingStepStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      OnboardingStepStatus.completed => (
        'Completed',
        AdminTokens.success,
        AdminTokens.successSoft,
      ),
      OnboardingStepStatus.inProgress => (
        'In progress',
        AdminTokens.primary,
        AdminTokens.primarySoft,
      ),
      OnboardingStepStatus.notStarted => (
        'Not started',
        AdminTokens.textSecondary,
        const Color(0xFFF1F5F9),
      ),
      OnboardingStepStatus.unavailable => (
        'Not reported',
        AdminTokens.border,
        const Color(0xFFF1F5F9),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: adminType(11, FontWeight.w700, fg, height: 1.1),
      ),
    );
  }
}

class _RecommendPill extends StatelessWidget {
  const _RecommendPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AdminTokens.warningBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Recommended now',
        style: adminType(11, FontWeight.w700, AdminTokens.warning, height: 1.1),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: adminType(12, FontWeight.w600, AdminTokens.success, height: 1.2),
    );
  }
}

class _StepAction extends StatelessWidget {
  const _StepAction({required this.step, required this.onOpen});

  final OnboardingStep step;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final unavailable = step.status == OnboardingStepStatus.unavailable;
    final label = unavailable
        ? 'Unavailable'
        : (step.actionLabel ?? 'View details');
    final filled =
        step.status == OnboardingStepStatus.inProgress && !unavailable;
    if (filled) {
      return FilledButton(
        onPressed: onOpen,
        style: adminPrimaryButton(color: AdminTokens.primary, radius: 10),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: unavailable ? null : onOpen,
      style: adminOutlineButton(),
      child: Text(label),
    );
  }
}
