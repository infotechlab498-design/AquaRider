import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class SalesManagementScreen extends StatefulWidget {
  const SalesManagementScreen({
    required this.onNavigate,
    this.session,
    this.refreshEvery = const Duration(seconds: 30),
    super.key,
  });

  final AuthSession? session;
  final ValueChanged<String> onNavigate;
  final Duration? refreshEvery;

  @override
  State<SalesManagementScreen> createState() => _SalesManagementScreenState();
}

class _SalesManagementScreenState extends State<SalesManagementScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _started = false;
  var _loading = true;
  var _page = 1;
  var _tab = 'All';
  var _listGeneration = 0;
  var _detailBusy = false;
  var _pageSize = 5;
  var _sync = 'All';
  String? _selectedId;
  String? _riderId;
  DateTime _date = _today();
  List<RiderRecord> _riders = const [];
  Timer? _refresh;

  AdminLoad<AdminSalesSummary>? _summary;
  AdminLoad<AdminSalePage>? _pageData;
  AdminLoad<AdminSaleDetail>? _detail;

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
    final every = widget.refreshEvery;
    if (every != null) {
      _refresh = Timer.periodic(every, (_) {
        if (!mounted || _loading) return;
        _reload();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _listGeneration++;
    _debounce?.cancel();
    _refresh?.cancel();
    _search.dispose();
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
      () => api.adminSalesSummary(date: _dateIso),
    );
    final page = await guardAdminLoad(
      () => api.adminSales(
        date: _dateIso,
        type: _tab,
        syncStatus: _sync == 'All' ? null : _sync,
        riderId: _riderId,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        page: _page,
        pageSize: _pageSize,
      ),
    );
    var riders = _riders;
    try {
      riders = await api.riderOperationsRiders(date: _dateIso);
    } catch (_) {
      riders = _riders;
    }
    if (!mounted || generation != _listGeneration) return;
    setState(() {
      _summary = summary;
      _pageData = page;
      _riders = riders;
      _loading = false;
    });
    final selected = _selectedId;
    final rows = page.value?.rows ?? const <AdminSaleRow>[];
    if (selected != null && rows.any((row) => row.id == selected)) {
      await _loadDetail(selected);
    } else if (rows.isNotEmpty) {
      await _loadDetail(rows.first.id);
    } else {
      setState(() {
        _selectedId = null;
        _detail = null;
      });
    }
  }

  Future<void> _loadDetail(String id) async {
    setState(() {
      _selectedId = id;
      _detailBusy = true;
    });
    final detail = await guardAdminLoad(
      () => ApiScope.of(context).adminSaleDetail(id),
    );
    if (!mounted || _selectedId != id) return;
    setState(() {
      _detail = detail;
      _detailBusy = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _page = 1;
    });
    await _reload();
  }

  void _resetFilters() {
    setState(() {
      _search.clear();
      _tab = 'All';
      _sync = 'All';
      _riderId = null;
      _page = 1;
      _pageSize = 5;
      _date = _today();
    });
    _reload();
  }

  void _setTab(String tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _page = 1;
    });
    _reload();
  }

  String get _dateLabel {
    final today = _today();
    final sameDay =
        _date.year == today.year && _date.month == today.month && _date.day == today.day;
    final label = _compactDay(_date);
    return sameDay ? 'Today · $label' : label;
  }

  String _compactDay(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String? get _searchTerm {
    final text = _search.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _exportCsv() async {
    final api = ApiScope.of(context);
    final rows = <AdminSaleRow>[];
    try {
      var page = 1;
      var totalPages = 1;
      while (page <= totalPages && page <= 20) {
        final result = await api.adminSales(
          date: _dateIso,
          type: _tab,
          syncStatus: _sync == 'All' ? null : _sync,
          riderId: _riderId,
          search: _searchTerm,
          page: page,
          pageSize: 100,
        );
        rows.addAll(result.rows);
        totalPages = result.totalPages;
        if (result.rows.isEmpty) break;
        page++;
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
      return;
    } catch (_) {
      if (!mounted) return;
      showAdminNotice(context, adminUnreachableMessage);
      return;
    }
    if (!mounted) return;
    if (rows.isEmpty) {
      showAdminNotice(context, 'No sales matched the filters to export.');
      return;
    }
    final csv = StringBuffer(
      'Receipt,Time,Customer,Code,Rider,Vehicle,Items,Gross,Received,Credit,Tender,Sync,Status\n',
    );
    for (final row in rows) {
      csv.writeln([
        row.receiptNumber,
        formatAdminStamp(row.createdAtUtc),
        row.customerName,
        row.customerCode,
        row.riderName,
        row.vehicleLabel ?? '',
        row.itemsSummary,
        row.grossAmount.toString(),
        row.amountReceived.toString(),
        row.creditAmount.toString(),
        row.tenderLabel,
        row.syncStatus,
        row.status,
      ].map(_csvCell).join(','));
    }
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (!mounted) return;
    final noun = rows.length == 1 ? 'sale' : 'sales';
    showAdminNotice(context, 'Copied ${rows.length} $noun as CSV.');
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  String _slip(AdminSaleDetail detail) {
    final buffer = StringBuffer()
      ..writeln(detail.receiptNumber)
      ..writeln(formatAdminStamp(detail.createdAtUtc))
      ..writeln('${detail.status} · ${detail.syncStatus}')
      ..writeln(detail.customerName)
      ..writeln(detail.customerCode);
    if (detail.customerAddress.trim().isNotEmpty) {
      buffer.writeln(detail.customerAddress);
    }
    if (detail.customerPhone.trim().isNotEmpty) {
      buffer.writeln(detail.customerPhone);
    }
    buffer
      ..writeln('${detail.riderName} ${detail.riderCode ?? ''}'.trim())
      ..writeln(detail.vehicleLabel ?? '');
    if (detail.lines.isEmpty) {
      buffer.writeln('No sale lines were returned.');
    } else {
      for (final line in detail.lines) {
        buffer.writeln(
          '${line.productName} x ${line.quantity} ${line.unit} @ ${formatPkr(line.unitPrice)} = ${formatPkr(line.lineTotal)}',
        );
      }
    }
    buffer
      ..writeln('Previous balance ${formatPkr(detail.previousOutstanding)}')
      ..writeln('Gross ${formatPkr(detail.grossAmount)}')
      ..writeln('Received ${formatPkr(detail.amountReceived)}')
      ..writeln('Credit ${formatPkr(detail.creditAmount)}')
      ..writeln('Remaining ${formatPkr(detail.remainingFromSale)}')
      ..writeln('Tender ${detail.paymentChannel ?? detail.tenderClass}');
    final assets = detail.returnableAssets;
    if (assets != null) {
      buffer.writeln(
        '${assets.assetType}: held ${assets.previousHeld}, issued ${assets.issued}, returned ${assets.returned}, closing ${assets.closingBalance}',
      );
    }
    if (detail.signerName != null) {
      buffer.writeln('Signed by ${detail.signerName} ${detail.signerRole ?? ''}'.trim());
    }
    return buffer.toString().trim();
  }

  Future<void> _printSlip(AdminSaleDetail detail) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('sales-slip-dialog'),
        title: Text(detail.receiptNumber),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No thermal printer is paired. Copy this slip to print it.',
                  style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
                ),
                const SizedBox(height: 12),
                SelectableText(_slip(detail)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _slip(detail)));
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Copy slip'),
          ),
        ],
      ),
    );
  }

  Future<void> _copySlip(AdminSaleDetail detail) async {
    await Clipboard.setData(ClipboardData(text: _slip(detail)));
    if (!mounted) return;
    showAdminNotice(
      context,
      'Receipt text copied. This sale does not have a PDF file.',
    );
  }

  Future<void> _whatsapp(AdminSaleDetail detail) async {
    final digits = _whatsappDigits(detail.customerPhone);
    if (digits == null) {
      showAdminNotice(context, 'This receipt has no customer phone number.');
      return;
    }
    final uri = Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(_slip(detail))}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: _slip(detail)));
    if (!mounted) return;
    showAdminNotice(context, 'WhatsApp did not open. The slip was copied instead.');
  }

  String? _whatsappDigits(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return null;
    if (digits.startsWith('0')) return '92${digits.substring(1)}';
    return digits;
  }

  Future<void> _openManualInvoice() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManualInvoiceDialog(api: ApiScope.of(context)),
    );
    if (created == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[?_summary, ?_pageData, ?_detail];
    final summary = _summary?.value;
    final page = _pageData?.value;
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    return AdminShell(
      screenKey: const Key('sales-management-screen'),
      session: widget.session,
      activeKey: AdminNav.salesManagement,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search receipt #, store name, customer code or rider...',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && summary == null
          ? const AdminLoadingPane(label: 'Loading sales ledger…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                _header(),
                const SizedBox(height: 16),
                if (_summary?.error != null && summary == null)
                  _error(_summary!.error!)
                else if (summary != null) ...[
                  _kpiRow(summary),
                  const SizedBox(height: 16),
                  _tabs(summary),
                  const SizedBox(height: 12),
                  _filters(),
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _ledger(page)),
                        const SizedBox(width: 16),
                        SizedBox(width: 360, child: _detailPanel()),
                      ],
                    )
                  else ...[
                    _ledger(page),
                    const SizedBox(height: 16),
                    _detailPanel(),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _header() {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Operations  ›  Sales',
          style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          'Sales Management & Transactions',
          style: adminType(26, FontWeight.w700, AdminTokens.text, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          'Review field sales, doorstep delivery invoices, payment tender, and returnable container receipts.',
          style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const Key('sales-date'),
          style: adminOutlineButton(),
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(_dateLabel),
        ),
        OutlinedButton.icon(
          key: const Key('sales-export'),
          style: adminOutlineButton(),
          onPressed: _exportCsv,
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Export (CSV)'),
        ),
        FilledButton.icon(
          key: const Key('sales-manual-invoice'),
          style: FilledButton.styleFrom(
            backgroundColor: AdminTokens.button,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _openManualInvoice,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Manual Invoice Entry'),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: title), actions],
        );
      },
    );
  }

  Widget _kpiRow(AdminSalesSummary summary) {
    final change = summary.billedChangePercent;
    final billedHint = change == null
        ? '${summary.billedTransactionCount} txns'
        : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% vs prior day · ${summary.billedTransactionCount} txns';
    final cards = [
      _SaleKpi(
        "Today's Billed Sales",
        formatPkr(summary.todaysBilledSales),
        billedHint,
        Icons.receipt_long_outlined,
        hintColor: change == null || change >= 0
            ? AdminTokens.success
            : AdminTokens.error,
      ),
      _SaleKpi(
        'Cash Sales Inward',
        formatPkr(summary.cashSalesInward),
        '${summary.cashSaleCount} cash spot sales',
        Icons.payments_outlined,
      ),
      _SaleKpi(
        'Credit Receivables',
        formatPkr(summary.creditReceivablesFromSales),
        '${summary.creditSaleCount} credit sales',
        Icons.account_balance_outlined,
      ),
      _SaleKpi(
        'Completed Sales',
        '${summary.completedSales}',
        'Posted transactions',
        Icons.check_circle_outline,
      ),
      _SaleKpi(
        'Average Sale Value',
        formatPkr(summary.averageSaleValue),
        'Eligible posted sales',
        Icons.inventory_2_outlined,
      ),
      _SaleKpi(
        'Pending Sync',
        '${summary.syncAttentionCount}',
        '${summary.pendingSyncCount} pending · ${summary.failedSyncCount} failed',
        Icons.sync_problem_outlined,
        emphasize: summary.syncAttentionCount > 0,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 980
            ? 6
            : constraints.maxWidth >= 640
                ? 3
                : 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: (constraints.maxWidth - (cols - 1) * 12) / cols,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminTokens.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: card.emphasize ? AdminTokens.error : AdminTokens.line,
                    ),
                    boxShadow: AdminTokens.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              card.label.toUpperCase(),
                              style: adminType(
                                11,
                                FontWeight.w700,
                                AdminTokens.textSecondary,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: card.emphasize
                                  ? AdminTokens.errorBg
                                  : AdminTokens.field,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              card.icon,
                              size: 16,
                              color: card.emphasize
                                  ? AdminTokens.error
                                  : AdminTokens.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        card.value,
                        style: adminType(
                          22,
                          FontWeight.w700,
                          card.emphasize ? AdminTokens.error : AdminTokens.text,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.hint,
                        style: adminType(
                          11.5,
                          FontWeight.w600,
                          card.emphasize
                              ? AdminTokens.error
                              : (card.hintColor ?? AdminTokens.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tabs(AdminSalesSummary summary) {
    final items = [
      ('All', 'All Sales', summary.completedSales),
      ('Cash', 'Cash Spot Sales', summary.cashSaleCount),
      ('Credit', 'Credit Ledger Sales', summary.creditSaleCount),
      ('PendingSync', 'Pending Sync', summary.syncAttentionCount),
    ];
    final every = widget.refreshEvery;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminTokens.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in items) _tabButton(item.$1, item.$2, item.$3),
                ],
              ),
            ),
          ),
          if (every != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 12),
              child: Text(
                'Refreshing every ${every.inSeconds}s',
                style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabButton(String id, String label, int count) {
    final selected = _tab == id;
    final attention = id == 'PendingSync' && count > 0;
    return InkWell(
      key: Key('sales-tab-$id'),
      onTap: () => _setTab(id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 8, 16, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AdminTokens.button : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: adminType(
                13.5,
                FontWeight.w700,
                selected ? AdminTokens.button : AdminTokens.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: attention
                    ? AdminTokens.errorBg
                    : selected
                        ? AdminTokens.primarySoft
                        : AdminTokens.field,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: adminType(
                  11.5,
                  FontWeight.w700,
                  attention
                      ? AdminTokens.error
                      : selected
                          ? AdminTokens.button
                          : AdminTokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    final riderItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('All riders')),
      for (final rider in _riders)
        DropdownMenuItem(
          value: rider.id,
          child: Text(
            rider.riderCode.isEmpty
                ? rider.fullName
                : '${rider.fullName} · ${rider.riderCode}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    if (_riderId != null && _riders.every((rider) => rider.id != _riderId)) {
      riderItems.add(
        DropdownMenuItem(value: _riderId, child: Text(_riderId!)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final fieldWidth = wide ? 340.0 : constraints.maxWidth;
        final menuWidth = wide ? 190.0 : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: fieldWidth,
              child: TextField(
                key: const Key('sales-search'),
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search receipt #, store name, customer code or rider...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AdminTokens.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AdminTokens.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AdminTokens.line),
                  ),
                ),
              ),
            ),
            _menu<String>(
              keyName: 'sales-tender',
              width: menuWidth,
              value: _tab,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All tender types')),
                DropdownMenuItem(value: 'Cash', child: Text('Cash spot')),
                DropdownMenuItem(value: 'Credit', child: Text('Credit ledger')),
                DropdownMenuItem(value: 'PendingSync', child: Text('Pending sync')),
              ],
              onChanged: (value) {
                if (value == null) return;
                _setTab(value);
              },
            ),
            _menu<String?>(
              keyName: 'sales-rider',
              width: menuWidth,
              value: _riderId,
              items: riderItems,
              onChanged: (value) {
                setState(() {
                  _riderId = value;
                  _page = 1;
                });
                _reload();
              },
            ),
            _menu<String>(
              keyName: 'sales-sync',
              width: menuWidth,
              value: _sync,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('Sync: all')),
                DropdownMenuItem(value: 'Synced', child: Text('Synced')),
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Failed', child: Text('Failed')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _sync = value;
                  _page = 1;
                });
                _reload();
              },
            ),
            OutlinedButton(
              key: const Key('sales-reset'),
              style: adminOutlineButton(),
              onPressed: _resetFilters,
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  Widget _menu<T>({
    required String keyName,
    required double width,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        key: ValueKey('$keyName-$value'),
        initialValue: value,
        isExpanded: true,
        isDense: true,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AdminTokens.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AdminTokens.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AdminTokens.line),
          ),
        ),
      ),
    );
  }

  Widget _ledger(AdminSalePage? page) {
    if (_pageData?.error != null && page == null) {
      return _error(_pageData!.error!);
    }
    final rows = page?.rows ?? const <AdminSaleRow>[];
    return Container(
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Ledger Entries',
                  style: adminType(15, FontWeight.w700, AdminTokens.text),
                ),
                const SizedBox(height: 2),
                Text(
                  page == null
                      ? 'Recorded sales for this day'
                      : 'Displaying ${_rangeStart(page, rows.length)}–${_rangeEnd(page, rows.length)} of ${page.totalRecords} recorded sales',
                  style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                ),
              ],
            ),
          ),
          _ledgerHead(),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No sales matched the filters for ${formatAdminDay(_date)}.',
                style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
              ),
            )
          else
            for (final row in rows) _ledgerRow(row),
          if (page != null) _pager(page, rows.length),
        ],
      ),
    );
  }

  int _rangeStart(AdminSalePage page, int shown) {
    if (page.totalRecords == 0 || shown == 0) return 0;
    return ((page.page - 1) * page.pageSize) + 1;
  }

  int _rangeEnd(AdminSalePage page, int shown) {
    final start = _rangeStart(page, shown);
    if (start == 0) return 0;
    return start + shown - 1;
  }

  Widget _ledgerHead() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AdminTokens.field,
      child: Row(
        children: [
          _headCell('Receipt & time', 16),
          _headCell('Customer / store', 18),
          _headCell('Rider & van', 16),
          _headCell('Items', 14),
          _headCell('Gross', 12),
          _headCell('Recv / credit', 12),
          _headCell('Tender', 12),
          _headCell('Sync', 10),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _headCell(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: adminType(10.5, FontWeight.w700, AdminTokens.textSecondary, letterSpacing: 0.3),
      ),
    );
  }

  Widget _ledgerRow(AdminSaleRow row) {
    final selected = row.id == _selectedId;
    return Material(
      color: selected ? AdminTokens.primarySoft : Colors.transparent,
      child: InkWell(
        key: Key('sales-row-${row.id}'),
        onTap: () => _loadDetail(row.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AdminTokens.line)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 16,
                child: _twoLine(row.receiptNumber, formatAdminStamp(row.createdAtUtc), strong: true),
              ),
              Expanded(
                flex: 18,
                child: _twoLine(row.customerName, row.customerCode),
              ),
              Expanded(
                flex: 16,
                child: _twoLine(row.riderName, row.vehicleLabel ?? '—'),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  row.itemsSummary.isEmpty ? '—' : row.itemsSummary,
                  style: adminType(12.5, FontWeight.w500, AdminTokens.text),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  formatPkr(row.grossAmount),
                  style: adminType(12.5, FontWeight.w700, AdminTokens.text),
                ),
              ),
              Expanded(
                flex: 12,
                child: _twoLine(
                  formatPkr(row.amountReceived),
                  '${formatPkr(row.creditAmount)} credit',
                ),
              ),
              Expanded(flex: 12, child: _tenderPill(row.tenderLabel, row.tenderClass)),
              Expanded(flex: 10, child: _syncPill(row.syncStatus)),
              SizedBox(
                width: 36,
                child: IconButton(
                  tooltip: 'Open receipt',
                  onPressed: () => _loadDetail(row.id),
                  icon: Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: selected ? AdminTokens.button : AdminTokens.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _twoLine(String title, String subtitle, {bool strong = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.isEmpty ? '—' : title,
          style: adminType(
            12.5,
            strong ? FontWeight.w700 : FontWeight.w600,
            strong ? AdminTokens.button : AdminTokens.text,
          ),
        ),
        Text(
          subtitle,
          style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
        ),
      ],
    );
  }

  Widget _pager(AdminSalePage page, int shown) {
    final pages = page.totalPages < 1 ? 1 : page.totalPages;
    final windowStart = (page.page - 2).clamp(1, pages).toInt();
    final windowEnd = (windowStart + 4).clamp(1, pages).toInt();
    final first = (windowEnd - 4).clamp(1, windowStart).toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Rows per page',
            style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
          ),
          SizedBox(
            width: 84,
            child: DropdownButtonFormField<int>(
              key: ValueKey('sales-page-size-$_pageSize'),
              initialValue: _pageSize,
              isDense: true,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 20, child: Text('20')),
                DropdownMenuItem(value: 30, child: Text('30')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _pageSize = value;
                  _page = 1;
                });
                _reload();
              },
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Text(
            'Showing ${_rangeStart(page, shown)}–${_rangeEnd(page, shown)} of ${page.totalRecords}',
            style: adminType(12.5, FontWeight.w600, AdminTokens.text),
          ),
          IconButton(
            key: const Key('sales-prev'),
            onPressed: page.page <= 1
                ? null
                : () {
                    setState(() => _page = page.page - 1);
                    _reload();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          for (var number = first; number <= windowEnd; number++)
            _pageButton(number, page.page),
          IconButton(
            key: const Key('sales-next'),
            onPressed: page.page >= pages
                ? null
                : () {
                    setState(() => _page = page.page + 1);
                    _reload();
                  },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _pageButton(int number, int current) {
    final selected = number == current;
    return InkWell(
      key: Key('sales-page-$number'),
      onTap: selected
          ? null
          : () {
              setState(() => _page = number);
              _reload();
            },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AdminTokens.button : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AdminTokens.button : AdminTokens.line),
        ),
        child: Text(
          '$number',
          style: adminType(
            12.5,
            FontWeight.w700,
            selected ? Colors.white : AdminTokens.text,
          ),
        ),
      ),
    );
  }

  Widget _detailPanel() {
    if (_detailBusy && _detail?.value == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final detail = _detail?.value;
    if (_detail?.error != null && detail == null) {
      return _error(_detail!.error!);
    }
    if (detail == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AdminTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTokens.line),
        ),
        child: Text(
          'Select a sale to view receipt details.',
          style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
        ),
      );
    }
    final assets = detail.returnableAssets;
    return Container(
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
        boxShadow: AdminTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              color: AdminTokens.navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _syncPill(detail.syncStatus, onDark: true),
                    const Spacer(),
                    Text(
                      formatAdminStamp(detail.createdAtUtc),
                      style: adminType(11, FontWeight.w600, AdminTokens.promoMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  detail.receiptNumber,
                  style: adminType(18, FontWeight.w700, Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  detail.status,
                  style: adminType(12, FontWeight.w600, AdminTokens.promoTitle),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('Store / party', [
                  detail.customerName,
                  detail.customerCode,
                  detail.customerAddress,
                  detail.customerPhone,
                  if (detail.depotName.isNotEmpty) detail.depotName,
                ]),
                _section('Rider & vehicle', [
                  detail.riderName,
                  detail.riderCode ?? detail.riderId,
                  detail.vehicleLabel ?? '—',
                  detail.routeName ?? '—',
                ]),
                Text('Description', style: adminType(13, FontWeight.w700, AdminTokens.text)),
                const SizedBox(height: 6),
                if (detail.lines.isEmpty)
                  Text(
                    'No sale lines were returned.',
                    style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
                  )
                else
                  for (final line in detail.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${line.productName}\n${line.quantity} ${line.unit} @ ${formatPkr(line.unitPrice)}',
                              style: adminType(12.5, FontWeight.w600, AdminTokens.text),
                            ),
                          ),
                          Text(
                            formatPkr(line.lineTotal),
                            style: adminType(12.5, FontWeight.w700, AdminTokens.text),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 8),
                _moneyRow('Previous balance', formatPkr(detail.previousOutstanding)),
                _moneyRow('Gross', formatPkr(detail.grossAmount), strong: true),
                _moneyRow(
                  'Received · ${detail.paymentChannel ?? detail.tenderClass}',
                  formatPkr(detail.amountReceived),
                ),
                _moneyRow('Credit from this sale', formatPkr(detail.creditAmount)),
                _moneyRow('Remaining from this sale', formatPkr(detail.remainingFromSale), strong: true),
                const SizedBox(height: 12),
                _section(
                  'Returnable containers',
                  assets == null
                      ? const ['No returnable container movement was recorded on this receipt.']
                      : [
                          assets.assetType,
                          'Held ${assets.previousHeld} · Issued ${assets.issued} · Returned ${assets.returned}',
                          'Closing ${assets.closingBalance}',
                        ],
                ),
                _section(
                  'Proof of delivery',
                  detail.signerName == null
                      ? const ['No proof of delivery was stored for this receipt.']
                      : [
                          '${detail.signerName}${detail.signerRole == null ? '' : ' (${detail.signerRole})'}',
                          detail.hasSignatureImage
                              ? 'Signature image is on file.'
                              : 'No signature image is stored.',
                          if (detail.signedAtUtc != null)
                            formatAdminStamp(detail.signedAtUtc!),
                          if (detail.signatureNote != null) detail.signatureNote!,
                        ],
                ),
                if (detail.scopeNote.isNotEmpty)
                  Text(
                    detail.scopeNote,
                    style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('sales-print'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminTokens.button,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _printSlip(detail),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print slip'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('sales-download'),
                        style: adminOutlineButton(),
                        onPressed: () => _copySlip(detail),
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Copy receipt'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('sales-whatsapp'),
                        style: adminOutlineButton(),
                        onPressed: () => _whatsapp(detail),
                        icon: const Icon(Icons.chat_outlined, size: 16),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: adminType(
                12.5,
                strong ? FontWeight.w700 : FontWeight.w500,
                AdminTokens.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: adminType(
              12.5,
              strong ? FontWeight.w700 : FontWeight.w600,
              AdminTokens.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> lines) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminType(13, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 4),
          for (final line in lines)
            if (line.trim().isNotEmpty)
              Text(
                line,
                style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
              ),
        ],
      ),
    );
  }

  Widget _syncPill(String status, {bool onDark = false}) {
    final synced = status.toLowerCase() == 'synced';
    final failed = status.toLowerCase() == 'failed';
    final color = synced
        ? AdminTokens.success
        : failed
            ? AdminTokens.error
            : AdminTokens.warning;
    final background = synced ? AdminTokens.successSoft : failed ? AdminTokens.errorBg : AdminTokens.warningBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty ? '—' : status,
        style: adminType(11, FontWeight.w700, status.isEmpty ? AdminTokens.textSecondary : color),
      ),
    );
  }

  Widget _tenderPill(String label, String tenderClass) {
    final kind = tenderClass.toLowerCase();
    final credit = kind == 'credit';
    final cash = kind == 'cash';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: credit
              ? AdminTokens.primarySoft
              : cash
                  ? AdminTokens.field
                  : AdminTokens.warningBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.trim().isEmpty ? (tenderClass.isEmpty ? '—' : tenderClass) : label,
          overflow: TextOverflow.ellipsis,
          style: adminType(
            11,
            FontWeight.w700,
            credit
                ? AdminTokens.button
                : cash
                    ? AdminTokens.secondary
                    : AdminTokens.warning,
          ),
        ),
      ),
    );
  }

  Widget _error(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.errorBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: adminType(13.5, FontWeight.w600, AdminTokens.error)),
    );
  }
}

