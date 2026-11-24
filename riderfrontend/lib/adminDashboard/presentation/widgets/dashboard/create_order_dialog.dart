import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';

class CreateOrderDialog extends StatefulWidget {
  const CreateOrderDialog({super.key});

  @override
  State<CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _SizeLine {
  _SizeLine({
    required this.productId,
    required this.name,
    required this.sku,
    required this.size,
    required int quantity,
  }) : quantityText = TextEditingController(text: '$quantity');

  final String productId;
  final String name;
  final String sku;
  final String size;
  final TextEditingController quantityText;

  int get quantity => int.tryParse(quantityText.text.trim()) ?? 0;

  void dispose() => quantityText.dispose();
}

class _CreateOrderDialogState extends State<CreateOrderDialog> {
  final _customer = TextEditingController();
  final _rider = TextEditingController();
  final _product = TextEditingController();
  final _date = TextEditingController();
  final _note = TextEditingController();

  String? _customerId;
  String _customerLabel = '';
  AdminCustomerRow? _customerRow;
  String? _riderId;
  String _riderLabel = '';
  String? _window;
  String? _error;
  var _saving = false;
  var _showOnManifest = true;

  var _customerOpen = false;
  var _riderOpen = false;
  var _productOpen = false;
  var _customerLoading = false;
  var _riderLoading = false;
  var _productLoading = false;
  String? _customerHint;
  String? _riderHint;
  String? _productHint;
  List<AdminCustomerRow> _customers = const [];
  List<RiderRecord> _riders = const [];
  List<ProductBasePriceRow> _products = const [];
  final List<_SizeLine> _lines = [];

  Timer? _customerTimer;
  Timer? _riderTimer;
  Timer? _productTimer;
  var _suppressCustomer = false;
  var _suppressRider = false;

