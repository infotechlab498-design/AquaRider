import '../../api/route_api.dart';
import 'admin_format.dart';

enum DashboardRange { today, yesterday, week, month }

class DashboardPeriod {
  const DashboardPeriod._(this.range, this.from, this.to);

  final DashboardRange range;
  final DateTime from;
  final DateTime to;

  static DashboardPeriod resolve(DashboardRange range, [DateTime? now]) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    return switch (range) {
      DashboardRange.today => DashboardPeriod._(range, today, today),
      DashboardRange.yesterday => DashboardPeriod._(
        range,
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 1)),
      ),
      DashboardRange.week => DashboardPeriod._(
        range,
        today.subtract(const Duration(days: 6)),
        today,
      ),
      DashboardRange.month => DashboardPeriod._(
        range,
        today.subtract(const Duration(days: 29)),
        today,
      ),
    };
  }

  String get fromIso => isoDate(from);

  String get toIso => isoDate(to);

  /// Hour buckets for a single day. Day buckets for a span.
  String get bucket =>
      range == DashboardRange.today || range == DashboardRange.yesterday
      ? 'hour'
      : 'day';

  String get label {
    if (from == to) return formatAdminDay(from);
    return '${formatAdminDay(from)} – ${formatAdminDay(to)}';
  }
}

String isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String commandGreeting(AuthSession? session, {String? fromApi}) {
  final api = fromApi?.trim();
  if (api != null && api.isNotEmpty) return api;
  final hour = DateTime.now().hour;
  final hello = hour < 12
      ? 'Good morning'
      : hour < 17
      ? 'Good afternoon'
      : 'Good evening';
  final name = session?.firstName.trim() ?? '';
  if (name.isEmpty) return hello;
  return '$hello, $name';
}
