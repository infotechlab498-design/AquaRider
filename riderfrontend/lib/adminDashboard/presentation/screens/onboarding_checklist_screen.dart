import 'package:flutter/material.dart';

import '../../../api/route_api.dart';
import '../../theme/admin_tokens.dart';
import '../admin_nav.dart';
import '../widgets/admin_shell.dart';
import '../widgets/onboarding_hero.dart';
import '../widgets/onboarding_panels.dart';
import '../widgets/onboarding_step_card.dart';

enum _StepFilter { all, pending, completed }

class OnboardingChecklistScreen extends StatefulWidget {
  const OnboardingChecklistScreen({
    required this.onNavigate,
    this.session,
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<OnboardingChecklistScreen> createState() =>
      _OnboardingChecklistScreenState();
}

class _OnboardingChecklistScreenState extends State<OnboardingChecklistScreen> {
  final _search = TextEditingController();
  final _anchors = {
    for (final step in lockedOnboardingSteps) step.code: GlobalKey(),
  };
  var _started = false;
  var _loading = true;
  var _reachable = true;
  var _filter = _StepFilter.all;
  String _query = '';
  List<String> _errors = const [];
  OnboardingOverview? _overview;
  List<OnboardingStep>? _remoteSteps;
  OnboardingProgress? _progress;
  OnboardingReadiness? _readiness;
  OnboardingNextStep? _next;
  List<OnboardingActivity>? _activity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final errors = <String>[];
    Future<T?> take<T>(Future<T?> call) async {
      try {
        return await call;
      } on ApiException catch (error) {
        errors.add(error.message);
        return null;
      } catch (_) {
        errors.add('Cannot reach the route server.');
        return null;
      }
    }

    // Overview first so embedded steps are available if /steps is thin or missing.
    final overview = await take(api.onboardingOverview());
    final stepsF = take(api.onboardingSteps());
    final progressF = take(api.onboardingProgress());
    final readinessF = take(api.onboardingReadiness());
    final nextF = take(api.onboardingNextStep());
    final activityF = take(api.onboardingActivity());
    final steps = await stepsF;
    final progress = await progressF;
    final readiness = await readinessF;
    final next = await nextF;
    final activity = await activityF;
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _remoteSteps = steps;
      _progress = progress;
      _readiness = readiness;
      _next = next;
      _activity = activity;
      _errors = errors.toSet().toList();
      _reachable = !errors.contains('Cannot reach the route server.');
      _loading = false;
    });
  }

  List<OnboardingStep> get _steps => mergeLockedSteps(_remoteSteps);

  List<OnboardingStep> get _visible {
    final query = _query.trim().toLowerCase();
    return [
      for (final step in _steps)
        if (_matchesFilter(step) &&
            (query.isEmpty ||
                '${step.title} ${step.summary}'.toLowerCase().contains(query)))
          step,
    ];
  }

  bool _matchesFilter(OnboardingStep step) {
    return switch (_filter) {
      _StepFilter.all => true,
      _StepFilter.pending => step.isPending,
      _StepFilter.completed => step.isCompleted,
    };
  }

  void _notice(String message) => showAdminNotice(context, message);

  void _openDashboard() => widget.onNavigate(AdminNav.dashboard);

  void _continue() {
    final next = _next;
    if (next == null) {
      _notice('The server did not return a next step.');
      return;
    }
    final code = _codeFor(next);
    if (code == null) {
      _notice(
        'The next step from the server is outside the six-step checklist.',
      );
      return;
    }
    setState(() {
      _filter = _StepFilter.all;
      _query = '';
      _search.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _anchors[code]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 280),
          alignment: 0.12,
        );
      }
    });
  }

  String? _codeFor(OnboardingNextStep next) {
    final wanted = next.code.toLowerCase();
    final title = next.title.toLowerCase();
    for (final step in _steps) {
      if (wanted.isNotEmpty &&
          (step.code == wanted || wanted.contains(step.code))) {
        return step.code;
      }
      if (title.isNotEmpty && title.contains(step.title.toLowerCase())) {
        return step.code;
      }
    }
    for (final locked in lockedOnboardingSteps) {
      if (wanted.contains(locked.code) ||
          title.contains(locked.title.toLowerCase())) {
        return locked.code;
      }
      for (final alias in locked.aliases) {
        if (wanted.contains(alias) || title.contains(alias)) return locked.code;
      }
    }
    return null;
  }

  void _openStep(OnboardingStep step) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AdminTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: adminType(
                  18,
                  FontWeight.w700,
                  AdminTokens.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step.summary.isEmpty
                    ? 'No detail was returned for this step.'
                    : step.summary,
                style: adminType(
                  14,
                  FontWeight.w400,
                  AdminTokens.textSecondary,
                  height: 1.45,
                ),
              ),
              for (final check in step.checks) ...[
                const SizedBox(height: 6),
                Text(
                  '• $check',
                  style: adminType(
                    13,
                    FontWeight.w500,
                    AdminTokens.text,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Completion is recorded by the server. This screen does not mark the step done.',
                style: adminType(
                  12.5,
                  FontWeight.w600,
                  AdminTokens.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final accountName = session == null || session.fullName.isEmpty
        ? 'Administrator'
        : session.fullName;
    final accountRole = session == null || session.role.isEmpty
        ? 'Admin'
        : session.role;
    return AdminShell(
      screenKey: const Key('onboarding-screen'),
      activeKey: AdminNav.checklist,
      session: session,
      serverReachable: _reachable,
      search: _search,
      onSearch: (value) => setState(() => _query = value),
      onSkip: _openDashboard,
      onNavigate: widget.onNavigate,
      onNotify: () => _notice('Notifications are not configured.'),
      onHelp: () => _notice('In-app help is not configured.'),
      body: _loading ? const _LoadingPane() : _body(accountName, accountRole),
    );
  }

  Widget _body(String accountName, String accountRole) {
    final steps = _steps;
    final visible = _visible;
    final pending = steps.where((step) => step.isPending).length;
    final completed = steps.where((step) => step.isCompleted).length;
    final missingService =
        _remoteSteps == null &&
        _overview == null &&
        _progress == null &&
        _errors.isEmpty;
    final fatal =
        steps.every(
          (step) => step.status == OnboardingStepStatus.unavailable,
        ) &&
        _overview == null &&
        _progress == null &&
        _errors.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        BusinessContextBar(
          overview: _overview,
          accountName: accountName,
          accountRole: accountRole,
        ),
        const SizedBox(height: 16),
        if (fatal)
          OnboardingMessageBanner(
            message: _errors.join(' '),
            onRetry: _load,
            error: true,
          )
        else if (_errors.isNotEmpty)
          OnboardingMessageBanner(
            message: _errors.join(' '),
            onRetry: _load,
            error: true,
          )
        else if (missingService)
          OnboardingMessageBanner(
            message: 'The onboarding endpoints are not available on this server yet.',
            onRetry: _load,
          ),
        if (fatal || _errors.isNotEmpty || missingService)
          const SizedBox(height: 16),
        if (!fatal) ...[
          OnboardingHero(
            overview: _overview,
            progress: _progress,
            next: _next,
            steps: steps,
            onContinue: _continue,
          ),
          const SizedBox(height: 16),
          _ChecklistHeader(
            filter: _filter,
            all: steps.length,
            pending: pending,
            completed: completed,
            onFilter: (value) => setState(() => _filter = value),
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No steps match this filter.',
                style: adminType(
                  14,
                  FontWeight.w600,
                  AdminTokens.textSecondary,
                ),
              ),
            )
          else
            for (final step in visible) ...[
              KeyedSubtree(
                key: _anchors[step.code],
                child: OnboardingStepCard(
                  step: step,
                  onOpen: () => _openStep(step),
                ),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 8),
          OnboardingReadinessBanner(
            readiness: _readiness,
            onSkip: _openDashboard,
          ),
          const SizedBox(height: 12),
          OnboardingInfoCards(overview: _overview),
          const SizedBox(height: 12),
          if (_activity != null) ...[
            OnboardingActivityCard(items: _activity!),
            const SizedBox(height: 12),
          ],
          OnboardingSupportBar(
            onVideo: () =>
                _notice('Setup videos are not published on this server.'),
            onCall: () =>
                _notice('Onboarding calls are not scheduled from this server.'),
            onChat: () => _notice('Live chat is not connected in this build.'),
          ),
        ],
      ],
    );
  }
}

