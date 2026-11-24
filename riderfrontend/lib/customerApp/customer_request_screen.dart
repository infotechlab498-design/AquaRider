import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/customer_theme.dart';

class CustomerRequestForm extends StatefulWidget {
  const CustomerRequestForm({required this.type, super.key});

  final String type;

  @override
  State<CustomerRequestForm> createState() => _CustomerRequestFormState();
}

class _CustomerRequestFormState extends State<CustomerRequestForm> {
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  final _quantity = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _street = TextEditingController();
  final _house = TextEditingController();
  final _effective = TextEditingController();
  final _pauseStart = TextEditingController();
  final _resume = TextEditingController();
  var _started = false;
  var _busy = false;
  String? _error;
  List<CustomerPlan> _plans = const [];
  String? _scheduleId;
  var _frequency = 'Weekly';
  var _window = 'Morning';
  List<CustomerAddress> _addresses = const [];
  String? _addressId;
  final _monthDays = TextEditingController(text: '1, 15');
  final _days = <int>{1, 3, 5};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    _quantity.dispose();
    _city.dispose();
    _area.dispose();
    _street.dispose();
    _house.dispose();
    _effective.dispose();
    _pauseStart.dispose();
    _resume.dispose();
    _monthDays.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ApiScope.of(context);
      final plans = await api.customerSchedules();
      final profile = widget.type == 'AddressChange' ? await api.customerProfile() : null;
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _scheduleId = plans.isEmpty ? null : plans.first.scheduleId;
        if (plans.isNotEmpty) _quantity.text = '${plans.first.quantity}';
        _addresses = profile?.addresses.where((item) => item.isActive).toList() ?? const [];
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  String _quantityLabel(int current, int requested) {
    final difference = requested - current;
    final direction = difference == 0 ? 'No change' : difference > 0 ? 'Increase' : 'Decrease';
    return '$direction · current $current · requested $requested · difference $difference';
  }

  String get _title => switch (widget.type) {
        'Pause' => 'Pause Deliveries',
        'QuantityChange' => 'Change Bottle Quantity',
        'AddressChange' => 'Request Address Change',
        _ => 'Request Schedule Change',
      };

