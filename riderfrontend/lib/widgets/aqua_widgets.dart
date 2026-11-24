import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/rider_store.dart';
import '../core/theme.dart';

class RiderHeader extends StatelessWidget {
  const RiderHeader({required this.subtitle, super.key});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final rider = RiderScope.of(context).rider;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AquaRider',
                  style: aquaText(
                    18,
                    FontWeight.w800,
                    AquaColors.primary,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  subtitle,
                  style: aquaText(12, FontWeight.w500, AquaColors.secondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rider.shortName,
                style: aquaText(12, FontWeight.w700, AquaColors.navy),
              ),
              Text(
                'Rider #${rider.id}',
                style: aquaText(11, FontWeight.w700, AquaColors.primary),
              ),
            ],
          ),
          const SizedBox(width: 8),
          const _RiderAvatar(),
        ],
      ),
    );
  }
}

class _RiderAvatar extends StatelessWidget {
  const _RiderAvatar();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: AquaColors.tint,
          child: Icon(Icons.person, color: AquaColors.primary, size: 20),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: AquaColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: AquaColors.background, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class FlowHeader extends StatelessWidget {
  const FlowHeader({
    required this.title,
    required this.step,
    required this.onBack,
    super.key,
  });

  final String title;
  final String step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            key: const Key('flow-back'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AquaColors.navy),
            tooltip: 'Back',
            style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: aquaText(20, FontWeight.w800, AquaColors.navy),
                ),
                const SizedBox(height: 2),
                Text(
                  step,
                  style: aquaText(
                    12,
                    FontWeight.w600,
                    AquaColors.secondary,
                    letterSpacing: 0.4,
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

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.urduLabel,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final String? urduLabel;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AquaColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB7CBE0),
          disabledForegroundColor: Colors.white,
          elevation: enabled ? 1 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: aquaText(16, FontWeight.w700, Colors.white),
                        ),
                        if (urduLabel != null)
                          Text(urduLabel!, style: urduText(12, Colors.white)),
                      ],
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.edit_outlined, size: 18),
        label: Text(
          label,
          style: aquaText(15, FontWeight.w700, AquaColors.primary),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({
    required this.title,
    required this.urdu,
    this.trailing,
    super.key,
  });

  final String title;
  final String urdu;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: aquaText(15, FontWeight.w700, AquaColors.navy),
              ),
              Text(urdu, style: urduText(13, AquaColors.secondary)),
            ],
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: aquaText(11, FontWeight.w600, AquaColors.secondary),
          ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.label, required this.tone, super.key});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      StatusTone.success => (AquaColors.successTint, AquaColors.success),
      StatusTone.warning => (AquaColors.warningTint, const Color(0xFF8A5A00)),
      StatusTone.error => (AquaColors.errorTint, AquaColors.error),
      StatusTone.info => (AquaColors.tint, AquaColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: aquaText(11, FontWeight.w700, foreground)),
    );
  }
}

enum StatusTone { success, warning, error, info }

StatusTone toneForStatus(String label) {
  return switch (label) {
    'Unpaid' => StatusTone.error,
    'Awaiting Verification' => StatusTone.warning,
    'Saved' => StatusTone.success,
    _ => StatusTone.info,
  };
}

class SyncLabel extends StatelessWidget {
  const SyncLabel({required this.synced, super.key});

  final bool synced;

  @override
  Widget build(BuildContext context) {
    final color = synced ? AquaColors.success : const Color(0xFF8A5A00);
    return Row(
      children: [
        Icon(
          synced ? Icons.cloud_done_outlined : Icons.phone_android,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            synced ? kSyncedLabel : kPendingSyncLabel,
            style: aquaText(12, FontWeight.w600, color),
          ),
        ),
      ],
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.index,
    required this.todayCount,
    required this.onChanged,
    super.key,
  });

  final int index;
  final int todayCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF7FFFFFF),
        border: Border(top: BorderSide(color: AquaColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                itemKey: const Key('nav-entry'),
                icon: Icons.water_drop_outlined,
                label: 'Entry',
                urdu: 'اندراج',
                selected: index == 0,
                onTap: () => onChanged(0),
              ),
              _NavItem(
                itemKey: const Key('nav-today'),
                icon: Icons.receipt_long_outlined,
                label: "Today's Entries",
                urdu: 'آج کی ترسیل',
                badge: todayCount > 0 ? '$todayCount' : null,
                selected: index == 1,
                onTap: () => onChanged(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.itemKey,
    required this.icon,
    required this.label,
    required this.urdu,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final Key itemKey;
  final IconData icon;
  final String label;
  final String urdu;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AquaColors.primary : AquaColors.secondary;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Material(
          color: selected ? AquaColors.tint : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: itemKey,
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: badge != null,
                  label: Text(badge ?? ''),
                  backgroundColor: AquaColors.primary,
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: aquaText(12, FontWeight.w700, color),
                      ),
                      Text(
                        urdu,
                        maxLines: 1,
                        style: urduText(10, AquaColors.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeTab extends InheritedWidget {
  const HomeTab({
    required this.index,
    required this.select,
    required super.child,
    super.key,
  });

  final int index;
  final ValueChanged<int> select;

  static HomeTab of(BuildContext context) {
    final tab = context.getInheritedWidgetOfExactType<HomeTab>();
    assert(tab != null, 'HomeTab is missing above this widget.');
    return tab!;
  }

  @override
  bool updateShouldNotify(HomeTab oldWidget) => index != oldWidget.index;
}
