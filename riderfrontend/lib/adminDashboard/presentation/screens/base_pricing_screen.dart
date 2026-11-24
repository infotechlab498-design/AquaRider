import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:riderfrontend/adminDashboard/data/admin_format.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/pricing/create_price_list_dialog.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

const _readOnlyPricing =
    'The pricing matrix is read-only. Additional price lists, edits, and customer assignments are not stored.';

class BasePricingScreen extends StatefulWidget {
  const BasePricingScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<BasePricingScreen> createState() => _BasePricingScreenState();
}

class _BasePricingScreenState extends State<BasePricingScreen> {
  final _search = TextEditingController();
  final _customer = TextEditingController();
  final _qty = TextEditingController(text: '1');
  Timer? _debounce;
  Timer? _customerTimer;
  var _started = false;
  var _loading = true;
  var _exporting = false;
  var _page = 1;
  var _category = 'all';
  var _status = 'all';
  String? _selectedProductId;
  String? _customerId;
  String _customerLabel = '';
  var _customerOpen = false;
  var _customerLoading = false;
  String? _customerHint;
  List<AdminCustomerRow> _customerHits = const [];
  AdminLoad<CustomerBasePriceLookup>? _lookup;

  AdminLoad<PricingCoverage>? _coverage;
  AdminLoad<List<ProductCategoryGroup>>? _categories;
  AdminLoad<ProductCataloguePage>? _catalogue;
  AdminLoad<BasePriceValidation>? _validation;
  AdminLoad<List<PriceListSummary>>? _priceLists;
  AdminLoad<PriceListDetail>? _openDetail;
  String? _openListId;

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
    _debounce?.cancel();
    _customerTimer?.cancel();
    _search.dispose();
    _customer.dispose();
    _qty.dispose();
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
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final coverage = await guardAdminLoad(api.pricingCoverage);
    final categories = await guardAdminLoad(api.productCategories);
    final catalogue = await guardAdminLoad(
      () => api.productCatalogue(
        categoryKey: _category == 'all' ? null : _category,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
        status: _status == 'all' ? null : _status,
        page: _page,
        pageSize: 6,
      ),
    );
    final lists = await guardAdminLoad(api.priceLists);
    if (!mounted) return;
    final rows = catalogue.value?.rows ?? const <ProductBasePriceRow>[];
    final known = categories.value ?? const <ProductCategoryGroup>[];
    var category = _category;
    if (category != 'all' && known.every((item) => item.key != category)) {
      category = 'all';
    }
    final selected = _openListId != null
        ? _selectedProductId
        : (rows.any((row) => row.id == _selectedProductId)
              ? _selectedProductId
              : (rows.isEmpty ? null : rows.first.id));
    setState(() {
      _coverage = coverage;
      _categories = categories;
      _catalogue = catalogue;
      _priceLists = lists;
      _category = category;
      _selectedProductId = selected;
      _loading = false;
    });
    final openId = _openListId;
    if (openId != null) {
      final detail = await guardAdminLoad(() => api.priceList(openId));
      if (!mounted || _openListId != openId) return;
      final lines = detail.value?.lines ?? const <PriceListLine>[];
      setState(() {
        _openDetail = detail;
        if (lines.isNotEmpty && lines.every((line) => line.productId != _selectedProductId)) {
          _selectedProductId = lines.first.productId;
        }
      });
    }
    final productId = _selectedProductId;
    if (productId != null) await _validate(productId);
  }

  Future<void> _validate(String productId) async {
    final qty = int.tryParse(_qty.text.trim());
    final validation = await guardAdminLoad(
      () => ApiScope.of(context).basePriceValidate(
        productId: productId,
        quantity: qty == null || qty < 1 ? 1 : qty,
      ),
    );
    if (!mounted) return;
    setState(() => _validation = validation);
  }

  Future<void> _loadCustomers(String query) async {
    setState(() {
      _customerLoading = true;
      _customerOpen = true;
      _customerHint = null;
    });
    try {
      final page = await ApiScope.of(context).adminCustomers(
        search: query.trim().isEmpty ? null : query.trim(),
        pageSize: 6,
      );
      if (!mounted) return;
      setState(() {
        _customerHits = page.rows.where((row) => row.id.isNotEmpty).toList();
        _customerLoading = false;
        _customerHint = _customerHits.isEmpty
            ? 'No customers match that search.'
            : null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _customerHits = const [];
        _customerLoading = false;
        _customerHint = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _customerHits = const [];
        _customerLoading = false;
        _customerHint = 'Customer list could not be loaded.';
      });
    }
  }

  Future<void> _selectCustomer(AdminCustomerRow row) async {
    final label = row.businessName.trim().isEmpty
        ? row.code
        : '${row.businessName.trim()} (${row.code.trim().isEmpty ? row.id : row.code.trim()})';
    setState(() {
      _customerId = row.id;
      _customerLabel = label;
      _customer.text = label;
      _customerOpen = false;
      _customerHits = const [];
      _lookup = null;
    });
    final lookup = await guardAdminLoad(
      () => ApiScope.of(context).customerBasePriceLookup(row.id),
    );
    if (!mounted) return;
    setState(() => _lookup = lookup);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final api = ApiScope.of(context);
      final rows = <ProductBasePriceRow>[];
      var page = 1;
      var pages = 1;
      while (page <= pages && page <= 20) {
        final result = await api.productCatalogue(
          categoryKey: _category == 'all' ? null : _category,
          search: _search.text.trim().isEmpty ? null : _search.text.trim(),
          status: _status == 'all' ? null : _status,
          page: page,
          pageSize: 100,
        );
        rows.addAll(result.rows);
        pages = result.totalPages;
        if (result.rows.isEmpty) break;
        page += 1;
      }
      final csv = StringBuffer(
        'name,sku,unit,base_system,list_rate,difference,status,category\n',
      );
      for (final row in rows) {
        final base = row.baseSystemPrice;
        final list = row.effectiveBasePrice;
        final difference = base == null || list == null ? '' : '${list - base}';
        csv.write(
          '${_csv(row.name)},${_csv(row.sku)},${_csv(row.unitLabel)},${base ?? ''},${list ?? ''},$difference,${_csv(row.priceStatus)},${_csv(row.categoryKey)}\n',
        );
      }
      await Clipboard.setData(ClipboardData(text: csv.toString()));
      if (!mounted) return;
      showAdminNotice(
        context,
        rows.isEmpty
            ? 'No priced rows were returned to export.'
            : 'Copied ${rows.length} catalogue rows. Paste them into a spreadsheet.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showAdminNotice(context, 'The price matrix could not be exported.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _audit() async {
    final id = _selectedProductId;
    final rows = _catalogue?.value?.rows ?? const <ProductBasePriceRow>[];
    final product = _findRow(rows, id);
    if (id == null || product == null) {
      showAdminNotice(context, 'Select a catalogue row before auditing prices.');
      return;
    }
    String message;
    try {
      message = await ApiScope.of(context).productPriceHistory(id);
    } on ApiException catch (error) {
      message = error.message;
    } catch (_) {
      message = 'Price history could not be loaded.';
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audit price changes'),
        content: SizedBox(
          width: 420,
          child: Text(
            '${product.name.isEmpty ? product.sku : product.name}\n\n$message',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _readOnlyNotice() => showAdminNotice(context, _readOnlyPricing);

  Future<void> _editOpenList() async {
    final id = _openListId;
    final detail = _openDetail?.value;
    if (id == null || detail == null) {
      _readOnlyNotice();
      return;
    }
    final name = TextEditingController(text: detail.name);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit price list'),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    final nextName = name.text.trim();
    name.dispose();
    if (saved != true || !mounted) return;
    try {
      await ApiScope.of(context).updatePriceList(id, {
        'code': detail.code,
        'name': nextName,
        'description': detail.description,
        'isDefault': detail.isDefault,
        'isActive': detail.isActive,
        'effectiveFrom': detail.effectiveFrom,
        'effectiveTo': detail.effectiveTo.isEmpty ? null : detail.effectiveTo,
        'scope': detail.scope,
        'routeId': detail.routeId.isEmpty ? null : detail.routeId,
        'zoneId': detail.zoneId.isEmpty ? null : detail.zoneId,
        'lines': [
          for (final line in detail.lines)
            if (line.listRate != null) {'productId': line.productId, 'listRate': line.listRate, 'included': true},
        ],
      });
      if (!mounted) return;
      await _openSavedList(id);
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    }
  }

  Future<void> _duplicateOpenList() async {
    final id = _openListId;
    if (id == null || _openDetail?.value == null) {
      _readOnlyNotice();
      return;
    }
    final code = TextEditingController();
    final name = TextEditingController(text: '${_openDetail!.value!.name} copy');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate price list'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: code, decoration: const InputDecoration(labelText: 'New code')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'New name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Duplicate')),
        ],
      ),
    );
    final nextCode = code.text.trim();
    final nextName = name.text.trim();
    code.dispose();
    name.dispose();
    if (saved != true || !mounted) return;
    try {
      await ApiScope.of(context).duplicatePriceList(id, code: nextCode, name: nextName);
      if (!mounted) return;
      await _reload();
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    }
  }

  Future<void> _assignOpenList() async {
    final id = _openListId;
    if (id == null || _openDetail?.value == null) {
      _readOnlyNotice();
      return;
    }
    final page = await guardAdminLoad(() => ApiScope.of(context).adminCustomers(status: 'Active', pageSize: 50));
    if (!mounted) return;
    final rows = page.value?.rows ?? const <AdminCustomerRow>[];
    if (rows.isEmpty) {
      showAdminNotice(context, page.error ?? 'No route customers were returned.');
      return;
    }
    final selected = <String>{};
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Assign customers'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final row in rows)
                  CheckboxListTile(
                    value: selected.contains(row.id),
                    title: Text('${row.code} · ${row.businessName}'),
                    onChanged: (value) => setLocal(() {
                      if (value == true) {
                        selected.add(row.id);
                      } else {
                        selected.remove(row.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Assign')),
          ],
        ),
      ),
    );
    if (saved != true || !mounted || selected.isEmpty) return;
    try {
      await ApiScope.of(context).assignPriceList(id, selected.toList());
      if (!mounted) return;
      showAdminNotice(context, 'Customers now use this list rate on rider sales.');
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminNotice(context, error.message);
    }
  }

  void _chooseCategory(String key) {
    setState(() {
      _category = key;
      _page = 1;
      _openListId = null;
      _openDetail = null;
    });
    _reload();
  }

  Future<void> _openSavedList(String id) async {
    setState(() {
      _openListId = id;
      _openDetail = null;
    });
    final detail = await guardAdminLoad(() => ApiScope.of(context).priceList(id));
    if (!mounted || _openListId != id) return;
    final lines = detail.value?.lines ?? const <PriceListLine>[];
    setState(() {
      _openDetail = detail;
      _selectedProductId = lines.isEmpty ? null : lines.first.productId;
    });
    final productId = _selectedProductId;
    if (productId != null) await _validate(productId);
  }

  List<ProductBasePriceRow> _rowsFromList(PriceListDetail? detail) {
    if (detail == null) return const [];
    final query = _search.text.trim().toLowerCase();
    return [
      for (final line in detail.lines)
        if (query.isEmpty ||
            line.name.toLowerCase().contains(query) ||
            line.sku.toLowerCase().contains(query))
          if (_status == 'all' || line.priceStatus.toLowerCase() == _status)
            ProductBasePriceRow(
              id: line.productId,
              name: line.name,
              sku: line.sku,
              unitLabel: line.unitLabel,
              baseSystemPrice: line.baseSystemPrice,
              effectiveBasePrice: line.listRate,
              priceStatus: line.priceStatus,
              categoryKey: line.categoryKey,
            ),
    ];
  }

  Future<void> _createList() async {
    final created = await showDialog<PriceListDetail>(
      context: context,
      builder: (context) => const CreatePriceListDialog(),
    );
    if (!mounted || created == null) return;
    showAdminNotice(context, 'Price list ${created.code} was saved.');
    setState(() => _openListId = created.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final loads = <AdminLoad<dynamic>>[?_coverage, ?_categories, ?_catalogue];
    final categories = _categories?.value ?? const <ProductCategoryGroup>[];
    final page = _catalogue?.value;
    final catalogueRows = page?.rows ?? const <ProductBasePriceRow>[];
    final viewingList = _openListId != null;
    final openList = viewingList ? _openDetail?.value : null;
    final rows = viewingList ? _rowsFromList(openList) : catalogueRows;
    final matrixPage = openList == null
        ? page
        : ProductCataloguePage(
            rows: rows,
            page: 1,
            pageSize: rows.isEmpty ? 1 : rows.length,
            totalRecords: rows.length,
            totalPages: rows.isEmpty ? 0 : 1,
          );
    final selected = _findRow(rows, _selectedProductId);
    return AdminShell(
      screenKey: const Key('base-pricing-screen'),
      session: widget.session,
      activeKey: AdminNav.basePricing,
      serverReachable: adminServerReachable(loads),
      search: _search,
      onSearch: (_) {},
      searchHint: 'Search product name or SKU',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && _coverage == null
          ? const AdminLoadingPane(label: 'Loading base pricing…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                _Header(
                  exporting: _exporting,
                  onExport: _export,
                  onAudit: _audit,
                  onCreate: _createList,
                ),
                const SizedBox(height: 12),
                const _LedgerBanner(),
                const SizedBox(height: 12),
                _KpiRow(
                  coverage: _coverage?.value,
                  error: _coverage?.failed == true ? _coverage!.error : null,
                  categories: categories,
                  onResolve: () {
                    setState(() {
                      _status = 'unpriced';
                      _page = 1;
                    });
                    _reload();
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final tiers = _TierColumn(
                      categories: categories,
                      priceLists: _priceLists?.value ?? const <PriceListSummary>[],
                      listError: _priceLists?.failed == true ? _priceLists!.error : null,
                      error: _categories?.failed == true
                          ? _categories!.error
                          : null,
                      selectedKey: _openListId == null ? _category : '',
                      selectedListId: _openListId,
                      coverage: _coverage?.value,
                      onSelect: _chooseCategory,
                      onSelectList: _openSavedList,
                    );
                    final matrix = _Matrix(
                      categories: categories,
                      selectedKey: _category,
                      listTitle: openList == null
                          ? null
                          : '${openList.name} (${openList.code})',
                      status: _status,
                      page: matrixPage,
                      rows: rows,
                      selectedId: _selectedProductId,
                      failed: viewingList
                          ? _openDetail?.failed == true
                          : _catalogue?.failed == true,
                      error: viewingList ? _openDetail?.error : _catalogue?.error,
                      emptyText: !viewingList
                          ? 'No approved base-priced products found.'
                          : _openDetail == null
                          ? 'Loading price list…'
                          : 'No products were saved on this list.',
                      search: _search,
                      onCategory: _chooseCategory,
                      onStatus: (value) {
                        setState(() {
                          _status = value;
                          _page = 1;
                        });
                        _reload();
                      },
                      onSelect: (id) {
                        setState(() => _selectedProductId = id);
                        _validate(id);
                      },
                      onEdit: () => _editOpenList(),
                      onDuplicate: () => _duplicateOpenList(),
                      onAssign: () => _assignOpenList(),
                      onPage: (next) {
                        setState(() => _page = next);
                        _reload();
                      },
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          tiers,
                          const SizedBox(height: 12),
                          matrix,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 320, child: tiers),
                        const SizedBox(width: 16),
                        Expanded(child: matrix),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _Simulator(
                  customer: _customer,
                  qty: _qty,
                  rows: rows,
                  selected: selected,
                  validation: _validation,
                  lookup: _lookup,
                  customerOpen: _customerOpen,
                  customerLoading: _customerLoading,
                  customerHint: _customerHint,
                  customerHits: _customerHits,
                  onCustomer: (value) {
                    if (_customerId != null && value != _customerLabel) {
                      _customerId = null;
                      _lookup = null;
                    }
                    _customerTimer?.cancel();
                    _customerTimer = Timer(
                      const Duration(milliseconds: 250),
                      () => _loadCustomers(value),
                    );
                  },
                  onPickCustomer: _selectCustomer,
                  onProduct: (id) {
                    setState(() => _selectedProductId = id);
                    _validate(id);
                  },
                  onQuantity: () {
                    final id = _selectedProductId;
                    if (id != null) _validate(id);
                  },
                ),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.exporting,
    required this.onExport,
    required this.onAudit,
    required this.onCreate,
  });

  final bool exporting;
  final VoidCallback onExport;
  final VoidCallback onAudit;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Management  ›  Price Lists & Rules',
                style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Price Lists & Customer Pricing',
                style: adminType(28, FontWeight.w700, AdminTokens.text, height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                'Review the approved base price, catalogue groups, and the rate a customer would be charged.',
                style: adminType(14, FontWeight.w500, AdminTokens.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('pricing-export'),
              onPressed: exporting ? null : onExport,
              style: adminOutlineButton(),
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: Text(exporting ? 'Exporting…' : 'Export Price Matrix'),
            ),
            OutlinedButton.icon(
              key: const Key('pricing-audit'),
              onPressed: onAudit,
              style: adminOutlineButton(),
              icon: const Icon(Icons.fact_check_outlined, size: 16),
              label: const Text('Audit Price Changes'),
            ),
            FilledButton.icon(
              key: const Key('pricing-create'),
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AdminTokens.button,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create Price List'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LedgerBanner extends StatelessWidget {
  const _LedgerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E6F5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: AdminTokens.button, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Immutable Ledger Synchronization',
                  style: adminType(14, FontWeight.w700, AdminTokens.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'Approved base prices apply to newly created eligible orders. Existing historical transactions, posted sales, and receipts remain unchanged.',
                  style: adminType(
                    12.5,
                    FontWeight.w500,
                    AdminTokens.textSecondary,
                    height: 1.35,
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

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.coverage,
    required this.categories,
    required this.onResolve,
    this.error,
  });

  final PricingCoverage? coverage;
  final List<ProductCategoryGroup> categories;
  final VoidCallback onResolve;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final names = categories.map((item) => item.label).where((item) => item.isNotEmpty);
    final percent = coverage?.coveragePercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              error!,
              style: adminType(13, FontWeight.w600, AdminTokens.error),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 720
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _KpiCard(
                  width: width,
                  label: 'CATALOGUE GROUPS',
                  value: coverage?.categoryCount?.toString() ?? '—',
                  detail: names.isEmpty ? 'Groups were not returned.' : names.join(', '),
                  icon: Icons.layers_outlined,
                ),
                _KpiCard(
                  width: width,
                  label: 'PRICED ITEMS',
                  value: coverage?.pricedProducts?.toString() ?? '—',
                  detail: coverage?.activeProducts == null
                      ? 'Active catalogue size was not returned.'
                      : '${coverage!.pricedProducts ?? 0} of ${coverage!.activeProducts} active items',
                  icon: Icons.inventory_2_outlined,
                  progress: percent == null ? null : (percent / 100).clamp(0, 1).toDouble(),
                  progressLabel: percent == null ? null : '${_trimNumber(percent)}% catalog coverage',
                ),
                _KpiCard(
                  width: width,
                  label: 'CUSTOMER ACCOUNTS',
                  value: coverage?.customerAccounts?.toString() ?? '—',
                  detail: 'Approved base pricing',
                  icon: Icons.storefront_outlined,
                ),
                _KpiCard(
                  width: width,
                  label: 'UNPRICED',
                  value: coverage?.unpricedProducts?.toString() ?? '—',
                  detail: 'Base price missing',
                  icon: Icons.error_outline,
                  iconColor: AdminTokens.error,
                  action: 'Resolve',
                  onAction: onResolve,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.iconColor = AdminTokens.button,
    this.progress,
    this.progressLabel,
    this.action,
    this.onAction,
  });

  final double width;
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color iconColor;
  final double? progress;
  final String? progressLabel;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: adminType(11, FontWeight.w700, AdminTokens.textSecondary, letterSpacing: 0.4),
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: adminType(28, FontWeight.w700, AdminTokens.text, height: 1)),
          const SizedBox(height: 4),
          Text(
            detail,
            style: adminType(12, FontWeight.w500, AdminTokens.textSecondary, height: 1.3),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: const Color(0xFFE6EEF6),
                color: AdminTokens.button,
              ),
            ),
            if (progressLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  progressLabel!,
                  style: adminType(11.5, FontWeight.w600, AdminTokens.textSecondary),
                ),
              ),
          ],
          if (action != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('pricing-resolve'),
                onPressed: onAction,
                child: Text(action!),
              ),
            ),
        ],
      ),
    );
  }
}