  @override
  void dispose() {
    _customerTimer?.cancel();
    _riderTimer?.cancel();
    _productTimer?.cancel();
    _customer.dispose();
    _rider.dispose();
    _product.dispose();
    _date.dispose();
    _note.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  String _resolvedCustomerId() {
    final text = _customer.text.trim();
    if (_customerId != null && text == _customerLabel) return _customerId!;
    return text;
  }

  String _resolvedRiderId() {
    final text = _rider.text.trim();
    if (_riderId != null && text == _riderLabel) return _riderId!;
    return text;
  }

  Future<void> _submit() async {
    final customerId = _resolvedCustomerId();
    final riderId = _resolvedRiderId();
    final lines = [
      for (final line in _lines)
        if (line.productId.trim().isNotEmpty)
          AdminOrderLine(productId: line.productId, quantity: line.quantity),
    ];
    final delivery = _date.text.trim();
    if (customerId.isEmpty) {
      setState(() => _error = 'Enter the customer id.');
      return;
    }
    if (riderId.isEmpty) {
      setState(() => _error = 'Enter the rider id.');
      return;
    }
    if (lines.isEmpty) {
      setState(() => _error = 'Enter the product id.');
      return;
    }
    if (lines.any((line) => line.quantity <= 0)) {
      setState(() => _error = 'Enter a quantity greater than zero.');
      return;
    }
    if (_window == null) {
      setState(() => _error = 'Choose a delivery window.');
      return;
    }
    if (delivery.isNotEmpty &&
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(delivery)) {
      setState(() => _error = 'Use a delivery date as YYYY-MM-DD.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final first = lines.first;
      final result = await ApiScope.of(context).createDashboardOrder(
        AdminOrderRequest(
          customerId: customerId,
          riderId: riderId,
          productId: first.productId,
          quantity: first.quantity,
          lines: lines,
          window: _window!,
          deliveryDate: delivery.isEmpty ? null : delivery,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          showOnManifest: _showOnManifest,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
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
        _error = 'Cannot reach the route server.';
      });
    }
  }

  void _scheduleCustomers(String query) {
    _customerTimer?.cancel();
    _customerTimer = Timer(
      const Duration(milliseconds: 250),
      () => _loadCustomers(query),
    );
  }

  Future<void> _loadCustomers(String query) async {
    if (!mounted) return;
    setState(() {
      _customerLoading = true;
      _customerOpen = true;
      _customerHint = null;
    });
    try {
      final page = await ApiScope.of(context).adminCustomers(
        search: query.trim().isEmpty ? null : query.trim(),
        pageSize: 8,
      );
      if (!mounted) return;
      final rows = page.rows.where((row) => row.id.isNotEmpty).toList();
      setState(() {
        _customers = rows;
        _customerLoading = false;
        _customerHint = rows.isEmpty ? 'No customers match that search.' : null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _customers = const [];
        _customerLoading = false;
        _customerHint = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _customers = const [];
        _customerLoading = false;
        _customerHint = 'Customer list could not be loaded.';
      });
    }
  }

  void _selectCustomer(AdminCustomerRow row) {
    final label = _customerLabelFor(row);
    _suppressCustomer = true;
    _customer.text = label;
    _customer.selection = TextSelection.collapsed(offset: label.length);
    _suppressCustomer = false;
    setState(() {
      _customerId = row.id;
      _customerLabel = label;
      _customerRow = row;
      _customerOpen = false;
      _customers = const [];
      _riderId = null;
      _riderLabel = '';
      _rider.clear();
      _riders = const [];
      _riderHint = null;
    });
    _loadRiders('');
  }

  void _scheduleRiders(String query) {
    _riderTimer?.cancel();
    _riderTimer = Timer(
      const Duration(milliseconds: 250),
      () => _loadRiders(query),
    );
  }

  Future<void> _loadRiders(String query) async {
    if (!mounted) return;
    setState(() {
      _riderLoading = true;
      _riderOpen = true;
      _riderHint = null;
    });
    try {
      final date = _date.text.trim();
      final roster = await ApiScope.of(context).riderOperationsRiders(
        date: RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)
            ? date
            : _todayIso(),
        search: query.trim().isEmpty ? null : query.trim(),
      );
      if (!mounted) return;
      final areaRiders = roster.where(_riderServesCustomer).toList();
      setState(() {
        _riders = areaRiders;
        _riderLoading = false;
        _riderHint = _riderEmptyHint(areaRiders, roster);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _riders = const [];
        _riderLoading = false;
        _riderHint = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _riders = const [];
        _riderLoading = false;
        _riderHint = 'Rider list could not be loaded.';
      });
    }
  }

  String? _riderEmptyHint(List<RiderRecord> matched, List<RiderRecord> roster) {
    if (matched.isNotEmpty) return null;
    final place = _customerPlace();
    if (_customerRow != null && place.isNotEmpty && roster.isNotEmpty) {
      return 'No riders are allocated to $place. Type a rider id to assign one manually.';
    }
    if (_customerRow == null) {
      return 'Select a customer to list riders for that area. You can still type a rider id.';
    }
    return 'No riders match that search. You can still type a rider id.';
  }

  bool _riderServesCustomer(RiderRecord rider) {
    final customer = _customerRow;
    if (customer == null) return true;
    final route = customer.routeName.trim().toLowerCase();
    final area = customer.area.trim().toLowerCase();
    final zone = (customer.zoneName ?? '').trim().toLowerCase();
    final riderRoute = rider.routeName.trim().toLowerCase();
    if (route.isEmpty && area.isEmpty && zone.isEmpty) return true;
    if (riderRoute.isEmpty) return false;
    if (route.isNotEmpty &&
        (riderRoute == route ||
            riderRoute.contains(route) ||
            route.contains(riderRoute))) {
      return true;
    }
    if (area.isNotEmpty && riderRoute.contains(area)) return true;
    if (zone.isNotEmpty && riderRoute.contains(zone)) return true;
    return false;
  }

  void _selectRider(RiderRecord rider) {
    final label = _riderLabelFor(rider);
    _suppressRider = true;
    _rider.text = label;
    _rider.selection = TextSelection.collapsed(offset: label.length);
    _suppressRider = false;
    setState(() {
      _riderId = rider.id;
      _riderLabel = label;
      _riderOpen = false;
      _riders = const [];
      _riderHint = null;
    });
  }

  void _scheduleProducts(String query) {
    _productTimer?.cancel();
    _productTimer = Timer(
      const Duration(milliseconds: 250),
      () => _loadProducts(query),
    );
  }

  Future<void> _loadProducts(String query) async {
    if (!mounted) return;
    setState(() {
      _productLoading = true;
      _productOpen = true;
      _productHint = null;
    });
    try {
      final page = await ApiScope.of(context).productCatalogue(
        search: query.trim().isEmpty ? null : query.trim(),
        pageSize: 8,
      );
      if (!mounted) return;
      final rows = page.rows.where((row) => row.id.isNotEmpty).toList();
      setState(() {
        _products = rows;
        _productLoading = false;
        _productHint = rows.isEmpty ? 'No products match that search.' : null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _products = const [];
        _productLoading = false;
        _productHint = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _products = const [];
        _productLoading = false;
        _productHint = 'Product list could not be loaded.';
      });
    }
  }

  void _addProduct(ProductBasePriceRow row) {
    if (_lines.any((line) => line.productId == row.id)) {
      setState(() {
        _product.clear();
        _productOpen = false;
        _products = const [];
      });
      return;
    }
    setState(() {
      _lines.add(
        _SizeLine(
          productId: row.id,
          name: row.name.trim().isEmpty ? row.sku : row.name.trim(),
          sku: row.sku,
          size: row.unitLabel,
          quantity: 1,
        ),
      );
      _product.clear();
      _productOpen = false;
      _products = const [];
      _productHint = null;
    });
  }

  void _addTypedProduct() {
    final id = _product.text.trim();
    if (id.isEmpty || _lines.any((line) => line.productId == id)) return;
    setState(() {
      _lines.add(
        _SizeLine(productId: id, name: id, sku: '', size: '', quantity: 1),
      );
      _product.clear();
      _productOpen = false;
      _products = const [];
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_date.text.trim()) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !mounted) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    setState(() => _date.text = '${picked.year}-$month-$day');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Create order',
        style: adminType(18, FontWeight.w700, AdminTokens.text, height: 1.2),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _lookupField(
                controller: _customer,
                fieldKey: const Key('order-customer-id'),
                label: 'Customer',
                hint: 'Search name or customer id',
                open: _customerOpen,
                loading: _customerLoading,
                message: _customerHint,
                onTap: () => _scheduleCustomers(_customer.text),
                onChanged: (value) {
                  if (_suppressCustomer) return;
                  setState(() {
                    if (_customerId != null && value != _customerLabel) {
                      _customerId = null;
                      _customerLabel = '';
                      _customerRow = null;
                    }
                  });
                  _scheduleCustomers(value);
                },
                options: [
                  for (final row in _customers) _customerOption(row),
                ],
              ),
              if (_customerRow != null) _customerCaption(_customerRow!),
              const SizedBox(height: 8),
              _lookupField(
                controller: _rider,
                fieldKey: const Key('order-rider-id'),
                label: 'Rider',
                hint: _customerRow == null
                    ? 'Select a customer, or type a rider id'
                    : 'Riders for ${_customerPlace()}',
                open: _riderOpen,
                loading: _riderLoading,
                message: _riderHint,
                onTap: () => _scheduleRiders(_rider.text),
                onChanged: (value) {
                  if (_suppressRider) return;
                  setState(() {
                    if (_riderId != null && value != _riderLabel) {
                      _riderId = null;
                      _riderLabel = '';
                    }
                  });
                  _scheduleRiders(value);
                },
                options: [for (final rider in _riders) _riderOption(rider)],
              ),
              const SizedBox(height: 8),
              _lookupField(
                controller: _product,
                fieldKey: const Key('order-product-id'),
                label: 'Product',
                hint: 'Search product, size, or product id',
                open: _productOpen,
                loading: _productLoading,
                message: _productHint,
                onTap: () => _scheduleProducts(_product.text),
                onChanged: _scheduleProducts,
                onSubmitted: (_) => _addTypedProduct(),
                options: [
                  for (final row in _products) _productOption(row),
                  if (_product.text.trim().isNotEmpty)
                    _manualProductOption(_product.text.trim()),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Sizes and quantities',
                style: adminType(13, FontWeight.w700, AdminTokens.text),
              ),
              const SizedBox(height: 2),
              Text(
                'Each bottle size is its own line. Set how many of that size to deliver.',
                style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
              ),
              const SizedBox(height: 8),
              if (_lines.isEmpty)
                Text(
                  'Choose a product to add its size.',
                  key: const Key('order-quantity'),
                  style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
                )
              else
                for (var i = 0; i < _lines.length; i++)
                  _SizeCard(
                    line: _lines[i],
                    quantityKey: i == 0 ? const Key('order-quantity') : null,
                    enabled: !_saving,
                    onChanged: () => setState(() {}),
                    onRemove: () {
                      final line = _lines.removeAt(i);
                      line.dispose();
                      setState(() {});
                    },
                  ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('order-window'),
                initialValue: _window,
                decoration: const InputDecoration(
                  labelText: 'Delivery window',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                  DropdownMenuItem(
                    value: 'Afternoon',
                    child: Text('Afternoon'),
                  ),
                  DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _window = value),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('order-date'),
                controller: _date,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: 'Delivery date',
                  hintText: 'YYYY-MM-DD',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    key: const Key('order-date-picker'),
                    tooltip: 'Choose a delivery date',
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('order-note'),
                controller: _note,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _showOnManifest,
                onChanged: _saving
                    ? null
                    : (value) =>
                          setState(() => _showOnManifest = value ?? true),
                title: Text(
                  'Show on manifest',
                  style: adminType(13, FontWeight.w600, AdminTokens.text),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: adminType(
                    13,
                    FontWeight.w600,
                    AdminTokens.error,
                    height: 1.35,
                  ),
                ),
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
          key: const Key('create-order-submit'),
          onPressed: _saving ? null : _submit,
          style: adminPrimaryButton(),
          child: Text(_saving ? 'Saving…' : 'Save order'),
        ),
      ],
    );
  }

