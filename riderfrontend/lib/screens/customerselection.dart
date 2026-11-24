import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/rider_store.dart';
import '../core/theme.dart';
import '../widgets/aqua_widgets.dart';
import 'paymentdetails.dart';

class CustomerSelectionScreen extends StatefulWidget {
  const CustomerSelectionScreen({super.key});

  @override
  State<CustomerSelectionScreen> createState() =>
      _CustomerSelectionScreenState();
}

class _CustomerSelectionScreenState extends State<CustomerSelectionScreen> {
  var _customerError = false;
  var _qtyError = false;

  Future<void> _pickCustomer(RiderStore store) async {
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          _CustomerSheet(selectedId: store.draft.customer?.id),
    );
    if (selected == null) return;
    store.selectCustomer(selected);
    if (!mounted) return;
    setState(() => _customerError = false);
  }

  Future<void> _call(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    final uri = Uri(scheme: 'tel', path: '+92$local');
    try {
      final opened = await launchUrl(uri);
      if (!opened && mounted) {
        _toast('Call $phone');
      }
    } on Object {
      if (mounted) _toast('Call $phone');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _continue(RiderStore store) {
    final missingCustomer = store.draft.customer == null;
    final missingQty = !store.draft.hasQuantity;
    setState(() {
      _customerError = missingCustomer;
      _qtyError = missingQty;
    });
    if (missingCustomer || missingQty) return;
    store.ensureAmountDefault();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PaymentDetailsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = RiderScope.of(context);
    final draft = store.draft;
    final customer = draft.customer;
    return ColoredBox(
      color: AquaColors.background,
      child: Column(
        children: [
          const RiderHeader(subtitle: 'Entry'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                _Greeting(
                  name: store.rider.fullName,
                  saved: store.today.length,
                ),
                const SizedBox(height: 12),
                const SectionLabel(
                  title: 'Select Customer',
                  urdu: 'گاہک منتخب کریں',
                ),
                const SizedBox(height: 8),
                _CustomerPicker(
                  loading: store.customersLoading,
                  label: customer?.name,
                  invalid: _customerError,
                  onTap: () => _pickCustomer(store),
                ),
                if (customer != null) ...[
                  const SizedBox(height: 8),
                  _CustomerCard(
                    customer: customer,
                    onCall: () => _call(customer.phone),
                  ),
                ],
                const SizedBox(height: 14),
                const SectionLabel(
                  title: 'Bottle Details',
                  urdu: 'بوتلوں کی تعداد',
                  trailing: '19L',
                ),
                const SizedBox(height: 8),
                _QtyCard(
                  icon: Icons.water_drop_outlined,
                  title: 'Full Bottles Delivered',
                  urdu: 'بھری بوتلیں دی گئیں',
                  badge: '${formatRs(kBottlePrice)} / ea',
                  caption: 'Delivered',
                  value: draft.fullBottles,
                  plusKey: const Key('full-plus'),
                  minusKey: const Key('full-minus'),
                  onMinus: draft.fullBottles > 0
                      ? () {
                          store.setFull(draft.fullBottles - 1);
                          setState(() => _qtyError = false);
                        }
                      : null,
                  onPlus: () {
                    store.setFull(draft.fullBottles + 1);
                    setState(() => _qtyError = false);
                  },
                ),
                const SizedBox(height: 8),
                _QtyCard(
                  icon: Icons.recycling_outlined,
                  title: 'Empty Bottles Collected',
                  urdu: 'خالی بوتلیں وصول ہوئیں',
                  badge: 'Empties',
                  caption: 'Collected',
                  value: draft.emptyBottles,
                  accent: AquaColors.secondary,
                  plusKey: const Key('empty-plus'),
                  minusKey: const Key('empty-minus'),
                  onMinus: draft.emptyBottles > 0
                      ? () {
                          store.setEmpty(draft.emptyBottles - 1);
                          setState(() => _qtyError = false);
                        }
                      : null,
                  onPlus: () {
                    store.setEmpty(draft.emptyBottles + 1);
                    setState(() => _qtyError = false);
                  },
                ),
                const SizedBox(height: 8),
                _TotalBar(total: draft.bill, full: draft.fullBottles),
              ],
            ),
          ),
          if (_customerError || _qtyError)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_customerError)
                    const _ValidationNote(
                      message: 'Select a customer before continuing.',
                    ),
                  if (_qtyError)
                    const _ValidationNote(
                      message:
                          'Enter at least one full bottle or one empty bottle.',
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: PrimaryButton(
              key: const Key('continue-payment'),
              label: 'Continue to Payment',
              urduLabel: 'ادائیگی کی طرف جائیں',
              icon: Icons.arrow_forward,
              onPressed: () => _continue(store),
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.saved});

  final String name;
  final int saved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AquaColors.tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: AquaColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: aquaText(18, FontWeight.w800, AquaColors.navy),
                ),
                Text(
                  "Today's Deliveries",
                  style: aquaText(12, FontWeight.w600, AquaColors.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$saved saved',
            style: aquaText(12, FontWeight.w700, AquaColors.primary),
          ),
        ],
      ),
    );
  }
}

class _CustomerPicker extends StatelessWidget {
  const _CustomerPicker({
    required this.loading,
    required this.label,
    required this.invalid,
    required this.onTap,
  });