class _TierColumn extends StatelessWidget {
  const _TierColumn({
    required this.categories,
    required this.priceLists,
    required this.selectedKey,
    required this.coverage,
    required this.onSelect,
    required this.onSelectList,
    this.selectedListId,
    this.error,
    this.listError,
  });

  final List<ProductCategoryGroup> categories;
  final List<PriceListSummary> priceLists;
  final String selectedKey;
  final String? selectedListId;
  final PricingCoverage? coverage;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onSelectList;
  final String? error;
  final String? listError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Price tiers & rules',
              style: adminType(16, FontWeight.w700, AdminTokens.text),
            ),
            const Spacer(),
            Text(
              '${categories.length + 1 + priceLists.length}',
              style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (error != null)
          Text(error!, style: adminType(13, FontWeight.w600, AdminTokens.error)),
        _TierCard(
          selected: selectedKey == 'all',
          badge: 'BASE',
          title: 'Approved base price',
          body: 'Default fallback for new orders. The list rate is the approved unit price.',
          stats: [
            _Stat(
              'Priced items',
              coverage?.pricedProducts?.toString() ?? '—',
            ),
            _Stat('Customers', coverage?.customerAccounts?.toString() ?? '—'),
          ],
          footer: 'View matrix',
          active: true,
          onTap: () => onSelect('all'),
        ),
        if (listError != null)
          Text(listError!, style: adminType(13, FontWeight.w600, AdminTokens.error)),
        for (final list in priceLists)
          _TierCard(
            selected: selectedListId == list.id,
            badge: list.code.isEmpty ? 'LIST' : list.code,
            title: list.name.isEmpty ? list.code : list.name,
            body: [
              if (list.description.isNotEmpty) list.description,
              list.scope == 'route'
                  ? 'Route ${list.routeName}'
                  : list.scope == 'zone'
                  ? 'Zone ${list.zoneName}'
                  : 'All customers',
              if (list.isDefault) 'Default fallback',
            ].where((part) => part.isNotEmpty).join(' · '),
            stats: [
              _Stat('Products', '${list.lineCount}'),
              _Stat('From', list.effectiveFrom.isEmpty ? '—' : list.effectiveFrom),
            ],
            footer: 'View matrix',
            active: list.isActive,
            onTap: () => onSelectList(list.id),
          ),
        for (final category in categories)
          _TierCard(
            selected: selectedKey == category.key,
            badge: category.key,
            title: category.label.isEmpty ? category.key : category.label,
            body: category.description,
            stats: [
              _Stat('Products', '${category.productCount}'),
              _Stat('State', category.active ? 'Active' : 'Inactive'),
            ],
            footer: 'View matrix',
            active: category.active,
            onTap: () => onSelect(category.key),
          ),
      ],
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.selected,
    required this.badge,
    required this.title,
    required this.body,
    required this.stats,
    required this.footer,
    required this.active,
    required this.onTap,
  });

  final bool selected;
  final String badge;
  final String title;
  final String body;
  final List<_Stat> stats;
  final String footer;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFF4F9FD) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AdminTokens.button : AdminTokens.line,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminTokens.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: adminType(10, FontWeight.w700, AdminTokens.button),
                      ),
                    ),
                    const Spacer(),
                    _StatusPill(label: active ? 'Active' : 'Inactive', active: active),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title, style: adminType(14, FontWeight.w700, AdminTokens.text)),
                if (body.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: adminType(12, FontWeight.w500, AdminTokens.textSecondary, height: 1.35),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final stat in stats)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat.label,
                              style: adminType(11, FontWeight.w600, AdminTokens.textSecondary),
                            ),
                            Text(
                              stat.value,
                              style: adminType(13, FontWeight.w700, AdminTokens.text),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    footer,
                    style: adminType(12, FontWeight.w700, AdminTokens.button),
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

class _Matrix extends StatelessWidget {
  const _Matrix({
    required this.categories,
    required this.selectedKey,
    this.listTitle,
    required this.status,
    required this.page,
    required this.rows,
    required this.selectedId,
    required this.failed,
    required this.search,
    required this.onCategory,
    required this.onStatus,
    required this.onSelect,
    required this.onEdit,
    required this.onDuplicate,
    required this.onAssign,
    required this.onPage,
    this.error,
    this.emptyText = 'No approved base-priced products found.',
  });

  final List<ProductCategoryGroup> categories;
  final String selectedKey;
  final String? listTitle;
  final String status;
  final ProductCataloguePage? page;
  final List<ProductBasePriceRow> rows;
  final String? selectedId;
  final bool failed;
  final String? error;
  final TextEditingController search;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onAssign;
  final ValueChanged<int> onPage;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    ProductCategoryGroup? group;
    for (final category in categories) {
      if (category.key == selectedKey) group = category;
    }
    final title = listTitle ??
        (selectedKey == 'all'
            ? 'Approved base price'
            : (group?.label.isEmpty ?? true ? selectedKey : group!.label));
    final total = page?.totalRecords ?? rows.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(title, style: adminType(16, FontWeight.w700, AdminTokens.text)),
              _StatusPill(
                label: listTitle != null
                    ? 'Saved list'
                    : selectedKey == 'all'
                    ? 'Base matrix'
                    : 'Group',
                active: true,
              ),
              Text(
                listTitle != null
                    ? 'Saved rates for this list'
                    : selectedKey == 'all'
                    ? 'Default fallback for new orders'
                    : '${group?.productCount ?? rows.length} products in this group',
                style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                style: adminOutlineButton(),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit List'),
              ),
              OutlinedButton.icon(
                onPressed: onDuplicate,
                style: adminOutlineButton(),
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Duplicate'),
              ),
              FilledButton.icon(
                onPressed: onAssign,
                style: FilledButton.styleFrom(
                  backgroundColor: AdminTokens.button,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                ),
                icon: const Icon(Icons.person_add_alt, size: 16),
                label: const Text('Assign Customers'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Filter product SKU or name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('pricing-status-$status'),
                  initialValue: status,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'unpriced', child: Text('Unpriced')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) {
                    if (value != null) onStatus(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (categories.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _FilterChip(
                  label: 'All groups',
                  selected: selectedKey == 'all',
                  onTap: () => onCategory('all'),
                ),
                for (final category in categories)
                  _FilterChip(
                    label: category.label.isEmpty ? category.key : category.label,
                    selected: selectedKey == category.key,
                    onTap: () => onCategory(category.key),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          if (failed)
            Text(
              error ?? adminUnreachableMessage,
              style: adminType(13, FontWeight.w600, AdminTokens.error),
            )
          else if (page == null || rows.isEmpty)
            Text(
              emptyText,
              style: adminType(13.5, FontWeight.w600, AdminTokens.textSecondary),
            )
          else ...[
            const _MatrixHeader(),
            for (final row in rows)
              _MatrixRow(
                row: row,
                selected: row.id == selectedId,
                onTap: () => onSelect(row.id),
              ),
            const SizedBox(height: 6),
            Text(
              'Gross margin is not shown. Product cost was not returned.',
              style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
            ),
            const SizedBox(height: 8),
            _Pager(page: page!, shown: rows.length, total: total, onPage: onPage),
          ],
        ],
      ),
    );
  }
}

class _MatrixHeader extends StatelessWidget {
  const _MatrixHeader();

  @override
  Widget build(BuildContext context) {
    final style = adminType(10, FontWeight.w700, AdminTokens.textSecondary, letterSpacing: 0.3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('PRODUCT NAME & SKU', style: style)),
          Expanded(flex: 2, child: Text('UNIT', style: style)),
          Expanded(flex: 2, child: Text('BASE SYSTEM', style: style)),
          Expanded(flex: 2, child: Text('LIST RATE', style: style)),
          Expanded(flex: 2, child: Text('DIFFERENCE', style: style)),
          Expanded(flex: 2, child: Text('GROSS MARGIN', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }
}

class _MatrixRow extends StatelessWidget {
  const _MatrixRow({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  final ProductBasePriceRow row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = row.baseSystemPrice;
    final list = row.effectiveBasePrice;
    final difference = base == null || list == null ? null : list - base;
    final active = row.priceStatus.toLowerCase() == 'active';
    return Material(
      color: selected ? const Color(0xFFF4F9FD) : Colors.white,
      child: InkWell(
        key: Key('pricing-row-${row.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Icon(_unitIcon(row.unitLabel), size: 16, color: AdminTokens.button),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.name.isEmpty ? row.sku : row.name,
                            style: adminType(13, FontWeight.w700, AdminTokens.text),
                          ),
                          if (row.sku.isNotEmpty)
                            Text(
                              row.sku,
                              style: adminType(11.5, FontWeight.w500, AdminTokens.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  row.unitLabel.isEmpty ? '—' : row.unitLabel,
                  style: adminType(12, FontWeight.w600, AdminTokens.text),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  base == null ? '—' : formatPkr(base),
                  style: adminType(12, FontWeight.w600, AdminTokens.text),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  list == null ? '—' : formatPkr(list),
                  style: adminType(12, FontWeight.w700, AdminTokens.text),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  difference == null ? '—' : formatPkr(difference),
                  style: adminType(
                    12,
                    FontWeight.w700,
                    difference == null
                        ? AdminTokens.textSecondary
                        : difference < 0
                        ? AdminTokens.error
                        : AdminTokens.success,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '—',
                  style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusPill(
                    label: _statusLabel(row.priceStatus),
                    active: active,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.shown,
    required this.total,
    required this.onPage,
  });

  final ProductCataloguePage page;
  final int shown;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final start = total == 0 ? 0 : ((page.page - 1) * page.pageSize) + 1;
    final end = start == 0 ? 0 : start + shown - 1;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing $start–$end of $total',
            style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
          ),
        ),
        TextButton(
          key: const Key('pricing-prev'),
          onPressed: page.page <= 1 ? null : () => onPage(page.page - 1),
          child: const Text('Previous'),
        ),
        Text(
          '${page.page}',
          style: adminType(12, FontWeight.w700, AdminTokens.text),
        ),
        TextButton(
          key: const Key('pricing-next'),
          onPressed: page.totalPages == 0 || page.page >= page.totalPages
              ? null
              : () => onPage(page.page + 1),
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class _Simulator extends StatelessWidget {
  const _Simulator({
    required this.customer,
    required this.qty,
    required this.rows,
    required this.selected,
    required this.validation,
    required this.lookup,
    required this.customerOpen,
    required this.customerLoading,
    required this.customerHits,
    required this.onCustomer,
    required this.onPickCustomer,
    required this.onProduct,
    required this.onQuantity,
    this.customerHint,
  });

  final TextEditingController customer;
  final TextEditingController qty;
  final List<ProductBasePriceRow> rows;
  final ProductBasePriceRow? selected;
  final AdminLoad<BasePriceValidation>? validation;
  final AdminLoad<CustomerBasePriceLookup>? lookup;
  final bool customerOpen;
  final bool customerLoading;
  final String? customerHint;
  final List<AdminCustomerRow> customerHits;
  final ValueChanged<String> onCustomer;
  final ValueChanged<AdminCustomerRow> onPickCustomer;
  final ValueChanged<String> onProduct;
  final VoidCallback onQuantity;

  @override
  Widget build(BuildContext context) {
    final result = validation?.value;
    final customerPrice = _customerPrice(lookup?.value, selected?.id);
    final unit = customerPrice ?? result?.basePrice;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, color: AdminTokens.button, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pricing simulator',
                      style: adminType(16, FontWeight.w700, AdminTokens.text),
                    ),
                    Text(
                      'Check the approved price for a customer, product, and quantity. This does not create an order.',
                      style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                    ),
                  ],
                ),
              ),
              const _StatusPill(label: 'Read-only check', active: true),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              final fields = [
                Expanded(child: _customerField()),
                const SizedBox(width: 8, height: 8),
                Expanded(child: _productField()),
                const SizedBox(width: 8, height: 8),
                SizedBox(width: stacked ? double.infinity : 140, child: _qtyField()),
              ];
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _customerField(),
                    const SizedBox(height: 8),
                    _productField(),
                    const SizedBox(height: 8),
                    _qtyField(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: fields,
              );
            },
          ),
          const SizedBox(height: 12),
          if (validation?.failed == true)
            Text(
              validation!.error ?? adminUnreachableMessage,
              style: adminType(13, FontWeight.w600, AdminTokens.error),
            )
          else if (result == null)
            Text(
              'Select a product to validate base price × quantity.',
              style: adminType(12.5, FontWeight.w600, AdminTokens.textSecondary),
            )
          else
            _Result(result: result, lookup: lookup, unit: unit),
        ],
      ),
    );
  }

  Widget _customerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('pricing-customer'),
          controller: customer,
          onChanged: onCustomer,
          decoration: InputDecoration(
            labelText: 'Select customer account',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: customerLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (customerOpen && (customerHits.isNotEmpty || customerHint != null))
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AdminTokens.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                for (final row in customerHits)
                  ListTile(
                    dense: true,
                    title: Text(row.businessName),
                    subtitle: Text(
                      'Customer ID: ${row.code.trim().isEmpty ? row.id : row.code.trim()}',
                    ),
                    onTap: () => onPickCustomer(row),
                  ),
                if (customerHint != null)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      customerHint!,
                      style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _productField() {
    if (rows.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Select product SKU',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        child: Text('No products on this page'),
      );
    }
    final current = rows.any((row) => row.id == selected?.id) ? selected?.id : null;
    return DropdownButtonFormField<String>(
      key: const Key('pricing-product'),
      initialValue: current,
      isExpanded: true,
      isDense: true,
      decoration: const InputDecoration(
        labelText: 'Select product SKU',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final row in rows)
          DropdownMenuItem(
            value: row.id,
            child: Text(
              '${row.name.isEmpty ? row.sku : row.name}${row.sku.isEmpty ? '' : ' (${row.sku})'}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: rows.isEmpty ? null : (value) {
        if (value != null) onProduct(value);
      },
    );
  }

  Widget _qtyField() {
    return TextField(
      key: const Key('pricing-qty'),
      controller: qty,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => onQuantity(),
      decoration: const InputDecoration(
        labelText: 'Simulated order qty',
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.result,
    required this.lookup,
    required this.unit,
  });

  final BasePriceValidation result;
  final AdminLoad<CustomerBasePriceLookup>? lookup;
  final num? unit;

  @override
  Widget build(BuildContext context) {
    final account = lookup?.value;
    final model = account?.pricingModel.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _bit(
            'APPLIED PRICE',
            model == null || model.isEmpty ? 'Approved base price' : model,
          ),
          _bit(
            'UNIT',
            unit == null ? '—' : '${formatPkr(unit!)} × ${result.quantity} units',
          ),
          _bit(
            'SIMULATED SUBTOTAL',
            result.subtotal == null ? '—' : formatPkr(result.subtotal!),
          ),
          if (lookup?.failed == true)
            Text(
              lookup!.error ?? 'Customer price could not be loaded.',
              style: adminType(12, FontWeight.w600, AdminTokens.error),
            )
          else if (account != null)
            Text(
              '${account.businessName} · ${account.customerCode}',
              style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _bit(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: adminType(10, FontWeight.w700, AdminTokens.textSecondary)),
        Text(value, style: adminType(16, FontWeight.w700, AdminTokens.text)),
      ],
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
          style: adminType(
            12,
            FontWeight.w700,
            selected ? Colors.white : AdminTokens.text,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AdminTokens.success : AdminTokens.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: adminType(11, FontWeight.w700, color)),
    );
  }
}

ProductBasePriceRow? _findRow(List<ProductBasePriceRow> rows, String? id) {
  for (final row in rows) {
    if (row.id == id) return row;
  }
  return null;
}

num? _customerPrice(CustomerBasePriceLookup? lookup, String? productId) {
  if (lookup == null || productId == null) return null;
  for (final row in lookup.products) {
    if (row.id == productId) return row.effectiveBasePrice;
  }
  return null;
}

IconData _unitIcon(String unit) {
  final value = unit.toLowerCase();
  if (value.contains('pack') || value.contains('case')) return Icons.inventory_2_outlined;
  if (value.contains('empty') || value.contains('asset')) return Icons.shield_outlined;
  return Icons.water_drop_outlined;
}

String _statusLabel(String status) {
  final value = status.trim();
  if (value.isEmpty) return '—';
  return value[0].toUpperCase() + value.substring(1);
}

String _trimNumber(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}

String _csv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
