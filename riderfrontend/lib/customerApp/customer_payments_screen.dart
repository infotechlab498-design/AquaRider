import 'package:flutter/material.dart';

import 'package:riderfrontend/api/office_document.dart';
import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/customer_request_screen.dart';
import 'package:riderfrontend/customerApp/customer_theme.dart';

const _navy = Color(0xFF102448);
const _blue = Color(0xFF0875E8);
const _muted = Color(0xFF6A7C90);
const _billedBg = Color(0xFFE8F4FF);
const _paidBg = Color(0xFFE6F7ED);
const _outstandingBg = Color(0xFFFFF4E5);
const _overdueBg = Color(0xFFFDECEC);

class CustomerPaymentsScreen extends StatefulWidget {
  const CustomerPaymentsScreen({this.standalone = false, this.reloadToken = 0, super.key});

  final bool standalone;
  final int reloadToken;

  @override
  State<CustomerPaymentsScreen> createState() => _CustomerPaymentsScreenState();
}

class _CustomerPaymentsScreenState extends State<CustomerPaymentsScreen> {
  var _started = false;
  var _loading = true;
  var _showAllInvoices = false;
  var _showAllPayments = false;
  String? _error;
  CustomerPayments? _data;
  int _unread = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void didUpdateWidget(covariant CustomerPaymentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ApiScope.of(context);
      final data = await api.customerPayments();
      var unread = 0;
      try {
        unread = (await api.customerNotifications()).where((item) => !item.read).length;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _data = data;
        _unread = unread;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot reach the route server.';
        _loading = false;
      });
    }
  }

  String _rs(num value) => 'Rs ${customerMoney(value)}';

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final landscape = constraints.maxHeight > 0 && constraints.maxWidth / constraints.maxHeight > 1.15;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFF2F8FE)),
            Positioned.fill(
              child: Image.asset(
                'assets/customer_home/payments/payments_bg.jpg',
                fit: landscape ? BoxFit.cover : BoxFit.cover,
                alignment: landscape ? Alignment.center : Alignment.topCenter,
              ),
            ),
            SafeArea(
              bottom: widget.standalone,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 980 : 560),
                  child: RefreshIndicator(
                    color: _blue,
                    onRefresh: _load,
                    child: ListView(
                      key: const Key('customer-payments-screen'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 8, 16, widget.standalone ? 24 : 12),
                      children: [
                        _header(),
                        const SizedBox(height: 8),
                        if (_loading) const LinearProgressIndicator(color: _blue, minHeight: 2),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: customerType(14, FontWeight.w600, const Color(0xFFDC2626))),
                          TextButton(onPressed: _load, child: const Text('Try again')),
                        ],
                        if (data != null) ...[
                          Text(
                            data.summary.note,
                            key: const Key('customer-payment-note'),
                            style: customerType(12, FontWeight.w500, _muted, height: 1.35),
                          ),
                          const SizedBox(height: 12),
                          _stats(data.summary, wide || landscape),
                          if (data.summary.lastPaymentDate != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Last cash recorded ${data.summary.lastPaymentDate}${data.summary.lastPaymentAmount == null ? '' : ' · ${_rs(data.summary.lastPaymentAmount!)}'}',
                              style: customerType(12, FontWeight.w600, _muted),
                            ),
                          ],
                          const SizedBox(height: 18),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _invoicesBlock(data.invoices)),
                                const SizedBox(width: 14),
                                Expanded(child: _paymentsBlock(data.payments)),
                              ],
                            )
                          else ...[
                            _invoicesBlock(data.invoices),
                            const SizedBox(height: 16),
                            _paymentsBlock(data.payments),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (!widget.standalone) return body;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FE),
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: _navy, elevation: 0, title: const Text('Payments')),
      body: body,
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset('assets/customer_home/branding/aquarider_logo.png', height: 36, fit: BoxFit.contain),
            const Spacer(),
            Material(
              color: Colors.white,
              elevation: 1,
              shadowColor: const Color(0x220875E8),
              shape: const CircleBorder(),
              child: IconButton(
                key: const Key('customer-payments-notifications'),
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CustomerNotificationsScreen())),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(34, 34),
                  fixedSize: const Size(34, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Badge(
                  isLabelVisible: _unread > 0,
                  backgroundColor: const Color(0xFFE23B4A),
                  smallSize: 8,
                  child: const Icon(Icons.notifications_none_rounded, color: _navy, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Payments', style: customerType(28, FontWeight.w800, _navy, height: 1.1)),
        const SizedBox(height: 4),
        Text('Your invoices and payment history', style: customerType(14, FontWeight.w500, _muted)),
      ],
    );
  }

  Widget _stats(CustomerMoney money, bool wide) {
    final cards = [
      _statCard('Billed', _rs(money.totalBilled), _billedBg, const Color(0xFF0875E8), Icons.description_outlined),
      _statCard('Paid', _rs(money.totalPaid), _paidBg, const Color(0xFF16834A), Icons.check_circle_outline),
      _statCard('Outstanding', _rs(money.outstanding), _outstandingBg, const Color(0xFFE99A22), Icons.hourglass_bottom_rounded),
      _statCard('Overdue', _rs(money.overdue), _overdueBg, const Color(0xFFDC2626), Icons.warning_amber_rounded),
    ];
    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(children: [Expanded(child: cards[0]), const SizedBox(width: 10), Expanded(child: cards[1])]),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: cards[2]), const SizedBox(width: 10), Expanded(child: cards[3])]),
      ],
    );
  }

  Widget _statCard(String label, String value, Color background, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0F0B4F93), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.72), shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(height: 12),
          Text(label, style: customerType(13, FontWeight.w600, _muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: customerType(22, FontWeight.w800, _navy, height: 1.15)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required VoidCallback onViewAll,
    required bool expanded,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE8F4FF), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: _blue),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: customerType(17, FontWeight.w800, _navy))),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(
            foregroundColor: _blue,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(expanded ? 'Show less' : 'View All', style: customerType(13, FontWeight.w700, _blue)),
              Icon(expanded ? Icons.keyboard_arrow_up : Icons.arrow_forward_ios_rounded, size: 13, color: _blue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x140875C8), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }

  Widget _invoicesBlock(List<CustomerInvoiceRow> invoices) {
    final visible = _showAllInvoices ? invoices : invoices.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          icon: Icons.description_outlined,
          title: 'Invoices',
          expanded: _showAllInvoices,
          onViewAll: () => setState(() => _showAllInvoices = !_showAllInvoices),
        ),
        const SizedBox(height: 10),
        _panel(
          child: invoices.isEmpty
              ? _emptyState(
                  art: const _InvoiceEmptyArt(),
                  title: 'No invoices yet',
                  subtitle: 'Your invoices will appear here after each delivery.',
                )
              : Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) const Divider(height: 18, color: Color(0xFFE8F0F7)),
                      _invoiceRow(visible[i]),
                    ],
                    if (!_showAllInvoices && invoices.length > 3) ...[
                      const SizedBox(height: 8),
                      Text('${invoices.length - 3} more invoice${invoices.length - 3 == 1 ? '' : 's'}', style: customerType(12, FontWeight.w600, _muted)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _paymentsBlock(List<CustomerPaymentRow> payments) {
    final visible = _showAllPayments ? payments : payments.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          icon: Icons.history_rounded,
          title: 'Payment History',
          expanded: _showAllPayments,
          onViewAll: () => setState(() => _showAllPayments = !_showAllPayments),
        ),
        const SizedBox(height: 10),
        _panel(
          child: payments.isEmpty
              ? _emptyState(
                  art: Image.asset('assets/customer_home/images/payments_wallet_illustration.png', width: 120, height: 100, fit: BoxFit.contain),
                  title: 'No payment History yet',
                  subtitle: 'Payments will appear here once recorded.',
                )
              : Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) const Divider(height: 18, color: Color(0xFFE8F0F7)),
                      _paymentRow(visible[i]),
                    ],
                    if (!_showAllPayments && payments.length > 3) ...[
                      const SizedBox(height: 8),
                      Text('${payments.length - 3} more payment${payments.length - 3 == 1 ? '' : 's'}', style: customerType(12, FontWeight.w600, _muted)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _emptyState({required Widget art, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          art,
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: customerType(16, FontWeight.w800, _navy)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: customerType(13, FontWeight.w500, _muted)),
        ],
      ),
    );
  }

  Widget _invoiceRow(CustomerInvoiceRow row) {
    return InkWell(
      key: Key('customer-invoice-${row.number}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerInvoiceDetailScreen(number: row.number))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _billedBg, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.receipt_long_outlined, color: _blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.number, style: customerType(14, FontWeight.w800, _navy)),
                  Text(row.date, style: customerType(12, FontWeight.w500, _muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_rs(row.amount), style: customerType(14, FontWeight.w800, _navy)),
                Text(row.status, style: customerType(12, FontWeight.w700, customerStatusColor(row.status))),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Color(0xFF9AADC0)),
          ],
        ),
      ),
    );
  }

  Widget _paymentRow(CustomerPaymentRow row) {
    final received = row.status.toLowerCase().contains('received') || row.status.toLowerCase() == 'paid';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: received ? _paidBg : _billedBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(received ? Icons.payments_outlined : Icons.account_balance_wallet_outlined, color: received ? const Color(0xFF16834A) : _blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.reference, style: customerType(14, FontWeight.w800, _navy)),
                Text('${row.date} · ${row.method}', style: customerType(12, FontWeight.w500, _muted)),
                if (row.relatedReference != null) Text('Invoice ${row.relatedReference}', style: customerType(12, FontWeight.w600, _blue)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_rs(row.amount), style: customerType(14, FontWeight.w800, _navy)),
              Text(row.status, style: customerType(12, FontWeight.w700, customerStatusColor(row.status))),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceEmptyArt extends StatelessWidget {
  const _InvoiceEmptyArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 18,
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                width: 58,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFB7D6F5)),
                ),
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                child: Column(
                  children: [
                    Container(height: 6, decoration: BoxDecoration(color: const Color(0xFF9CC7F0), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    for (var i = 0; i < 4; i++) ...[
                      Container(height: 4, margin: EdgeInsets.only(right: i.isOdd ? 10 : 0), decoration: BoxDecoration(color: const Color(0xFFC9DFF5), borderRadius: BorderRadius.circular(3))),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 10,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5CB6FF), Color(0xFF0875E8)]),
                boxShadow: [BoxShadow(color: Color(0x330875E8), blurRadius: 8, offset: Offset(0, 3))],
              ),
              alignment: Alignment.center,
              child: Text('Rs', style: customerType(13, FontWeight.w800, Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerInvoiceDetailScreen extends StatefulWidget {
  const CustomerInvoiceDetailScreen({required this.number, super.key});

  final String number;

  @override
  State<CustomerInvoiceDetailScreen> createState() => _CustomerInvoiceDetailScreenState();
}

class _CustomerInvoiceDetailScreenState extends State<CustomerInvoiceDetailScreen> {
  var _started = false;
  var _loading = true;
  String? _error;
  CustomerInvoiceDetail? _detail;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await ApiScope.of(context).customerInvoice(widget.number);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot reach the route server.';
        _loading = false;
      });
    }
  }

  Future<void> _pdf(String number) async {
    try {
      final file = await ApiScope.of(context).invoicePdf(number);
      await shareOfficeDocument(file);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The invoice PDF could not be created.')));
    }
  }

  String _rs(num value) => 'Rs ${customerMoney(value)}';

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      key: const Key('customer-invoice-detail'),
      backgroundColor: const Color(0xFFF2F8FE),
      appBar: AppBar(backgroundColor: const Color(0xFFF2F8FE), foregroundColor: _navy, elevation: 0, title: Text(widget.number)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(color: _blue),
          if (_error != null) Text(_error!, style: customerType(14, FontWeight.w600, const Color(0xFFDC2626))),
          if (detail != null) ...[
            CustomerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.number, style: customerType(18, FontWeight.w700, _navy)),
                  Text('Billing date ${detail.date}', style: customerType(13, FontWeight.w500, _muted)),
                  Text('Amount ${_rs(detail.amount)}', style: customerType(14, FontWeight.w600, _navy)),
                  Text('Paid ${_rs(detail.paid)} · remaining ${_rs(detail.remaining)}', style: customerType(14, FontWeight.w600, _navy)),
                  Text(detail.status, style: customerType(14, FontWeight.w700, customerStatusColor(detail.status))),
                  const SizedBox(height: 8),
                  Text(detail.pdfNote, style: customerType(13, FontWeight.w600, _muted)),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => _pdf(detail.number), child: const Text('Download PDF')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Breakdown', style: customerType(16, FontWeight.w700, _navy)),
            const SizedBox(height: 8),
            if (detail.lines.isEmpty) const CustomerCard(child: Text('No product lines are stored on this invoice.')),
            for (final line in detail.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CustomerCard(child: Text('${line.product} · ${line.quantity} × ${_rs(line.unitPrice)} = ${_rs(line.amount)}', style: customerType(14, FontWeight.w600, _navy))),
              ),
            Text('Related payments', style: customerType(16, FontWeight.w700, _navy)),
            const SizedBox(height: 8),
            if (detail.payments.isEmpty) const CustomerCard(child: Text('No payment is recorded against this invoice.')),
            for (final row in detail.payments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CustomerCard(child: Text('${row.reference} · ${row.method} · ${_rs(row.amount)} · ${row.status}', style: customerType(14, FontWeight.w600, _navy))),
              ),
          ],
        ],
      ),
    );
  }
}
