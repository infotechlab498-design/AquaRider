import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/onboarding_models.dart';

import '../../theme/admin_tokens.dart';

class BusinessContextBar extends StatelessWidget {
  const BusinessContextBar({
    required this.overview,
    required this.accountName,
    required this.accountRole,
    super.key,
  });

  final OnboardingOverview? overview;
  final String accountName;
  final String accountRole;

  @override
  Widget build(BuildContext context) {
    final business = overview?.businessName ?? '';
    final status = overview?.statusLabel ?? '';
    final setup = overview?.setupLabel ?? '';
    final name = (overview?.accountName.isNotEmpty ?? false)
        ? overview!.accountName
        : accountName;
    final role = (overview?.accountRole.isNotEmpty ?? false)
        ? overview!.accountRole
        : accountRole;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          setup.isEmpty ? 'Business onboarding' : setup,
          style: adminType(
            13,
            FontWeight.w600,
            AdminTokens.textSecondary,
            height: 1.2,
          ),
        ),
        Text(
          business.isEmpty ? 'Business name was not reported' : business,
          style: adminType(16, FontWeight.w700, AdminTokens.text, height: 1.2),
        ),
        if (status.isNotEmpty) _StatusChip(status),
        Text(
          '$name · $role',
          style: adminType(
            12.5,
            FontWeight.w500,
            AdminTokens.textSecondary,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminTokens.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: adminType(
          11.5,
          FontWeight.w700,
          AdminTokens.primary,
          height: 1.1,
        ),
      ),
    );
  }
}

class OnboardingHero extends StatelessWidget {
  const OnboardingHero({
    required this.overview,
    required this.progress,
    required this.next,
    required this.steps,
    required this.onContinue,
    super.key,
  });

  final OnboardingOverview? overview;
  final OnboardingProgress? progress;
  final OnboardingNextStep? next;
  final List<OnboardingStep> steps;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final welcome = _WelcomeCard(
          overview: overview,
          progress: progress,
          steps: steps,
        );
        final pace = _PaceCard(
          progress: progress,
          next: next,
          onContinue: onContinue,
        );
        if (stacked) {
          return Column(children: [welcome, const SizedBox(height: 16), pace]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: welcome),
            const SizedBox(width: 16),
            SizedBox(width: 300, child: pace),
          ],
        );
      },
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.overview,
    required this.progress,
    required this.steps,
  });

  final OnboardingOverview? overview;
  final OnboardingProgress? progress;
  final List<OnboardingStep> steps;

  @override
  Widget build(BuildContext context) {
    final business = overview?.businessName ?? '';
    final title = (overview?.welcomeTitle.isNotEmpty ?? false)
        ? overview!.welcomeTitle
        : (business.isEmpty
              ? 'Welcome to RouteLedger.'
              : 'Welcome to RouteLedger, $business');
    final body = (overview?.welcomeBody.isNotEmpty ?? false)
        ? overview!.welcomeBody
        : 'Step status loads from the onboarding service.';
    final milestone =
        progress?.milestoneLabel ??
        ((progress?.completed != null && progress?.total != null)
            ? 'Milestone ${progress!.completed} of ${progress!.total} reached'
            : 'Progress was not reported');
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTokens.line),
        boxShadow: AdminTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 16,
                color: AdminTokens.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'SYSTEM LAUNCH ROADMAP',
                style: adminType(
                  11,
                  FontWeight.w700,
                  AdminTokens.primary,
                  height: 1.2,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: adminType(
              26,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: adminType(
              14,
              FontWeight.w400,
              AdminTokens.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AdminTokens.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISPATCH READINESS',
                  style: adminType(
                    10.5,
                    FontWeight.w700,
                    AdminTokens.border,
                    height: 1.2,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final step in steps) ...[
                        _RoadNode(step: step),
                        if (step != steps.last)
                          Container(
                            width: 28,
                            height: 2,
                            margin: const EdgeInsets.only(bottom: 28),
                            color: AdminTokens.line,
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  milestone,
                  style: adminType(
                    12.5,
                    FontWeight.w600,
                    AdminTokens.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadNode extends StatelessWidget {
  const _RoadNode({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final done = step.status == OnboardingStepStatus.completed;
    final current = step.status == OnboardingStepStatus.inProgress;
    final color = done
        ? AdminTokens.success
        : (current ? AdminTokens.primary : AdminTokens.line);
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done || current ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '${step.order}',
                    style: adminType(
                      12,
                      FontWeight.w700,
                      current ? Colors.white : AdminTokens.textSecondary,
                      height: 1,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            step.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: adminType(
              11,
              FontWeight.w600,
              AdminTokens.text,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaceCard extends StatelessWidget {
  const _PaceCard({
    required this.progress,
    required this.next,
    required this.onContinue,
  });

  final OnboardingProgress? progress;
  final OnboardingNextStep? next;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final percent = progress?.displayPercent;
    final done = progress?.completed;
    final total = progress?.total;
    final fraction = (done != null && total != null && total > 0)
        ? '$done of $total complete'
        : 'Completion was not reported';
    final task = (next != null && next!.taskLabel.isNotEmpty)
        ? next!.taskLabel
        : 'No next step was reported.';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTokens.line),
        boxShadow: AdminTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Onboarding Pace',
            style: adminType(
              16,
              FontWeight.w700,
              AdminTokens.text,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Center(child: _PaceRing(percent: percent)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              fraction,
              style: adminType(
                12.5,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.2,
              ),
            ),
          ),
          if (progress?.paceLabel != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                progress!.paceLabel!,
                textAlign: TextAlign.center,
                style: adminType(
                  12,
                  FontWeight.w500,
                  AdminTokens.textSecondary,
                  height: 1.3,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTokens.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT PRIORITY',
                  style: adminType(
                    10.5,
                    FontWeight.w700,
                    AdminTokens.border,
                    height: 1.2,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task,
                  style: adminType(
                    13,
                    FontWeight.w600,
                    AdminTokens.text,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('continue-setup'),
              onPressed: onContinue,
              style: adminPrimaryButton(color: AdminTokens.primary),
              child: const FittedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continue Setup'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_downward, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaceRing extends StatelessWidget {
  const _PaceRing({required this.percent});

  final int? percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: CustomPaint(
        painter: _RingPainter(percent: percent),
        child: Center(
          child: Text(
            percent == null ? '—' : '$percent%',
            style: adminType(28, FontWeight.w700, AdminTokens.text, height: 1),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.percent});

  final int? percent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    final track = Paint()
      ..color = AdminTokens.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    final value = percent;
    if (value == null || value <= 0) return;
    final sweep = (value.clamp(0, 100) / 100) * 6.283185307179586;
    final arc = Paint()
      ..color = AdminTokens.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57079632679,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percent != percent;
}