  Future<void> _submit() async {
    if (_busy) return;
    if (_scheduleId == null) {
      setState(() => _error = 'No delivery schedule is linked to this account yet.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = {
        'type': widget.type,
        'scheduleId': _scheduleId,
        'reason': _reason.text.trim(),
        'notes': _notes.text.trim(),
        'frequency': _frequency,
        'weekdays': _days.toList(),
        'monthDays': _monthDays.text.split(',').map((item) => int.tryParse(item.trim())).whereType<int>().toList(),
        'timeWindow': _window,
        'effectiveDate': _effective.text.trim().isEmpty ? null : _effective.text.trim(),
        'pauseStart': _pauseStart.text.trim().isEmpty ? null : _pauseStart.text.trim(),
        'resumeDate': _resume.text.trim().isEmpty ? null : _resume.text.trim(),
        'quantity': int.tryParse(_quantity.text.trim()),
        'city': _city.text.trim(),
        'area': _area.text.trim(),
        'street': _street.text.trim(),
        'houseNumber': _house.text.trim(),
      };
      CustomerRequestPreview? preview;
      try {
        preview = await ApiScope.of(context).previewCustomerRequest(body);
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _error = error.message;
          _busy = false;
        });
        return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('customer-request-confirm'),
          title: const Text('Submit this request?'),
          content: Text(preview == null ? 'The schedule stays unchanged until the office approves it.' : '${preview.summary}\n${preview.dispatchedNote}\n${preview.scheduledCount} scheduled, ${preview.publishedCount} dispatched, ${preview.completedCount} completed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
            FilledButton(key: const Key('customer-request-confirm-submit'), onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        setState(() => _busy = false);
        return;
      }
      final created = await ApiScope.of(context).submitCustomerRequest(body);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => CustomerRequestResult(request: created)));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot reach the route server.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plans.cast<CustomerPlan?>().firstWhere((item) => item?.scheduleId == _scheduleId, orElse: () => null);
    return Scaffold(
      key: const Key('customer-request-form'),
      backgroundColor: customerPage,
      appBar: AppBar(backgroundColor: customerPage, foregroundColor: customerNavy, elevation: 0, title: Text(_title)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            key: const Key('customer-request-list'),
            padding: const EdgeInsets.all(16),
            children: [
              Text('This request does not change the active schedule. The office reviews it first.', style: customerType(14, FontWeight.w600, customerNavy)),
              const SizedBox(height: 12),
              if (_plans.isEmpty)
                const CustomerCard(child: Text('No delivery schedule is linked to this account yet.')),
              if (_plans.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: const Key('customer-request-schedule'),
                  initialValue: _scheduleId,
                  decoration: customerField('Schedule'),
                  items: [for (final item in _plans) DropdownMenuItem(value: item.scheduleId, child: Text(item.code))],
                  onChanged: (value) => setState(() {
                    _scheduleId = value;
                    final selected = _plans.cast<CustomerPlan?>().firstWhere((item) => item?.scheduleId == value, orElse: () => null);
                    if (selected != null) _quantity.text = '${selected.quantity}';
                  }),
                ),
              if (plan != null) ...[
                const SizedBox(height: 12),
                CustomerCard(child: Text('Current: ${plan.frequency} · ${plan.quantity} · ${plan.timeWindow}\n${plan.address}', style: customerType(14, FontWeight.w600, customerNavy))),
              ],
              const SizedBox(height: 12),
              if (widget.type == 'ScheduleChange') ...[
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: customerField('Requested frequency'),
                  items: const [
                    DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) => setState(() => _frequency = value ?? 'Weekly'),
                ),
                const SizedBox(height: 8),
                if (_frequency == 'Weekly') Wrap(spacing: 8, children: [
                  for (var day = 0; day < 7; day++)
                    FilterChip(
                      label: Text(const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day]),
                      selected: _days.contains(day),
                      onSelected: (selected) => setState(() => selected ? _days.add(day) : _days.remove(day)),
                    ),
                ]),
                if (_frequency == 'Monthly') ...[
                  const SizedBox(height: 8),
                  TextField(controller: _monthDays, decoration: customerField('Month dates', hint: '1, 15')),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _window,
                  decoration: customerField('Delivery window'),
                  items: const [
                    DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                    DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon')),
                    DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                  ],
                  onChanged: (value) => setState(() => _window = value ?? 'Morning'),
                ),
                const SizedBox(height: 8),
                TextField(controller: _effective, decoration: customerField('Effective date', hint: 'YYYY-MM-DD')),
              ],
              if (widget.type == 'Pause') ...[
                TextField(key: const Key('customer-pause-start'), controller: _pauseStart, decoration: customerField('Pause start', hint: 'YYYY-MM-DD')),
                const SizedBox(height: 8),
                TextField(key: const Key('customer-pause-resume'), controller: _resume, decoration: customerField('Resume date', hint: 'YYYY-MM-DD')),
              ],
              if (widget.type == 'QuantityChange') ...[
                TextField(
                  key: const Key('customer-quantity'),
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: customerField('Requested quantity'),
                  onChanged: (_) => setState(() {}),
                ),
                if (plan != null && int.tryParse(_quantity.text.trim()) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_quantityLabel(plan.quantity, int.parse(_quantity.text.trim())), style: customerType(13, FontWeight.w700, customerNavy)),
                  ),
                const SizedBox(height: 8),
                TextField(controller: _effective, decoration: customerField('Effective date', hint: 'YYYY-MM-DD')),
              ],
              if (widget.type == 'AddressChange') ...[
                if (_addresses.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _addressId,
                    decoration: customerField('Saved address'),
                    items: [for (final item in _addresses) DropdownMenuItem(value: item.id, child: Text('${item.label} · ${item.street}'))],
                    onChanged: (value) {
                      final selected = _addresses.cast<CustomerAddress?>().firstWhere((item) => item?.id == value, orElse: () => null);
                      setState(() {
                        _addressId = value;
                        if (selected == null) return;
                        _city.text = selected.city;
                        _area.text = selected.area;
                        _street.text = selected.street;
                        _house.text = selected.houseNumber;
                      });
                    },
                  ),
                const SizedBox(height: 8),
                TextField(controller: _city, decoration: customerField('City')),
                const SizedBox(height: 8),
                TextField(controller: _area, decoration: customerField('Area')),
                const SizedBox(height: 8),
                TextField(controller: _street, decoration: customerField('Street')),
                const SizedBox(height: 8),
                TextField(controller: _house, decoration: customerField('House number')),
              ],
              const SizedBox(height: 8),
              TextField(key: const Key('customer-request-reason'), controller: _reason, decoration: customerField('Reason')),
              const SizedBox(height: 8),
              TextField(controller: _notes, decoration: customerField('Additional notes'), maxLines: 3),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, key: const Key('customer-request-error'), style: customerType(13, FontWeight.w600, customerError)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('customer-request-submit'),
                style: customerPrimaryButton(),
                onPressed: _busy || _plans.isEmpty ? null : _submit,
                child: Text(_busy ? 'Submitting' : 'Submit request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerRequestResult extends StatelessWidget {
  const CustomerRequestResult({required this.request, super.key});

  final CustomerRequest request;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('customer-request-result'),
      backgroundColor: customerPage,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Request submitted', style: customerType(26, FontWeight.w700, customerNavy)),
              const SizedBox(height: 12),
              Text(request.code, key: const Key('customer-request-code'), style: customerType(20, FontWeight.w700, customerPrimary)),
              const SizedBox(height: 8),
              Text('Status: ${request.status}', style: customerType(16, FontWeight.w700, customerStatusColor(request.status))),
              const SizedBox(height: 8),
              Text(request.requestedSummary, style: customerType(14, FontWeight.w500, customerNavy)),
              const SizedBox(height: 8),
              Text('The current schedule stays in place until the office applies this request.', style: customerType(14, FontWeight.w600, customerMuted)),
              const Spacer(),
              FilledButton(
                style: customerPrimaryButton(),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerRequestsScreen extends StatefulWidget {
  const CustomerRequestsScreen({super.key});

  @override
  State<CustomerRequestsScreen> createState() => _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState extends State<CustomerRequestsScreen> {
  var _started = false;
  var _loading = true;
  String? _error;
  List<CustomerRequest> _rows = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ApiScope.of(context).customerRequests();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('customer-requests-screen'),
      backgroundColor: customerPage,
      appBar: AppBar(backgroundColor: customerPage, foregroundColor: customerNavy, elevation: 0, title: const Text('My Requests')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(color: customerPrimary),
          if (_error != null) Text(_error!, style: customerType(14, FontWeight.w600, customerError)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _count('Pending', _rows.where((item) => item.status == 'Pending' || item.status == 'UnderReview' || item.status == 'MoreInformationRequired').length),
              _count('Approved', _rows.where((item) => item.status == 'Approved' || item.status == 'Applied').length),
              _count('Rejected', _rows.where((item) => item.status == 'Rejected').length),
              _count('Applied', _rows.where((item) => item.status == 'Applied').length),
            ],
          ),
          const SizedBox(height: 12),
          if (!_loading && _rows.isEmpty) const CustomerCard(child: Text('No requests yet.')),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerRequestDetail(request: row))),
                child: CustomerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row.code} · ${_typeLabel(row.type)}', style: customerType(15, FontWeight.w700, customerNavy)),
                      if (row.scheduleCode != null) Text(row.scheduleCode!, style: customerType(12, FontWeight.w600, customerMuted)),
                      Text('Submitted ${row.createdAt}', style: customerType(12, FontWeight.w500, customerMuted)),
                      if (row.effectiveDate != null) Text('Effective ${row.effectiveDate}', style: customerType(12, FontWeight.w600, customerNavy)),
                      if (row.pauseStart != null) Text('Pause ${row.pauseStart} · resume ${row.resumeDate ?? ''}', style: customerType(12, FontWeight.w600, customerNavy)),
                      Text(row.status, style: customerType(13, FontWeight.w700, customerStatusColor(row.status))),
                      Text('Updated ${row.reviewedAt ?? row.createdAt}', style: customerType(12, FontWeight.w500, customerMuted)),
                      if (row.adminComment != null) Text(row.adminComment!, style: customerType(13, FontWeight.w500, customerNavy)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _count(String label, int value) {
    return SizedBox(
      width: 140,
      child: CustomerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: customerType(20, FontWeight.w700, customerNavy)),
            Text(label, style: customerType(12, FontWeight.w600, customerMuted)),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'Pause' => 'Temporary Pause',
        'QuantityChange' => 'Bottle Quantity Change',
        'AddressChange' => 'Delivery Address Change',
        _ => 'Schedule Change',
      };
}

class CustomerRequestDetail extends StatefulWidget {
  const CustomerRequestDetail({required this.request, super.key});

  final CustomerRequest request;

  @override
  State<CustomerRequestDetail> createState() => _CustomerRequestDetailState();
}

class _CustomerRequestDetailState extends State<CustomerRequestDetail> {
  late CustomerRequest _request = widget.request;
  final _reply = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  bool get _open => _request.status == 'Pending' || _request.status == 'UnderReview' || _request.status == 'MoreInformationRequired';

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      final updated = await ApiScope.of(context).cancelCustomerRequest(_request.id);
      if (!mounted) return;
      setState(() {
        _request = updated;
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

  Future<void> _sendReply() async {
    setState(() => _busy = true);
    try {
      final updated = await ApiScope.of(context).replyCustomerRequest(_request.id, _reply.text.trim());
      if (!mounted) return;
      setState(() {
        _request = updated;
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

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return Scaffold(
      key: const Key('customer-request-detail'),
      backgroundColor: customerPage,
      appBar: AppBar(backgroundColor: customerPage, foregroundColor: customerNavy, elevation: 0, title: Text(request.code)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CustomerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.status, style: customerType(16, FontWeight.w700, customerStatusColor(request.status))),
                const SizedBox(height: 8),
                Text('Current', style: customerType(12, FontWeight.w700, customerMuted)),
                Text(request.currentSummary, style: customerType(14, FontWeight.w500, customerNavy)),
                const SizedBox(height: 8),
                Text('Requested', style: customerType(12, FontWeight.w700, customerMuted)),
                Text(request.requestedSummary, style: customerType(14, FontWeight.w500, customerNavy)),
                const SizedBox(height: 8),
                Text('Reason: ${request.reason}', style: customerType(14, FontWeight.w600, customerNavy)),
                if (request.notes != null && request.notes!.isNotEmpty) Text(request.notes!, style: customerType(13, FontWeight.w500, customerNavy)),
                if (request.affectedDates.isNotEmpty) Text(request.affectedDates, style: customerType(13, FontWeight.w500, customerMuted)),
                if (request.adminComment != null) Text('Office: ${request.adminComment}', style: customerType(14, FontWeight.w700, customerNavy)),
                if (request.effectiveDate != null) Text('Effective ${request.effectiveDate}', style: customerType(13, FontWeight.w600, customerNavy)),
                if (request.pauseStart != null) Text('Pause ${request.pauseStart} until ${request.resumeDate ?? ''}', style: customerType(13, FontWeight.w600, customerNavy)),
                if (request.status == 'Applied') Text('The office applied this to eligible future deliveries. Completed visits stay as recorded.', style: customerType(13, FontWeight.w600, customerNavy)),
              ],
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: customerType(13, FontWeight.w600, customerError))),
          if (_open) ...[
            const SizedBox(height: 12),
            OutlinedButton(key: const Key('customer-request-cancel'), onPressed: _busy ? null : _cancel, child: const Text('Cancel request')),
          ],
          if (request.status == 'MoreInformationRequired') ...[
            const SizedBox(height: 12),
            TextField(controller: _reply, decoration: customerField('Reply'), maxLines: 3),
            const SizedBox(height: 8),
            FilledButton(style: customerPrimaryButton(), onPressed: _busy ? null : _sendReply, child: const Text('Send reply')),
          ],
        ],
      ),
    );
  }
}

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});

  @override
  State<CustomerNotificationsScreen> createState() => _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState extends State<CustomerNotificationsScreen> {
  var _started = false;
  var _loading = true;
  String? _error;
  List<CustomerNote> _rows = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ApiScope.of(context).customerNotifications();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('customer-notification-center'),
      backgroundColor: customerPage,
      appBar: AppBar(
        backgroundColor: customerPage,
        foregroundColor: customerNavy,
        elevation: 0,
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: () async {
            try {
              await ApiScope.of(context).readAllCustomerNotifications();
            } on ApiException {
              // The list still shows the stored messages.
            }
            if (mounted) _load();
          }, child: const Text('Mark all read')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(color: customerPrimary),
          if (_error != null) Text(_error!, style: customerType(14, FontWeight.w600, customerError)),
          if (!_loading && _rows.isEmpty) const CustomerCard(child: Text('No notifications yet.')),
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () async {
                  try {
                    await ApiScope.of(context).readCustomerNotification(row.id);
                  } on ApiException {
                    // The row still shows the stored message.
                  }
                  if (!context.mounted) return;
                  if (row.requestId.isNotEmpty) {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CustomerRequestsScreen()));
                  }
                  _load();
                },
                child: CustomerCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.title, style: customerType(15, FontWeight.w700, row.read ? customerMuted : customerNavy)),
                      Text(row.body, style: customerType(13, FontWeight.w500, customerMuted)),
                      Text(row.createdAt, style: customerType(12, FontWeight.w500, customerMuted)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
