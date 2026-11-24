import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/typography.dart';

export '../core/typography.dart';

const riderShellRoute = 'route-shell';

class RouteColors {
  static const page = Color(0xFFF8F9FF);
  static const ink = Color(0xFF0B1C30);
  static const secondary = Color(0xFF565E74);
  static const body = Color(0xFF434655);
  static const muted = Color(0xFF737686);
  static const primary = Color(0xFF1565C0);
  static const link = Color(0xFF1565C0);
  static const tint = Color(0xFFEFF4FF);
  static const splash = Color(0xFF1565C0);
  static const slate = Color(0xFF37474F);
  static const pale = Color(0xFFE3F0FB);
  static const bar = Color(0xFF1565C0);
  static const accent = Color(0xFF1565C0);
  static const line = Color(0xFFE6E8EE);
  static const sync = Color(0xFF71F8E4);
  static const syncInk = Color(0xFF00201C);
  static const danger = Color(0xFFD64545);
  static const ok = Color(0xFF0B7A4B);
}

const routeCardShadow = [
  BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 6,
    spreadRadius: -1,
    offset: Offset(0, 4),
  ),
  BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 4,
    spreadRadius: -2,
    offset: Offset(0, 2),
  ),
];

const routeSoftShadow = [
  BoxShadow(color: Color(0x0D000000), blurRadius: 1, offset: Offset(0, 1)),
];

class RouteSvg extends StatelessWidget {
  const RouteSvg(this.asset, this.width, this.height, {super.key});

  final String asset;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(asset, width: width, height: height);
  }
}

class RoutePage extends StatelessWidget {
  const RoutePage({
    required this.body,
    this.title,
    this.navIndex,
    this.onNav,
    this.bottom,
    this.trailing,
    super.key,
  });

  final Widget body;
  final String? title;
  final int? navIndex;
  final ValueChanged<int>? onNav;
  final Widget? bottom;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = title;
    return Scaffold(
      backgroundColor: RouteColors.page,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                if (heading != null)
                  RouteTitleBar(title: heading, trailing: trailing),
                Expanded(child: body),
                ?bottom,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: navIndex == null
          ? null
          : RouteBottomNav(index: navIndex!, onChanged: onNav ?? (_) {}),
    );
  }
}

class RouteTitleBar extends StatelessWidget {
  const RouteTitleBar({required this.title, this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back,
              color: RouteColors.ink,
              size: 22,
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: routeType(18, FontWeight.w600, RouteColors.ink, 24, -0.1),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: trailing!,
            ),
        ],
      ),
    );
  }
}

class RouteCard extends StatelessWidget {
  const RouteCard({
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: routeSoftShadow,
      ),
      child: child,
    );
  }
}

class RouteButton extends StatelessWidget {
  const RouteButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.keyId,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? icon;
  final Key? keyId;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RouteColors.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: routeCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: keyId,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Text(
                  label,
                  style: routeType(14, FontWeight.w600, Colors.white, 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RouteOutlineButton extends StatelessWidget {
  const RouteOutlineButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: RouteColors.ink,
          side: const BorderSide(color: RouteColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: routeType(14, FontWeight.w600, RouteColors.ink, 20),
        ),
      ),
    );
  }
}

class RouteBottomNav extends StatelessWidget {
  const RouteBottomNav({
    required this.index,
    required this.onChanged,
    super.key,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Color(0x1A0875C8), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: SizedBox(
          height: 64,
          child: Row(
          children: [
            _item(0, Icons.home_outlined, Icons.home, 'Home', 'nav-home'),
            _item(
              1,
              Icons.checklist_outlined,
              Icons.checklist,
              'To-Do',
              'nav-todo',
            ),
            _item(2, Icons.map_outlined, Icons.map, 'Map', 'nav-map'),
            _item(
              3,
              Icons.person_outline,
              Icons.person,
              'Profile',
              'nav-profile',
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _item(
    int value,
    IconData icon,
    IconData selected,
    String label,
    String keyName,
  ) {
    final active = index == value;
    final color = active ? Colors.white : const Color(0xFF7C8DA3);
    return Expanded(
      child: InkWell(
        key: Key(keyName),
        onTap: () => onChanged(value),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF0875E8) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(active ? selected : icon, size: 18, color: color),
                const SizedBox(height: 2),
                Text(label, style: routeType(11, FontWeight.w600, color, 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void pushRoute(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}