  Widget _lookupField({
    required TextEditingController controller,
    required Key fieldKey,
    required String label,
    required String hint,
    required bool open,
    required bool loading,
    required String? message,
    required VoidCallback onTap,
    required ValueChanged<String> onChanged,
    required List<Widget> options,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: fieldKey,
          controller: controller,
          enabled: !_saving,
          onTap: onTap,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.arrow_drop_down),
          ),
        ),
        if (open && (options.isNotEmpty || message != null))
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminTokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...options,
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      message,
                      style: adminType(
                        12.5,
                        FontWeight.w600,
                        AdminTokens.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _customerOption(AdminCustomerRow row) {
    final idLabel = row.code.trim().isEmpty ? row.id : row.code.trim();
    final place = [
      row.area.trim(),
      row.routeName.trim(),
    ].where((part) => part.isNotEmpty).join(' · ');
    return InkWell(
      onTap: () => _selectCustomer(row),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row.businessName.trim().isEmpty ? idLabel : row.businessName.trim(),
              style: adminType(13.5, FontWeight.w700, AdminTokens.text),
            ),
            Text(
              'Customer ID: $idLabel',
              style: adminType(12, FontWeight.w600, AdminTokens.button),
            ),
            if (place.isNotEmpty)
              Text(
                place,
                style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customerCaption(AdminCustomerRow row) {
    final place = _customerPlace();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        place.isEmpty
            ? 'Customer ID ${row.code.trim().isEmpty ? row.id : row.code.trim()} is sent with the order.'
            : 'Area $place. The order is saved with customer id ${row.id}.',
        style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
      ),
    );
  }

  Widget _riderOption(RiderRecord rider) {
    final code = rider.riderCode.trim().isEmpty ? rider.id : rider.riderCode.trim();
    return InkWell(
      onTap: () => _selectRider(rider),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rider.fullName.trim().isEmpty ? code : rider.fullName.trim(),
              style: adminType(13.5, FontWeight.w700, AdminTokens.text),
            ),
            Text(
              'Rider ID: $code',
              style: adminType(12, FontWeight.w600, AdminTokens.button),
            ),
            if (rider.routeName.trim().isNotEmpty)
              Text(
                rider.routeName.trim(),
                style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _productOption(ProductBasePriceRow row) {
    final size = row.unitLabel.trim();
    final price = row.effectiveBasePrice;
    return InkWell(
      onTap: () => _addProduct(row),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (size.isNotEmpty) _SizeChip(label: size),
            if (size.isNotEmpty) const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name.trim().isEmpty ? row.sku : row.name.trim(),
                    style: adminType(13.5, FontWeight.w700, AdminTokens.text),
                  ),
                  Text(
                    [
                      if (row.sku.trim().isNotEmpty) 'SKU ${row.sku.trim()}',
                      'Product ID: ${row.id}',
                      if (price != null) formatPkr(price),
                    ].join(' · '),
                    style: adminType(
                      12,
                      FontWeight.w500,
                      AdminTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _manualProductOption(String id) {
    return InkWell(
      onTap: _addTypedProduct,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          'Add product id $id',
          style: adminType(13, FontWeight.w700, AdminTokens.button),
        ),
      ),
    );
  }

  String _customerPlace() {
    final row = _customerRow;
    if (row == null) return 'this area';
    final parts = [
      row.area.trim(),
      row.routeName.trim(),
    ].where((part) => part.isNotEmpty);
    return parts.isEmpty ? 'this area' : parts.join(' · ');
  }
}

class _SizeCard extends StatelessWidget {
  const _SizeCard({
    required this.line,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
    this.quantityKey,
  });

  final _SizeLine line;
  final Key? quantityKey;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final size = line.size.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (size.isNotEmpty) _SizeChip(label: size),
              if (size.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.name,
                      style: adminType(13.5, FontWeight.w700, AdminTokens.text),
                    ),
                    Text(
                      [
                        if (line.sku.trim().isNotEmpty) 'SKU ${line.sku.trim()}',
                        size.isEmpty ? 'Size not listed' : 'Size $size',
                      ].join(' · '),
                      style: adminType(
                        12,
                        FontWeight.w500,
                        AdminTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove size',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Quantity',
                style: adminType(12, FontWeight.w700, AdminTokens.textSecondary),
              ),
              const Spacer(),
              _step(
                icon: Icons.remove,
                onPressed: !enabled || line.quantity <= 1
                    ? null
                    : () {
                        line.quantityText.text = '${line.quantity - 1}';
                        onChanged();
                      },
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  key: quantityKey,
                  controller: line.quantityText,
                  enabled: enabled,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              _step(
                icon: Icons.add,
                onPressed: !enabled
                    ? null
                    : () {
                        line.quantityText.text = '${line.quantity + 1}';
                        onChanged();
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step({required IconData icon, required VoidCallback? onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminTokens.button,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: adminType(11, FontWeight.w700, Colors.white),
      ),
    );
  }
}

String _customerLabelFor(AdminCustomerRow row) {
  final name = row.businessName.trim();
  final id = row.code.trim().isEmpty ? row.id : row.code.trim();
  if (name.isEmpty) return id;
  return '$name · $id';
}

String _riderLabelFor(RiderRecord rider) {
  final name = rider.fullName.trim();
  final id = rider.riderCode.trim().isEmpty ? rider.id : rider.riderCode.trim();
  if (name.isEmpty) return id;
  return '$name · $id';
}

String _todayIso() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