class _SaleKpi {
  const _SaleKpi(
    this.label,
    this.value,
    this.hint,
    this.icon, {
    this.emphasize = false,
    this.hintColor,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final bool emphasize;
  final Color? hintColor;
}

class ManualInvoiceDialog extends StatefulWidget {
  const ManualInvoiceDialog({required this.api, super.key});

  final RouteApi api;

  @override
  State<ManualInvoiceDialog> createState() => _ManualInvoiceDialogState();
}

class _ManualInvoiceDialogState extends State<ManualInvoiceDialog> {
  final _signer = TextEditingController(text: 'Store Manager');
  final _qty = TextEditingController(text: '1');
  final _received = TextEditingController();
  var _busy = false;
  String? _error;
  String? _riderId;
  String? _customerId;
  String? _productId;
  var _payment = 'Cash';
  List<StaffUser> _riders = const [];
  List<AdminCustomerRow> _customers = const [];
  List<ProductBasePriceRow> _products = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _signer.dispose();
    _qty.dispose();
    _received.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _busy = true);
    try {
      final riders = await widget.api.staffUsers(
        role: 'Rider',
        isActive: true,
        pageSize: 100,
      );
      final customers = await widget.api.adminCustomers(
        status: 'Active',
        pageSize: 100,
      );
      final products = await widget.api.productCatalogue(pageSize: 100);
      if (!mounted) return;
      setState(() {
        _riders = riders.rows
            .where((row) => row.routeId != null && row.vehicleId != null)
            .toList();
        _customers = customers.rows;
        _products = products.rows
            .where((row) => (row.effectiveBasePrice ?? row.baseSystemPrice) != null)
            .toList();
        _riderId = _riders.isEmpty ? null : _riders.first.id;
        _customerId = _customers.isEmpty ? null : _customers.first.id;
        _productId = _products.isEmpty ? null : _products.first.id;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  Future<void> _submit() async {
    final riderId = _riderId;
    final customerId = _customerId;
    final productId = _productId;
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    if (riderId == null || customerId == null || productId == null || qty <= 0) {
      setState(() => _error = 'Select rider, customer, product and a positive quantity.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.api.adminCreateSaleDraft(
        riderUserId: riderId,
        customerId: customerId,
        lines: [
          {'productId': productId, 'quantity': qty},
        ],
      );
      num? amountReceived;
      if (_payment == 'Credit') {
        amountReceived = 0;
      } else if (_payment == 'Partial') {
        amountReceived = num.tryParse(_received.text.trim());
        if (amountReceived == null || amountReceived <= 0 || amountReceived >= draft.saleAmount) {
          setState(() {
            _busy = false;
            _error = 'Partial cash requires 0 < amount received < sale total.';
          });
          return;
        }
      } else {
        amountReceived = draft.amountDue;
      }
      await widget.api.adminCompleteSale(
        draft.id,
        paymentMethod: 'Cash',
        amountReceived: amountReceived,
        signerName: _signer.text.trim().isEmpty ? 'Store Manager' : _signer.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manual Invoice Entry'),
      content: SizedBox(
        width: 480,
        child: _busy && _riders.isEmpty && _error == null
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: adminType(13, FontWeight.w600, AdminTokens.error),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _riderId,
                      decoration: const InputDecoration(labelText: 'Rider'),
                      items: [
                        for (final rider in _riders)
                          DropdownMenuItem(
                            value: rider.id,
                            child: Text('${rider.fullName} (${rider.riderCode ?? rider.id})'),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _riderId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _customerId,
                      decoration: const InputDecoration(labelText: 'Customer'),
                      items: [
                        for (final customer in _customers)
                          DropdownMenuItem(
                            value: customer.id,
                            child: Text('${customer.businessName} (${customer.code})'),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _customerId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _productId,
                      decoration: const InputDecoration(labelText: 'Product'),
                      items: [
                        for (final product in _products)
                          DropdownMenuItem(
                            value: product.id,
                            child: Text(
                              '${product.name} · ${formatPkr(product.effectiveBasePrice ?? product.baseSystemPrice ?? 0)}',
                            ),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _productId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _qty,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _payment,
                      decoration: const InputDecoration(labelText: 'Payment'),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash (full)')),
                        DropdownMenuItem(value: 'Credit', child: Text('Full credit')),
                        DropdownMenuItem(value: 'Partial', child: Text('Partial cash')),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _payment = value ?? 'Cash'),
                    ),
                    if (_payment == 'Partial') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _received,
                        decoration: const InputDecoration(
                          labelText: 'Amount received (PKR)',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _signer,
                      decoration: const InputDecoration(labelText: 'Signer name'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Server validates catalogue prices and van stock for the selected rider. Bank/Wallet posting is disabled in Locked V1.',
                      style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Posting…' : 'Post Sale'),
        ),
      ],
    );
  }
}