  final bool loading;
  final String? label;
  final bool invalid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = loading
        ? 'Loading customers...'
        : (label ?? 'Search customer name or phone');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('customer-picker'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: invalid ? AquaColors.error : AquaColors.border,
              width: invalid ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                loading ? Icons.hourglass_top : Icons.search,
                color: AquaColors.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: aquaText(
                    15,
                    FontWeight.w600,
                    label == null ? AquaColors.secondary : AquaColors.navy,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down,
                color: AquaColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidationNote extends StatelessWidget {
  const _ValidationNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: aquaText(13, FontWeight.w600, AquaColors.error),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onCall});

  final Customer customer;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: aquaCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customer.name,
            style: aquaText(18, FontWeight.w800, AquaColors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            customer.address,
            style: aquaText(14, FontWeight.w500, AquaColors.secondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AquaColors.tint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Balance',
                        style: aquaText(
                          11,
                          FontWeight.w600,
                          AquaColors.secondary,
                        ),
                      ),
                      Text(
                        customer.balance == 0
                            ? 'Rs. 0 (Nil)'
                            : formatRs(customer.balance),
                        style: aquaText(14, FontWeight.w800, AquaColors.navy),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onCall,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AquaColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.total, required this.full});

  final int total;
  final int full;

  @override
  Widget build(BuildContext context) {
    final bottleLabel = full == 1 ? '1 full bottle' : '$full full bottles';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AquaColors.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.payments_outlined,
            color: AquaColors.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Total ${formatRs(total)}  ($bottleLabel)',
              style: aquaText(14, FontWeight.w700, AquaColors.navy),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyCard extends StatelessWidget {
  const _QtyCard({
    required this.icon,
    required this.title,
    required this.urdu,
    required this.badge,
    required this.caption,
    required this.value,
    required this.plusKey,
    required this.minusKey,
    required this.onPlus,
    required this.onMinus,
    this.accent = AquaColors.primary,
  });

  final IconData icon;
  final String title;
  final String urdu;
  final String badge;
  final String caption;
  final int value;
  final Key plusKey;
  final Key minusKey;
  final VoidCallback onPlus;
  final VoidCallback? onMinus;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: aquaCard(),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AquaColors.tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AquaColors.primary, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  style: aquaText(14, FontWeight.w800, AquaColors.navy),
                ),
                Text(urdu, style: urduText(11, AquaColors.secondary)),
                Text(
                  '$caption · $badge',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: aquaText(11, FontWeight.w600, AquaColors.secondary),
                ),
              ],
            ),
          ),
          _StepButton(
            buttonKey: minusKey,
            icon: Icons.remove,
            background: AquaColors.tint,
            foreground: onMinus == null
                ? const Color(0xFFA7B6C9)
                : AquaColors.primary,
            onTap: onMinus,
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: aquaText(28, FontWeight.w800, AquaColors.navy, height: 1),
            ),
          ),
          _StepButton(
            buttonKey: plusKey,
            icon: Icons.add,
            background: accent,
            foreground: Colors.white,
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.buttonKey,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: foreground, size: 24),
        ),
      ),
    );
  }
}

class _CustomerSheet extends StatefulWidget {
  const _CustomerSheet({required this.selectedId});

  final String? selectedId;

  @override
  State<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends State<_CustomerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = RiderScope.of(context);
    final query = _query.trim().toLowerCase();
    final results = store.customers.where((customer) {
      if (query.isEmpty) return true;
      return customer.name.toLowerCase().contains(query) ||
          customer.area.toLowerCase().contains(query) ||
          customer.phone.contains(query);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AquaColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const Key('customer-search'),
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search customer name or phone',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AquaColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _sheetBody(results, store.customersLoading)),
          ],
        ),
      ),
    );
  }

  Widget _sheetBody(List<Customer> results, bool loading) {
    if (loading) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AquaColors.primary),
          const SizedBox(height: 8),
          Text(
            'Loading customers...',
            style: aquaText(14, FontWeight.w600, AquaColors.secondary),
          ),
        ],
      );
    }
    if (results.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 36, color: AquaColors.secondary),
          const SizedBox(height: 8),
          Text(
            'Customer not found',
            style: aquaText(16, FontWeight.w800, AquaColors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            'Try another name, area, or phone number.',
            style: aquaText(14, FontWeight.w500, AquaColors.secondary),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final customer = results[index];
        final selected = customer.id == widget.selectedId;
        return Material(
          color: selected ? AquaColors.tint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context, customer),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AquaColors.primary : AquaColors.border,
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AquaColors.tint,
                    child: Icon(
                      Icons.person_outline,
                      color: AquaColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: aquaText(15, FontWeight.w700, AquaColors.navy),
                        ),
                        Text(
                          customer.area,
                          style: aquaText(
                            13,
                            FontWeight.w500,
                            AquaColors.secondary,
                          ),
                        ),
                        if (customer.balance > 0)
                          Text(
                            'Due ${formatRs(customer.balance)}',
                            style: aquaText(
                              12,
                              FontWeight.w700,
                              AquaColors.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (customer.scheduledToday)
                    const StatusBadge(label: 'Today', tone: StatusTone.info),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