class _LoadingPane extends StatelessWidget {
  const _LoadingPane();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AdminTokens.primary),
          const SizedBox(height: 12),
          Text(
            'Loading onboarding…',
            style: adminType(14, FontWeight.w600, AdminTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ChecklistHeader extends StatelessWidget {
  const _ChecklistHeader({
    required this.filter,
    required this.all,
    required this.pending,
    required this.completed,
    required this.onFilter,
  });

  final _StepFilter filter;
  final int all;
  final int pending;
  final int completed;
  final ValueChanged<_StepFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final chips = [
      _FilterChip(
        label: 'All ($all)',
        selected: filter == _StepFilter.all,
        onTap: () => onFilter(_StepFilter.all),
      ),
      _FilterChip(
        label: 'Pending ($pending)',
        selected: filter == _StepFilter.pending,
        onTap: () => onFilter(_StepFilter.pending),
      ),
      _FilterChip(
        label: 'Completed ($completed)',
        selected: filter == _StepFilter.completed,
        onTap: () => onFilter(_StepFilter.completed),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final title = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.checklist_outlined,
              size: 18,
              color: AdminTokens.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Onboarding Checklist',
              style: adminType(
                16,
                FontWeight.w700,
                AdminTokens.text,
                height: 1.2,
              ),
            ),
          ],
        );
        final filters = Wrap(spacing: 6, runSpacing: 6, children: chips);
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 8), filters],
          );
        }
        return Row(children: [title, const Spacer(), filters]);
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AdminTokens.primarySoft : AdminTokens.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AdminTokens.primary : AdminTokens.line,
            ),
          ),
          child: Text(
            label,
            style: adminType(
              12,
              FontWeight.w700,
              selected ? AdminTokens.primary : AdminTokens.textSecondary,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
