import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class CreatePriceListDialog extends StatefulWidget {
  const CreatePriceListDialog({super.key});

  @override
  State<CreatePriceListDialog> createState() => _CreatePriceListDialogState();
}

class _DraftLine {
  _DraftLine(this.product)
    : rate = TextEditingController(
        text: product.baseSystemPrice == null
            ? ''
            : product.baseSystemPrice!.toString(),
      ),
      included = product.priceStatus.toLowerCase() == 'active' &&
          (product.categoryKey == 'saleUnits' || product.categoryKey == 'packs');

  final ProductBasePriceRow product;
  final TextEditingController rate;
  bool included;

  void dispose() => rate.dispose();
}

class _CreatePriceListDialogState extends State<CreatePriceListDialog> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _description = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _filter = TextEditingController();
  var _default = false;
  var _active = true;
  var _scope = 'all';
  String? _routeId;
  String? _zoneId;
  var _loading = true;
  var _saving = false;
  String? _error;
  String? _loadError;
  String _group = 'all';
  List<_DraftLine> _lines = const [];
  List<RouteListItem> _routes = const [];
  List<ZoneListItem> _zones = const [];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _from.text =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    _from.dispose();
    _to.dispose();
    _filter.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final api = ApiScope.of(context);
    final products = <ProductBasePriceRow>[];
    String? error;
    try {
      var page = 1;
      var pages = 1;
      while (page <= pages && page <= 20) {
        final result = await api.productCatalogue(page: page, pageSize: 100);
        products.addAll(result.rows);
        pages = result.totalPages;
        if (result.rows.isEmpty) break;
        page += 1;
      }
    } on ApiException catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'The product catalogue could not be loaded.';
    }
    List<RouteListItem> routes = const [];
    List<ZoneListItem> zones = const [];
    try {
      routes = await api.listRoutes();
    } catch (_) {}
    try {
      zones = await api.listZones(activeOnly: true);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _lines = [for (final product in products) _DraftLine(product)];
      _routes = routes;
      _zones = zones;
      _loadError = error;
      _loading = false;
    });
  }

  Future<void> _pickDate(TextEditingController target) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(target.text.trim()) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    setState(() => target.text = '${picked.year}-$month-$day');
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final code = _code.text.trim();
    final from = _from.text.trim();
    final to = _to.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a list name.');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'Enter a list code.');
      return;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(from)) {
      setState(() => _error = 'Choose the date this list starts.');
      return;
    }
    if (to.isNotEmpty && !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(to)) {
      setState(() => _error = 'Use an end date as YYYY-MM-DD.');
      return;
    }
    if (to.isNotEmpty && to.compareTo(from) < 0) {
      setState(() => _error = 'The end date cannot be before the start date.');
      return;
    }
    if (_scope == 'route' && (_routeId == null || _routeId!.isEmpty)) {
      setState(() => _error = 'Choose a route for this list.');
      return;
    }
    if (_scope == 'zone' && (_zoneId == null || _zoneId!.isEmpty)) {
      setState(() => _error = 'Choose a zone for this list.');
      return;
    }
    final lines = <CreatePriceListLine>[];
    for (final line in _lines.where((item) => item.included)) {
      final rate = num.tryParse(line.rate.text.trim());
      if (rate == null || rate < 0) {
        setState(() => _error = 'Enter a list rate of zero or more for each included product.');
        return;
      }
      lines.add(CreatePriceListLine(productId: line.product.id, listRate: rate));
    }
    if (lines.isEmpty) {
      setState(() => _error = 'Include at least one product.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await ApiScope.of(context).createPriceList(
        CreatePriceListRequest(
          code: code,
          name: name,
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          isDefault: _default,
          isActive: _active,
          effectiveFrom: from,
          effectiveTo: to.isEmpty ? null : to,
          scope: _scope,
          routeId: _scope == 'route' ? _routeId : null,
          zoneId: _scope == 'zone' ? _zoneId : null,
          lines: lines,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'The price list could not be saved.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _filter.text.trim().toLowerCase();
    final visible = [
      for (final line in _lines)
        if (_group == 'all' || line.product.categoryKey == _group)
          if (query.isEmpty ||
              line.product.name.toLowerCase().contains(query) ||
              line.product.sku.toLowerCase().contains(query))
            line,
    ];
    final groups = <String>{
      for (final line in _lines)
        if (line.product.categoryKey.isNotEmpty) line.product.categoryKey,
    }.toList();
    return AlertDialog(
      title: Text(
        'Create price list',
        style: adminType(18, FontWeight.w700, AdminTokens.text, height: 1.2),
      ),
      content: SizedBox(
        width: 760,
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'The base system price stays on the product. This list stores its own rate for each included size.',
                      style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('pricing-list-name'),
                      controller: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('pricing-list-code'),
                      controller: _code,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _description,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _dateField(_from, 'Effective from', const Key('pricing-list-from'))),
                        const SizedBox(width: 8),
                        Expanded(child: _dateField(_to, 'Effective to', const Key('pricing-list-to'))),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _active,
                      onChanged: _saving ? null : (value) => setState(() => _active = value),
                      title: const Text('Active'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _default,
                      onChanged: _saving ? null : (value) => setState(() => _default = value),
                      title: const Text('Default fallback'),
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey('pricing-list-scope-$_scope'),
                      initialValue: _scope,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Applies to',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All customers')),
                        DropdownMenuItem(value: 'route', child: Text('One route')),
                        DropdownMenuItem(value: 'zone', child: Text('One zone')),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _scope = value ?? 'all'),
                    ),
                    if (_scope == 'route') ...[
                      const SizedBox(height: 8),
                      _choice(
                        label: 'Route',
                        value: _routeId,
                        items: _routes.map((item) => (item.id, item.name)).toList(),
                        onChanged: (value) => setState(() => _routeId = value),
                      ),
                    ],
                    if (_scope == 'zone') ...[
                      const SizedBox(height: 8),
                      _choice(
                        label: 'Zone',
                        value: _zoneId,
                        items: _zones.map((item) => (item.id, item.name)).toList(),
                        onChanged: (value) => setState(() => _zoneId = value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Products',
                      style: adminType(15, FontWeight.w700, AdminTokens.text),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _filter,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Filter product SKU or name',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chip('All groups', _group == 'all', () => setState(() => _group = 'all')),
                        for (final key in groups)
                          _chip(key, _group == key, () => setState(() => _group = key)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadError != null)
                      Text(
                        _loadError!,
                        style: adminType(13, FontWeight.w600, AdminTokens.error),
                      )
                    else if (visible.isEmpty)
                      Text(
                        'No products match this group.',
                        style: adminType(13, FontWeight.w600, AdminTokens.textSecondary),
                      )
                    else
                      for (final line in visible) _lineTile(line),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: adminType(13, FontWeight.w600, AdminTokens.error),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('pricing-list-save'),
          onPressed: _saving || _loading ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AdminTokens.button,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 40),
          ),
          child: Text(_saving ? 'Saving…' : 'Save list'),
        ),
      ],
    );
  }

  Widget _dateField(TextEditingController controller, String label, Key key) {
    return TextField(
      key: key,
      controller: controller,
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Choose a date',
          onPressed: _saving ? null : () => _pickDate(controller),
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
      ),
    );
  }

  Widget _choice({
    required String label,
    required String? value,
    required List<(String, String)> items,
    required ValueChanged<String?> onChanged,
  }) {
    if (items.isEmpty) {
      return Text(
        'No ${label.toLowerCase()} records were returned.',
        style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
      );
    }
    final known = items.any((item) => item.$1 == value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$known'),
      initialValue: known,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item.$1, child: Text(item.$2)),
      ],
      onChanged: _saving || items.isEmpty ? null : onChanged,
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AdminTokens.button : const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: adminType(12, FontWeight.w700, selected ? Colors.white : AdminTokens.text),
        ),
      ),
    );
  }

  Widget _lineTile(_DraftLine line) {
    final product = line.product;
    final base = product.baseSystemPrice;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            key: Key('pricing-include-${product.id}'),
            value: line.included,
            onChanged: _saving
                ? null
                : (value) => setState(() => line.included = value ?? false),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name.isEmpty ? product.sku : product.name,
                  style: adminType(13, FontWeight.w700, AdminTokens.text),
                ),
                Text(
                  [
                    if (product.sku.isNotEmpty) product.sku,
                    if (product.unitLabel.isNotEmpty) product.unitLabel,
                    if (base != null) formatPkr(base),
                  ].join(' · '),
                  style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              key: Key('pricing-rate-${product.id}'),
              controller: line.rate,
              enabled: !_saving && line.included,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(
                labelText: 'List rate',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
