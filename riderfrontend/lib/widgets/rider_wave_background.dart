import 'package:flutter/material.dart';

/// Shared glossy water-wave backdrop for rider Route Map and Settings screens.
/// Portrait keeps the top-wave frame; landscape covers the viewport without
/// stretching the bubble art into the content band.
class RiderWaveBackground extends StatelessWidget {
  const RiderWaveBackground({
    this.asset = 'assets/rider_settings/rider_wave_bg.jpg',
    this.fill = const Color(0xFFF4F9FE),
    this.scrim = const Color(0x08FFFFFF),
    super.key,
  });

  final String asset;
  final Color fill;
  final Color scrim;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.height > 0 && size.width / size.height > 1.15;
    final short = size.shortestSide < 600;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: fill),
        Positioned.fill(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: landscape
                ? Alignment.center
                : (short ? Alignment.topCenter : const Alignment(0, -0.35)),
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
        // Soft center wash so white cards stay readable over the pale mid band.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scrim.withValues(alpha: landscape ? 0.04 : 0.02),
                    const Color(0x00FFFFFF),
                    scrim.withValues(alpha: landscape ? 0.06 : 0.03),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
