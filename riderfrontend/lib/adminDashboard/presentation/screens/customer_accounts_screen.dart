import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class CustomerAccountsScreen extends StatefulWidget {
  const CustomerAccountsScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<CustomerAccountsScreen> createState() => _CustomerAccountsScreenState();
}

class _CustomerAccountsScreenState extends State<CustomerAccountsScreen> {
  final _search = TextEditingController();
  var _started = false;
  var _loading = true;
  var _requestsTab = false;
  String? _error;
  CustomerAccountBoard? _board;
  CustomerOpsOverview? _overview;
  List<CustomerRequest> _queue = const [];
  CustomerAccountDetail? _detail;
  List<CustomerLinkReview> _reviews = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final board = await guardAdminLoad(() => api.customerAccountBoard(search: _search.text.trim()));
    final queue = await guardAdminLoad(() => api.customerRequestQueue());
    final overview = await guardAdminLoad(api.customerOpsOverview);
    List<CustomerLinkReview> reviews = const [];
    try {
      reviews = await api.customerLinkReviews(status: 'Pending');
    } on ApiException {
      reviews = const [];
    }
    if (!mounted) return;
    setState(() {
      _board = board.value;
      _queue = queue.value ?? const [];
      _reviews = reviews;
      _overview = overview.value;
      _error = adminErrorBanner([board, queue, overview]);
      _loading = false;
    });
  }

  Future<void> _open(String id) async {
    final detail = await guardAdminLoad(() => ApiScope.of(context).customerAccountDetail(id));
    if (!mounted) return;
    setState(() => _detail = detail.value);
    if (detail.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(detail.error!)));
    }
  }

  Future<void> _review(CustomerRequest request) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _ReviewDialog(request: request),
    );
    if (!mounted || result == null) return;
    final action = result.$1;
    final note = result.$2;
    if (action != 'approve' && note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A comment is required.')));
      return;
    }
    try {
      final updated = await ApiScope.of(context).reviewCustomerRequest(request.id, action: action, comment: note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${updated.code} is ${updated.status}.')));
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _link() async {
    final detail = _detail;
    if (detail == null) return;
    final email = TextEditingController(text: detail.account.email);
    final code = TextEditingController();
    final proposed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Propose a route link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The portal email and the route customer code must both match. The link is written only after a second approval.'),
            const SizedBox(height: 12),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Portal email')),
            TextField(key: Key('admin-link-${detail.account.id}'), controller: code, decoration: const InputDecoration(labelText: 'Route customer code')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Propose')),
        ],
      ),
    );
    final emailText = email.text.trim();
    final codeText = code.text.trim();
    email.dispose();
    code.dispose();
    if (proposed != true || !mounted) return;
    try {
      await ApiScope.of(context).proposeCustomerLink(detail.account.id, email: emailText, customerCode: codeText);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link proposed. Approve it from the pending reviews.')));
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _decideLink(CustomerLinkReview review, String action) async {
    var comment = '';
    if (action == 'reject') {
      final controller = TextEditingController();
      final rejected = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject link'),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Comment')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject')),
          ],
        ),
      );
      comment = controller.text.trim();
      controller.dispose();
      if (rejected != true || !mounted) return;
      if (comment.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A comment is required.')));
        return;
      }
    }
    try {
      await ApiScope.of(context).reviewCustomerLink(review.id, action: action, comment: comment);
      if (!mounted) return;
      await _load();
      if (_detail?.account.id == review.customerAccountId) await _open(review.customerAccountId);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _status(String status) async {
    final detail = _detail;
    if (detail == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == 'Suspended' ? 'Suspend account' : 'Reactivate account'),
        content: const Text('The customer cannot sign in while the account is suspended.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final updated = await ApiScope.of(context).setCustomerAccountStatus(detail.account.id, status);
      if (!mounted) return;
      setState(() => _detail = updated);
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    return AdminShell(
      activeKey: AdminNav.customerAccounts,
      session: widget.session,
      serverReachable: _error != adminUnreachableMessage,
      search: _search,
      onSearch: (_) => _load(),
      onNavigate: widget.onNavigate,
      searchHint: 'Search customer accounts',
      body: ListView(
        key: const Key('admin-customer-accounts'),
        padding: const EdgeInsets.all(16),
        children: [
          Text('Customer Management', style: adminType(24, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 8),
          Text('App accounts stay separate from route customers. A new schedule needs an approved email and customer-code link. Requests do not change a schedule until you approve them.', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary)),
          if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Pending link reviews', style: adminType(16, FontWeight.w700, AdminTokens.text)),
            for (final review in _reviews)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${review.accountCode} · ${review.accountEmail}'),
                subtitle: Text('${review.customerCode} · ${review.customerName}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(onPressed: () => _decideLink(review, 'approve'), child: const Text('Approve')),
                    TextButton(onPressed: () => _decideLink(review, 'reject'), child: const Text('Reject')),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          if (_overview != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _jump('Customers', _overview!.totalCustomers, () => setState(() => _requestsTab = false)),
                _jump('Active schedules', _overview!.withSchedules, () => widget.onNavigate(AdminNav.recurringSchedules)),
                _jump('Upcoming', _overview!.upcomingDeliveries, () => widget.onNavigate(AdminNav.recurringSchedules)),
                _jump('Completed', _overview!.completedDeliveries, () => widget.onNavigate(AdminNav.recurringSchedules)),
                _jump('With balance', _overview!.withBalance, () => widget.onNavigate(AdminNav.collectionsManagement)),
                _jump('Pending requests', _overview!.pendingRequests, () => setState(() => _requestsTab = true)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Registrations', style: adminType(14, FontWeight.w700, AdminTokens.text)),
            for (final row in _overview!.registrations) Text('${row.month}: ${row.count}', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary)),
            const SizedBox(height: 8),
            Text('Deliveries', style: adminType(14, FontWeight.w700, AdminTokens.text)),
            for (final row in _overview!.deliveries) Text('${row.month}: ${row.count}', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary)),
            const SizedBox(height: 8),
            for (final row in _overview!.upcoming)
              Text('${row.date} · ${row.customerName} · ${row.scheduleCode} · ${row.quantity} · ${row.status}', style: adminType(13, FontWeight.w600, AdminTokens.text)),
            const SizedBox(height: 12),
          ],
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!, style: adminType(14, FontWeight.w600, AdminTokens.error)),
          if (board != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _stat('Customers', board.total),
                _stat('Active', board.active),
                _stat('Inactive', board.inactive),
                _stat('With schedules', board.withSchedules),
                _stat('With balance', board.withBalance),
                _stat('Pending requests', board.pendingRequests),
              ],
            ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Accounts')),
              ButtonSegment(value: true, label: Text('Requests', key: Key('admin-customer-requests-tab'))),
            ],
            selected: {_requestsTab},
            onSelectionChanged: (value) => setState(() => _requestsTab = value.first),
          ),
          const SizedBox(height: 12),
          if (!_requestsTab && board != null)
            for (final row in board.rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AdminTokens.surface,
                  child: InkWell(
                    key: Key('admin-account-${row.id}'),
                    onTap: () => _open(row.id),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: AdminTokens.line), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${row.code} · ${row.name}', style: adminType(15, FontWeight.w700, AdminTokens.text)),
                          Text('${row.phone} · ${row.email} · ${row.city}', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary)),
                          Text('${row.status} · schedules ${row.activeSchedules} · balance ${row.outstanding} · requests ${row.pendingRequests}', style: adminType(13, FontWeight.w600, AdminTokens.text)),
                          Text(row.linked ? 'Route ${row.deliveryCustomerCode} ${row.deliveryCustomerName}' : 'Not linked to a route customer', style: adminType(13, FontWeight.w600, AdminTokens.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          if (_requestsTab) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _stat('Total', _queue.length),
                _stat('Pending', _queue.where((item) => item.status == 'Pending' || item.status == 'UnderReview' || item.status == 'MoreInformationRequired').length),
                _stat('Schedule', _queue.where((item) => item.type == 'ScheduleChange').length),
                _stat('Pause', _queue.where((item) => item.type == 'Pause').length),
                _stat('Quantity', _queue.where((item) => item.type == 'QuantityChange').length),
                _stat('Address', _queue.where((item) => item.type == 'AddressChange').length),
                _stat('Applied', _queue.where((item) => item.status == 'Applied').length),
                _stat('Rejected', _queue.where((item) => item.status == 'Rejected').length),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in _queue)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AdminTokens.surface,
                  child: InkWell(
                    key: Key('admin-request-${row.code}'),
                    onTap: () => _review(row),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(border: Border.all(color: AdminTokens.line), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${row.code} · ${row.customerName} · ${row.type}', style: adminType(15, FontWeight.w700, AdminTokens.text)),
                          Text(row.requestedSummary, style: adminType(13, FontWeight.w500, AdminTokens.text)),
                          Text(row.status, style: adminType(13, FontWeight.w700, AdminTokens.warning)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (_requestsTab && !_loading && _queue.isEmpty) const Text('No requests are waiting.'),
          if (_detail != null) ...[
            const SizedBox(height: 16),
            Text('Account detail', style: adminType(18, FontWeight.w700, AdminTokens.text)),
            const SizedBox(height: 8),
            Text('${_detail!.profile.firstName} ${_detail!.profile.lastName} · ${_detail!.account.code}', style: adminType(14, FontWeight.w600, AdminTokens.text)),
            Text(_detail!.payments.summary.note, style: adminType(13, FontWeight.w500, AdminTokens.textSecondary)),
            Text('Billed ${_detail!.payments.summary.totalBilled} · paid ${_detail!.payments.summary.totalPaid} · outstanding ${_detail!.payments.summary.outstanding}', style: adminType(13, FontWeight.w600, AdminTokens.text)),
            for (final invoice in _detail!.payments.invoices)
              Text('${invoice.number} · ${invoice.date} · ${invoice.status} · remaining ${invoice.remaining}', style: adminType(13, FontWeight.w500, AdminTokens.text)),
            const Text('Collected by Rider is not company cash until a warehouse cashier confirms Cash Received. Online payment is not enabled.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: _link, child: const Text('Propose route link')),
                OutlinedButton(onPressed: () => widget.onNavigate(AdminNav.recurringSchedules), child: const Text('Open schedules')),
                OutlinedButton(onPressed: () => widget.onNavigate(AdminNav.collectionsManagement), child: const Text('Record cash in Collections')),
                OutlinedButton(
                  onPressed: () => _status(_detail!.account.status == 'Suspended' ? 'Active' : 'Suspended'),
                  child: Text(_detail!.account.status == 'Suspended' ? 'Reactivate' : 'Suspend'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final plan in _detail!.schedules)
              Text('${plan.code} · ${plan.product} · ${plan.quantity} · ${plan.status}', style: adminType(13, FontWeight.w600, AdminTokens.text)),
            for (final entry in _detail!.timeline.take(8))
              Text('${entry.timestamp} · ${entry.action} · ${entry.newValue}', style: adminType(12, FontWeight.w500, AdminTokens.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _jump(String label, int value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AdminTokens.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminTokens.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: adminType(20, FontWeight.w700, AdminTokens.text)),
            Text(label, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AdminTokens.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminTokens.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: adminType(20, FontWeight.w700, AdminTokens.text)),
          Text(label, style: adminType(12, FontWeight.w600, AdminTokens.textSecondary)),
        ],
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.request});

  final CustomerRequest request;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  String? _impact;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_impact != null) return;
    _impact = '';
    ApiScope.of(context).customerRequestImpact(widget.request.id).then((impact) {
      if (!mounted) return;
      setState(() => _impact = '${impact.summary} ${impact.scheduledCount} scheduled, ${impact.publishedCount} dispatched, ${impact.completedCount} completed. ${impact.dispatchedNote} ${impact.inventoryNote} ${impact.pricingNote}');
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _close(String action) => Navigator.pop(context, (action, _comment.text.trim()));

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return AlertDialog(
      key: const Key('admin-request-review'),
      title: Text(request.code),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${request.customerName} · ${request.type}', style: adminType(14, FontWeight.w700, AdminTokens.text)),
              const SizedBox(height: 8),
              Text(request.currentSummary, style: adminType(13, FontWeight.w500, AdminTokens.text)),
              const SizedBox(height: 8),
              Text(request.requestedSummary, style: adminType(13, FontWeight.w500, AdminTokens.text)),
              const SizedBox(height: 8),
              Text(request.affectedDates, style: adminType(13, FontWeight.w600, AdminTokens.text)),
              if (_impact != null && _impact!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_impact!, style: adminType(13, FontWeight.w600, AdminTokens.text)),
              ],
              const SizedBox(height: 8),
              Text('Dispatched visits stay assigned. Completed visits stay as recorded.', style: adminType(13, FontWeight.w600, AdminTokens.textSecondary)),
              const SizedBox(height: 8),
              Text('Inventory availability is not calculated here. Issued invoices are not changed.', style: adminType(13, FontWeight.w500, AdminTokens.textSecondary)),
              const SizedBox(height: 8),
              TextField(key: const Key('admin-review-comment'), controller: _comment, decoration: const InputDecoration(labelText: 'Comment')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        TextButton(key: const Key('admin-review-more'), onPressed: () => _close('more'), child: const Text('Ask for information')),
        TextButton(key: const Key('admin-review-reject'), onPressed: () => _close('reject'), child: const Text('Reject')),
        FilledButton(key: const Key('admin-review-approve'), onPressed: () => _close('approve'), child: const Text('Approve')),
      ],
    );
  }
}
