import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final _shellSearch = TextEditingController();
  final _filter = TextEditingController();
  var _started = false;
  var _loading = true;
  var _saving = false;
  var _location = 'all';
  var _compact = false;
  DateTime _date = _today();
  AdminLoad<DepotOperations>? _ops;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _dateIso =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _filter.addListener(() {
      if (mounted) setState(() {});
    });
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
    _shellSearch.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final ops = await guardAdminLoad(() => api.depotSummary(date: _dateIso));
    if (!mounted) return;
    setState(() {
      _ops = ops;
      _loading = false;
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
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    await _reload();
  }

  void _unavailable(String feature) {
    showAdminNotice(
      context,
      '$feature is not available in Locked V1 (single Main Warehouse).',
    );
  }

  Future<void> _addHub() async {
    final name = TextEditingController();
    final gate = TextEditingController();
    final address = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add warehouse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: gate, decoration: const InputDecoration(labelText: 'Gate')),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    final values = (name.text.trim(), gate.text.trim(), address.text.trim());
    name.dispose();
    gate.dispose();
    address.dispose();
    if (saved != true || !mounted) return;
    try {
      await ApiScope.of(context).createWarehouse(name: values.$1, gate: values.$2, address: values.$3);
      if (!mounted) return;
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    }
  }

  Future<void> _count(DepotOperations ops) async {
    if (ops.stock.isEmpty) {
      showAdminNotice(context, 'No products are available to count at this warehouse.');
      return;
    }
    var productId = ops.stock.first.productId;
    final counted = TextEditingController(text: '${ops.stock.first.depotExpected}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Inventory count'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: productId,
                items: [
                  for (final line in ops.stock)
                    DropdownMenuItem(value: line.productId, child: Text(line.productName)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setLocal(() => productId = value);
                },
                decoration: const InputDecoration(labelText: 'Product'),
              ),
              TextField(
                controller: counted,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Counted quantity'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save count')),
          ],
        ),
      ),
    );
    final quantity = int.tryParse(counted.text.trim());
    counted.dispose();
    if (saved != true || !mounted) return;
    if (quantity == null) {
      showAdminNotice(context, 'Enter the counted quantity.');
      return;
    }
    try {
      await ApiScope.of(context).recordInventoryCount(depotId: ops.depot.id, productId: productId, countedQuantity: quantity);
      if (!mounted) return;
      showAdminNotice(context, 'Warehouse stock was set to the counted quantity. Van stock was not changed.');
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    }
  }

  bool _matches(DepotDetail depot) {
    final query = _filter.text.trim().toLowerCase();
    final blob = '${depot.name} ${depot.code} ${depot.address} ${depot.classification}'.toLowerCase();
    if (query.isNotEmpty && !blob.contains(query)) return false;
    final kind = depot.classification.toLowerCase();
    final central = kind.contains('central') || kind.contains('primary');
    final satellite = kind.contains('satellite');
    return switch (_location) {
      'central' => central,
      'satellite' => satellite,
      'unassigned' => !central && !satellite,
      _ => true,
    };
  }

  Future<void> _exportDirectory(DepotOperations ops) async {
    final csv = StringBuffer(
      'Name,Code,Classification,Status,Address,Gate,Fleet,Active vehicles,Dispatch orders,Dispatch volume,Linked stores,Billed\n',
    );
    final depot = ops.depot;
    final kpis = ops.kpis;
    csv.writeln([
      depot.name,
      depot.code,
      depot.classification,
      depot.status,
      depot.address,
      depot.gate,
      '${kpis.assignedFleet}',
      '${kpis.activeVehicles}',
      '${kpis.todaysDispatchOrders}',
      '${kpis.todaysDispatchVolume}',
      '${kpis.linkedStores}',
      ops.todaysBilledSales.toString(),
    ].map((value) => '"${value.replaceAll('"', '""')}"').join(','));
    csv.writeln('Vehicle,Plate,Rider,Stock units');
    for (final member in ops.fleet) {
      csv.writeln([
        member.vehicleName,
        member.plate,
        member.riderName ?? '',
        '${member.stockUnits}',
      ].map((value) => '"${value.replaceAll('"', '""')}"').join(','));
    }
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (!mounted) return;
    showAdminNotice(context, 'Copied the depot directory as CSV.');
  }

  Future<void> _showFleet(DepotOperations ops) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('warehouse-fleet-dialog'),
        title: Text(ops.depot.name),
        content: SizedBox(
          width: 460,
          child: ops.fleet.isEmpty
              ? const Text('No vehicles are registered.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final member in ops.fleet)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${member.vehicleName} · ${member.plate}'),
                        subtitle: Text(
                          member.riderName == null
                              ? 'Unassigned · ${member.stockUnits} units'
                              : '${member.riderName} · ${member.stockUnits} units',
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showStock(DepotOperations ops) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('warehouse-stock-dialog'),
        title: const Text('Depot stock'),
        content: SizedBox(
          width: 460,
          child: ops.stock.isEmpty
              ? const Text('No vehicle stock rows were found.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final line in ops.stock)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(line.productName),
                        subtitle: Text(line.sku),
                        trailing: Text('${line.quantityOnVans} / ${line.depotExpected}'),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _editSpecs() async {
    final current = _ops?.value?.depot;
    if (current == null) return;
    final name = TextEditingController(text: current.name);
    final gate = TextEditingController(text: current.gate);
    final address = TextEditingController(text: current.address);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit warehouse specs'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gate,
                decoration: const InputDecoration(labelText: 'Gate / bay'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) {
      name.dispose();
      gate.dispose();
      address.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiScope.of(context).updateDepot(
        name: name.text.trim(),
        gate: gate.text.trim(),
        address: address.text.trim(),
      );
      if (!mounted) return;
      showAdminNotice(context, 'Main warehouse updated.');
      await _reload();
    } on ApiException catch (error) {
      if (mounted) showAdminNotice(context, error.message);
    } finally {
      name.dispose();
      gate.dispose();
      address.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[?_ops];
    final ops = _ops?.value;
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    return AdminShell(
      screenKey: const Key('warehouse-screen'),
      session: widget.session,
      activeKey: AdminNav.branchesWarehouses,
      serverReachable: adminServerReachable(loads),
      search: _shellSearch,
      onSearch: (_) {},
      searchHint: 'Main warehouse console',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && ops == null
          ? const AdminLoadingPane(label: 'Loading main warehouse…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                _header(),
                const SizedBox(height: 16),
                if (ops != null) ...[
                  _kpiRow(ops.kpis),
                  const SizedBox(height: 12),
                  _toolbar(ops),
                  const SizedBox(height: 16),
                  if (!_matches(ops.depot))
                    _emptyFilter()
                  else if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _directoryCard(ops)),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _operationsPanel(ops)),
                      ],
                    )
                  else ...[
                    _directoryCard(ops),
                    const SizedBox(height: 16),
                    _operationsPanel(ops),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _header() {
    final ops = _ops?.value;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Team Management  ›  Branches & Warehouses',
          style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          'Branches & Warehouses Management',
          style: adminType(26, FontWeight.w700, AdminTokens.text, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          'Coordinate the registered depot, assigned fleet, van stock, and today\'s dispatch.',
          style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
        ),
        if (ops != null && ops.scopeNote.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(ops.scopeNote, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
        ],
        if (_ops?.error != null) ...[
          const SizedBox(height: 8),
          Text(
            _ops!.error!,
            style: adminType(13, FontWeight.w600, AdminTokens.error),
          ),
        ],
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          key: const Key('warehouse-export'),
          style: adminOutlineButton(),
          onPressed: ops == null ? null : () => _exportDirectory(ops),
          icon: const Icon(Icons.download_outlined, size: 16),
          label: const Text('Export Depot Directory'),
        ),
        OutlinedButton.icon(
          key: const Key('warehouse-add-branch'),
          style: adminOutlineButton(),
          onPressed: () => _unavailable('Add Branch Office'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Branch Office'),
        ),
        FilledButton.icon(
          key: const Key('warehouse-add-hub'),
          style: FilledButton.styleFrom(
            backgroundColor: AdminTokens.button,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _addHub,
          icon: const Icon(Icons.warehouse_outlined, size: 16),
          label: const Text('Add Warehouse Hub'),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: title), const SizedBox(width: 12), actions],
        );
      },
    );
  }

  Widget _toolbar(DepotOperations ops) {
    final kpis = ops.kpis;
    final unassigned = (kpis.totalDepots - kpis.centralWarehouses - kpis.satelliteHubs).clamp(0, 9999);
    final tabs = [
      ('all', 'All locations', kpis.totalDepots),
      ('central', 'Central warehouses', kpis.centralWarehouses),
      ('satellite', 'Satellite hubs', kpis.satelliteHubs),
      ('unassigned', 'Unassigned', unassigned),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final tab in tabs)
          InkWell(
            key: Key('warehouse-tab-${tab.$1}'),
            onTap: () => setState(() => _location = tab.$1),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _location == tab.$1 ? AdminTokens.button : AdminTokens.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _location == tab.$1 ? AdminTokens.button : AdminTokens.line,
                ),
              ),
              child: Text(
                '${tab.$2}  ${tab.$3}',
                style: adminType(
                  12.5,
                  FontWeight.w700,
                  _location == tab.$1 ? Colors.white : AdminTokens.text,
                ),
              ),
            ),
          ),
        SizedBox(
          width: 240,
          child: TextField(
            key: const Key('warehouse-search'),
            controller: _filter,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filter hub by code or city...',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: AdminTokens.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        OutlinedButton.icon(
          key: const Key('warehouse-date'),
          style: adminOutlineButton(),
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(formatAdminDay(_date)),
        ),
        IconButton(
          key: const Key('warehouse-list'),
          tooltip: 'List',
          onPressed: () => setState(() => _compact = false),
          icon: Icon(Icons.view_list, color: _compact ? AdminTokens.textSecondary : AdminTokens.button),
        ),
        IconButton(
          key: const Key('warehouse-grid'),
          tooltip: 'Compact',
          onPressed: () => setState(() => _compact = true),
          icon: Icon(Icons.grid_view, color: _compact ? AdminTokens.button : AdminTokens.textSecondary),
        ),
      ],
    );
  }

  Widget _emptyFilter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Text(
        'No warehouse matched this location filter.',
        style: adminType(13.5, FontWeight.w600, AdminTokens.textSecondary),
      ),
    );
  }

  Widget _kpiRow(DepotKpis kpis) {
    final cards = [
      _Kpi(
        'Total depots & hubs',
        '${kpis.totalDepots}',
        '${kpis.centralWarehouses} central · ${kpis.satelliteHubs} satellite',
        Icons.warehouse_outlined,
      ),
      _Kpi(
        'Active warehouses',
        '${kpis.activeWarehouses}',
        '${kpis.activePercent.toStringAsFixed(0)}% active',
        Icons.check_circle_outline,
      ),
      _Kpi(
        'Assigned fleet',
        '${kpis.assignedFleet}',
        '${kpis.activeVehicles} vehicles with an active rider',
        Icons.local_shipping_outlined,
      ),
      _Kpi(
        "Today's dispatch",
        '${kpis.todaysDispatchOrders}',
        '${kpis.todaysDispatchVolume} ${kpis.dispatchUnit}',
        Icons.water_drop_outlined,
      ),
      _Kpi(
        'Linked stores',
        '${kpis.linkedStores}',
        'Customer accounts',
        Icons.storefront_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 980
            ? 5
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
                child: _kpiCard(card),
              ),
          ],
        );
      },
    );
  }

  Widget _kpiCard(_Kpi card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTokens.line),
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
                  style: adminType(11, FontWeight.w700, AdminTokens.textSecondary, letterSpacing: 0.3),
                ),
              ),
              Icon(card.icon, size: 18, color: AdminTokens.secondary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            card.value,
            style: adminType(24, FontWeight.w700, AdminTokens.text, height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            card.hint,
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _directoryCard(DepotOperations ops) {
    final depot = ops.depot;
    final cap = ops.capacity;
    if (_compact) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AdminTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminTokens.primary, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(depot.name, style: adminType(16, FontWeight.w700, AdminTokens.text)),
            Text(depot.code, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
            const SizedBox(height: 8),
            Text(
              '${cap.utilizationPercent.toStringAsFixed(0)}% of van capacity in use',
              style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
            ),
            Text(
              "Today's billed ${formatPkr(ops.todaysBilledSales)}",
              style: adminType(13, FontWeight.w700, AdminTokens.text),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.primary, width: 1.5),
        boxShadow: AdminTokens.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  depot.name,
                  style: adminType(18, FontWeight.w700, AdminTokens.text),
                ),
              ),
              _pill(depot.classification, AdminTokens.primarySoft, AdminTokens.primary),
              const SizedBox(width: 8),
              _pill(depot.status, AdminTokens.successSoft, AdminTokens.success),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            depot.code,
            style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            '${depot.address}${depot.gate.isEmpty ? '' : ' · Gate ${depot.gate}'}',
            style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
          ),
          if (ops.managerName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Hub In-Charge: ${ops.managerName}',
              style: adminType(13, FontWeight.w600, AdminTokens.text),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            '${formatGrouped(cap.occupiedUnits)} / ${formatGrouped(cap.expectedUnits)} ${cap.unitLabel} (${cap.utilizationPercent.toStringAsFixed(0)}% utilized)',
            style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (cap.utilizationPercent / 100).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: AdminTokens.field,
              color: AdminTokens.primary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _stat('Dedicated Fleet', '${ops.kpis.assignedFleet} vans'),
              ),
              Expanded(
                child: _stat("Today's Output", '${ops.todaysCompletedSales} sales'),
              ),
              Expanded(
                child: _stat('Party Reach', '${ops.kpis.linkedStores} stores'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Today's billed: ${formatPkr(ops.todaysBilledSales)}",
            style: adminType(13, FontWeight.w600, AdminTokens.text),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('warehouse-bays'),
                style: adminOutlineButton(),
                onPressed: () => _unavailable('Configure Bays'),
                child: const Text('Configure bays'),
              ),
              FilledButton(
                key: const Key('warehouse-edit'),
                style: FilledButton.styleFrom(
                  backgroundColor: AdminTokens.button,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _saving ? null : _editSpecs,
                child: Text(_saving ? 'Saving…' : 'Manage depot'),
              ),
              OutlinedButton(
                key: const Key('warehouse-fleet'),
                style: adminOutlineButton(),
                onPressed: () => _showFleet(ops),
                child: const Text('Fleet roster'),
              ),
              OutlinedButton(
                key: const Key('warehouse-stock'),
                style: adminOutlineButton(),
                onPressed: () => _showStock(ops),
                child: const Text('Stock rollup'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _operationsPanel(DepotOperations ops) {
    return Column(
      children: [
        _panel(
          'Depot operations',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operational date ${formatAdminDay(_date)}',
                style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Capacity is units on assigned vans against the depot expected quantity. A corridor map is not stored for this depot.',
                style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          'Fleet Roster',
          ops.fleet.isEmpty
              ? Text(
                  'No vehicles are registered.',
                  style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
                )
              : Column(
                  children: [
                    for (final member in ops.fleet) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          '${member.vehicleName} · ${member.plate}',
                          style: adminType(13.5, FontWeight.w600, AdminTokens.text),
                        ),
                        subtitle: Text(
                          member.riderName == null
                              ? 'Unassigned · ${member.stockUnits} units'
                              : '${member.riderName} (${member.riderCode ?? '—'}) · ${member.stockUnits} units',
                          style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _panel(
          'Stock Custody Rollup',
          ops.stock.isEmpty
              ? Text(
                  'No vehicle stock rows were found.',
                  style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final line in ops.stock)
                      Container(
                        width: 140,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AdminTokens.field,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminTokens.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: adminType(12.5, FontWeight.w700, AdminTokens.text),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${line.quantityOnVans} on vans',
                              style: adminType(11.5, FontWeight.w600, AdminTokens.textSecondary),
                            ),
                            Text(
                              '${line.depotExpected} expected',
                              style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _panel(
          'Quick Operations',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                style: adminOutlineButton(),
                onPressed: _saving ? null : _editSpecs,
                child: const Text('Edit specs'),
              ),
              OutlinedButton(
                style: adminOutlineButton(),
                onPressed: () => _unavailable('Transfer Van'),
                child: const Text('Transfer van'),
              ),
              OutlinedButton(
                key: const Key('warehouse-audit'),
                style: adminOutlineButton(),
                onPressed: () => _showStock(ops),
                child: const Text('Stock rollup'),
              ),
              OutlinedButton(
                style: adminOutlineButton(),
                onPressed: () => _count(ops),
                child: const Text('Schedule audit'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminType(15, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: adminType(11.5, FontWeight.w600, AdminTokens.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: adminType(14, FontWeight.w700, AdminTokens.text)),
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: adminType(11, FontWeight.w700, fg)),
    );
  }

}

class _Kpi {
  const _Kpi(this.label, this.value, this.hint, this.icon);
  final String label;
  final String value;
  final String hint;
  final IconData icon;
}
