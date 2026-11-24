import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class DayCloseScreen extends StatefulWidget {
  const DayCloseScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<DayCloseScreen> createState() => _DayCloseScreenState();
}

class _DayCloseScreenState extends State<DayCloseScreen> {
  static const _pageSize = 10;
  final _search = TextEditingController();
  final _verified = TextEditingController();
  final _remarks = TextEditingController();
  Timer? _debounce;
  var _started = false;
  var _loading = true;
  var _page = 1;
  var _status = 'all';
  var _listGeneration = 0;
  var _detailGeneration = 0;
  var _detailBusy = false;
  var _actionBusy = false;
  String? _openId;
  String? _category;
  DateTime _date = _today();

  AdminLoad<DayCloseSummary>? _summary;
  AdminLoad<SettlementStatusCounts>? _counts;
  AdminLoad<SettlementSessionPage>? _sessions;
  AdminLoad<SettlementSessionDetail>? _detail;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _dateIso =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _search.addListener(_scheduleSearch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _listGeneration++;
    _detailGeneration++;
    _debounce?.cancel();
    _search.dispose();
    _verified.dispose();
    _remarks.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _page = 1);
      _reload();
    });
  }

  Future<void> _reload() async {
    final generation = ++_listGeneration;
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final summary = await guardAdminLoad(
      () => api.dayCloseSummary(date: _dateIso),
    );
    final counts = await guardAdminLoad(
      () => api.settlementStatusCounts(date: _dateIso, search: _search.text),
    );
    final sessions = await guardAdminLoad(
      () => api.settlementSessions(
        date: _dateIso,
        status: _status,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        page: _page,
        pageSize: _pageSize,
      ),
    );
    if (!mounted || generation != _listGeneration) return;
    setState(() {
      _summary = summary;
      _counts = counts;
      _sessions = sessions;
      _loading = false;
    });
    final open = _openId;
    if (open != null) await _loadDetail(open);
  }

  Future<void> _loadDetail(String id) async {
    final generation = ++_detailGeneration;
    setState(() {
      _openId = id;
      _detailBusy = true;
      _detail = null;
    });
    final detail = await guardAdminLoad(
      () => ApiScope.of(context).settlementSession(id),
    );
    if (!mounted || generation != _detailGeneration || _openId != id) return;
    final value = detail.value;
    _verified.text = value?.draftVerifiedCash?.toString() ?? '';
    _remarks.text = value?.draftRemarks ?? '';
    _category = value?.draftResolutionCategory;
    setState(() {
      _detail = detail;
      _detailBusy = false;
    });
  }

  void _closeDetail() {
    _detailGeneration++;
    setState(() {
      _openId = null;
      _detail = null;
      _detailBusy = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _page = 1;
      _openId = null;
    });
    await _reload();
  }

  Future<void> _saveDraft() async {
    final id = _openId;
    if (id == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await ApiScope.of(context).settlementSaveDraft(
        id,
        cashierVerifiedCash: num.tryParse(_verified.text.trim()),
        resolutionCategory: _category,
        remarks: _remarks.text.trim(),
      );
      if (!mounted) return;
      showAdminNotice(context, 'Draft saved.');
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _verifyCash() async {
    final id = _openId;
    final amount = num.tryParse(_verified.text.trim());
    if (id == null || amount == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await ApiScope.of(context).settlementVerifyCash(
        id,
        verifiedAmount: amount,
      );
      if (!mounted) return;
      showAdminNotice(context, 'Physical cash verification recorded.');
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _resolve() async {
    final id = _openId;
    if (id == null || _actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await ApiScope.of(context).settlementResolve(
        id,
        cashierVerifiedCash: num.tryParse(_verified.text.trim()),
        resolutionCategory: _category,
        remarks: _remarks.text.trim(),
      );
      if (!mounted) return;
      showAdminNotice(context, 'Settlement approved.');
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _lockDay() async {
    setState(() => _actionBusy = true);
    try {
      final readiness = await ApiScope.of(context).settlementLockReadiness(_dateIso);
      if (!mounted) return;
      if (!readiness.ready) {
        showAdminNotice(
          context,
          readiness.blockingReasons.isEmpty
              ? 'Day cannot be locked yet.'
              : readiness.blockingReasons.join(' '),
        );
        return;
      }
      final result = await ApiScope.of(context).settlementLockDay(_dateIso);
      if (!mounted) return;
      showAdminNotice(context, result.message.isEmpty ? (result.locked ? 'Day locked.' : 'Lock failed.') : result.message);
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[?_summary, ?_counts, ?_sessions];
    return AdminShell(
      screenKey: const Key('day-close-screen'),
      session: widget.session,
      activeKey: AdminNav.dayClose,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search rider name, ID or route',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && _summary == null
          ? const AdminLoadingPane(label: 'Loading day close…')
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1100;
                final content = ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  children: [
                    Text(
                      'Field Operations  ›  Day Close & Reconciliation',
                      style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Day Close & Cash Reconciliation',
                      style: adminType(28, FontWeight.w700, AdminTokens.text, height: 1.15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review rider cash collections, returned empty containers, and daily shift settlement audits.',
                      style: adminType(14, FontWeight.w500, AdminTokens.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined, size: 18),
                          label: Text(_dateIso),
                        ),
                        OutlinedButton(
                          onPressed: _actionBusy ? null : _lockDay,
                          style: adminOutlineButton(),
                          child: const Text('Lock Day'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _left(),
                    if (!wide && _openId != null) ...[
                      const SizedBox(height: 16),
                      _panel(fullscreen: true),
                    ],
                  ],
                );
                if (!wide) return content;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 55, child: content),
                    if (_openId != null)
                      Expanded(
                        flex: 40,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            border: Border(left: BorderSide(color: AdminTokens.line)),
                          ),
                          child: _panel(),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _left() {
    final summary = _summary?.value;
    final counts = _counts?.value;
    final page = _sessions?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_summary?.failed == true)
          Text(_summary!.error ?? adminUnreachableMessage, style: adminType(13, FontWeight.w600, AdminTokens.error)),
        _gatewayChip(summary?.gateway),
        const SizedBox(height: 12),
        _kpiRow(summary),
        const SizedBox(height: 12),
        if (summary?.sopMessage != null && summary!.sopMessage!.trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AdminTokens.primarySoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Standard Operating Procedure: Discrepancy Resolution', style: adminType(13.5, FontWeight.w700, AdminTokens.text)),
                const SizedBox(height: 4),
                Text(summary.sopMessage!, style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary, height: 1.35)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tab in [
              ('all', 'All', counts?.all),
              ('awaitingReview', 'Awaiting Review', counts?.awaitingReview),
              ('varianceDetected', 'Variance Detected', counts?.varianceDetected),
              ('reconciled', 'Reconciled', counts?.reconciled),
              ('locked', 'Locked', counts?.locked),
            ])
              ChoiceChip(
                label: Text('${tab.$2}${tab.$3 == null ? '' : ' (${tab.$3})'}'),
                selected: _status == tab.$1,
                onSelected: (_) {
                  setState(() {
                    _status = tab.$1;
                    _page = 1;
                  });
                  _reload();
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search rider name, ID or route',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        if (_sessions?.failed == true)
          Text(_sessions!.error ?? adminUnreachableMessage, style: adminType(13, FontWeight.w600, AdminTokens.error))
        else if (page == null || page.rows.isEmpty)
          Text(
            'No settlement sessions found for this date.',
            style: adminType(13.5, FontWeight.w600, AdminTokens.textSecondary),
          )
        else
          ...page.rows.map(_sessionTile),
        if (page != null && page.totalPages > 1) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Showing page ${page.page} of ${page.totalPages}'),
              const Spacer(),
              IconButton(
                onPressed: page.page <= 1
                    ? null
                    : () {
                        setState(() => _page -= 1);
                        _reload();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: page.page >= page.totalPages
                    ? null
                    : () {
                        setState(() => _page += 1);
                        _reload();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _gatewayChip(DayCloseGatewayStatus? gateway) {
    final message = gateway?.message ?? 'Gateway Integration Not Configured.';
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(
          gateway?.configured == true ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          size: 18,
          color: AdminTokens.primary,
        ),
        label: Text(message, style: adminType(12, FontWeight.w600, AdminTokens.text)),
        backgroundColor: AdminTokens.surface,
        side: const BorderSide(color: AdminTokens.line),
      ),
    );
  }

  Widget _kpiRow(DayCloseSummary? summary) {
    Widget card(String label, String value, [String? detail]) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AdminTokens.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AdminTokens.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: adminType(11.5, FontWeight.w600, AdminTokens.textSecondary)),
              const SizedBox(height: 6),
              Text(value, style: adminType(18, FontWeight.w700, AdminTokens.text)),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(detail, style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary)),
              ],
            ],
          ),
        ),
      );
    }

    final submitted = summary?.ridersSubmitted;
    final eligible = summary?.ridersEligible;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 900;
        final cards = [
          card(
            'Riders Submitted',
            submitted == null || eligible == null ? '—' : '$submitted / $eligible',
            summary?.ridersRemaining == null ? null : '${summary!.ridersRemaining} remaining',
          ),
          card('Expected Cash', summary?.expectedCash == null ? '—' : formatPkr(summary!.expectedCash!)),
          card('Declared Cash', summary?.declaredCash == null ? '—' : formatPkr(summary!.declaredCash!)),
          card('Physically Received', summary?.physicallyReceived == null ? '—' : formatPkr(summary!.physicallyReceived!)),
          card(
            'Unresolved Variance',
            summary?.unresolvedNetVariance == null ? '—' : formatPkr(summary!.unresolvedNetVariance!),
            summary?.unresolvedFlagCount == null ? null : '${summary!.unresolvedFlagCount} flags',
          ),
        ];
        if (stacked) {
          return Column(
            children: [
              for (final item in cards) ...[item, const SizedBox(height: 8)],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              cards[i],
            ],
          ],
        );
      },
    );
  }

  Widget _sessionTile(SettlementSessionRow row) {
    final selected = row.id == _openId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AdminTokens.primarySoft : AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: Key('settlement-session-${row.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _loadDetail(row.id),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? AdminTokens.primary : AdminTokens.line),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.riderName.isEmpty ? row.riderId : row.riderName, style: adminType(14, FontWeight.w700, AdminTokens.text)),
                      Text(row.sessionCode, style: adminType(12, FontWeight.w500, AdminTokens.textSecondary)),
                    ],
                  ),
                ),
                Expanded(child: Text(row.routeName.isEmpty ? '—' : row.routeName)),
                Expanded(child: Text(row.expectedCash == null ? '—' : formatPkr(row.expectedCash!))),
                Expanded(child: Text(row.physicallyReceived == null ? '—' : formatPkr(row.physicallyReceived!))),
                Expanded(child: Text(row.netVariance == null ? '—' : formatPkr(row.netVariance!))),
                Text(row.status, style: adminType(12, FontWeight.w700, AdminTokens.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({bool fullscreen = false}) {
    if (_openId == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AdminTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTokens.line),
        ),
        child: Text(
          'Select a settlement session to review cash, stock, and manager actions.',
          style: adminType(13.5, FontWeight.w600, AdminTokens.textSecondary, height: 1.4),
        ),
      );
    }
    if (_detailBusy || _detail == null) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator(color: AdminTokens.primary)),
      );
    }
    if (_detail!.failed) {
      return Text(_detail!.error ?? adminUnreachableMessage, style: adminType(13, FontWeight.w600, AdminTokens.error));
    }
    final detail = _detail!.value!;
    final ledger = detail.ledger;
    return Container(
      key: const Key('settlement-detail-panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: ListView(
        shrinkWrap: true,
        physics: fullscreen ? null : const NeverScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              if (fullscreen)
                IconButton(onPressed: _closeDetail, icon: const Icon(Icons.arrow_back))
              else
                IconButton(onPressed: _closeDetail, icon: const Icon(Icons.close)),
              Expanded(
                child: Text(
                  'Shift Settlement Audit — ${detail.session.riderName}',
                  style: adminType(16, FontWeight.w700, AdminTokens.text),
                ),
              ),
              Text(detail.session.status, style: adminType(12, FontWeight.w700, AdminTokens.primary)),
            ],
          ),
          Text(detail.session.sessionCode, style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _moneyCard('Expected', ledger.expectedCash),
              _moneyCard('Declared', ledger.declaredCash),
              _moneyCard('In Vault', ledger.physicallyReceived),
            ],
          ),
          const SizedBox(height: 12),
          Text('RIDER ANNOTATION', style: adminType(11.5, FontWeight.w700, AdminTokens.textSecondary)),
          const SizedBox(height: 4),
          Text(
            (detail.riderAnnotation ?? '').trim().isEmpty
                ? 'No annotation was returned.'
                : detail.riderAnnotation!,
            style: adminType(13, FontWeight.w600, AdminTokens.text, height: 1.35),
          ),
          const SizedBox(height: 12),
          Text(
            'Net variance: ${ledger.netVariance == null ? '—' : formatPkr(ledger.netVariance!)}',
            style: adminType(13.5, FontWeight.w700, AdminTokens.text),
          ),
          const SizedBox(height: 12),
          Text('VAN STOCK', style: adminType(11.5, FontWeight.w700, AdminTokens.textSecondary)),
          if (detail.stockNote != null) Text(detail.stockNote!, style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary)),
          for (final card in [...detail.fullBottles, ...detail.emptyReturns])
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(card.productName.isEmpty ? card.sku : card.productName),
              subtitle: Text(
                [
                  if (card.loaded != null) 'Loaded ${card.loaded}',
                  if (card.sold != null) 'Sold ${card.sold}',
                  if (card.expected != null) 'Expected ${card.expected}',
                  if (card.declared != null) 'Declared ${card.declared}',
                  if (card.discrepancy != null) 'Disc ${card.discrepancy}',
                ].join(' · '),
              ),
            ),
          if (detail.fullBottles.isEmpty && detail.emptyReturns.isEmpty)
            Text('No stock reconciliation rows were returned.', style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary)),
          const SizedBox(height: 12),
          Text('MANAGER SETTLEMENT DECISION', style: adminType(11.5, FontWeight.w700, AdminTokens.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _verified,
            enabled: detail.canEdit && !_actionBusy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(
              labelText: 'Cashier verified cash (PKR)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: detail.resolutionCategories.contains(_category) ? _category : null,
            items: [
              for (final item in detail.resolutionCategories)
                DropdownMenuItem(value: item, child: Text(_categoryLabel(item))),
            ],
            onChanged: !detail.canEdit || _actionBusy
                ? null
                : (value) => setState(() => _category = value),
            decoration: const InputDecoration(
              labelText: 'Variance resolution category',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _remarks,
            enabled: detail.canEdit && !_actionBusy,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Manager settlement remarks',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: !detail.canEdit || _actionBusy ? null : _saveDraft,
                child: const Text('Save Draft'),
              ),
              OutlinedButton(
                onPressed: !detail.canEdit || _actionBusy ? null : _verifyCash,
                child: const Text('Verify Cash'),
              ),
              FilledButton(
                key: const Key('settlement-resolve'),
                onPressed: !detail.canEdit || _actionBusy ? null : _resolve,
                style: adminPrimaryButton(),
                child: Text(_actionBusy ? 'Saving…' : 'Resolve & Approve'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('SETTLEMENT AUDIT TRAIL', style: adminType(11.5, FontWeight.w700, AdminTokens.textSecondary)),
          const SizedBox(height: 6),
          if (detail.auditTrail.isEmpty)
            Text('No settlement audit events were returned.', style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary))
          else
            for (final event in detail.auditTrail)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(event.title, style: adminType(13, FontWeight.w700, AdminTokens.text)),
                subtitle: Text(
                  [
                    event.detail,
                    event.actorName,
                    event.occurredAt?.toLocal().toString(),
                  ].where((part) => part != null && part.toString().trim().isNotEmpty).join(' · '),
                ),
              ),
        ],
      ),
    );
  }

  Widget _moneyCard(String label, num? value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTokens.line),
        color: AdminTokens.page,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: adminType(11, FontWeight.w600, AdminTokens.textSecondary)),
          const SizedBox(height: 4),
          Text(value == null ? '—' : formatPkr(value), style: adminType(15, FontWeight.w700, AdminTokens.text)),
        ],
      ),
    );
  }

  String _categoryLabel(String value) {
    return switch (value) {
      'cashShortageRiderAccountable' => 'Cash shortage — rider accountable',
      'cashOverageRecorded' => 'Cash overage recorded',
      'countingErrorCorrected' => 'Counting error corrected',
      'pendingSyncResolved' => 'Pending sync resolved',
      'stockDiscrepancyNoted' => 'Stock discrepancy noted',
      'other' => 'Other',
      _ => value,
    };
  }
}
