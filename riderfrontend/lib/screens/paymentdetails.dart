import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/format.dart';
import '../core/rider_store.dart';
import '../core/theme.dart';
import '../widgets/aqua_widgets.dart';
import 'reviewconfirmation.dart';

class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  var _ready = false;
  var _amountError = false;
  var _picking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final draft = RiderScope.of(context).draft;
    _amount.text = draft.amount == null ? '' : '${draft.amount}';
    _reference.text = draft.reference;
    _ready = true;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _setChip(RiderStore store, int value) {
    store.setAmount(value, touched: true);
    _amount.text = '$value';
    setState(() => _amountError = false);
  }

  Future<void> _pickProof(RiderStore store) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final dest = File(
        '${directory.path}${Platform.pathSeparator}proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(picked.path).copy(dest.path);
      if (!mounted) return;
      store.setProof(dest.path);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the gallery on this phone.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _review(RiderStore store) {
    if (!store.draft.amountValid) {
      setState(() => _amountError = true);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ReviewSaveConfirmationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = RiderScope.of(context);
    final draft = store.draft;
    final customer = draft.customer;
    return Scaffold(
      backgroundColor: AquaColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(
              title: 'Payment Details',
              step: 'STEP 2 OF 3',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (customer != null)
                    _SummaryCard(
                      name: customer.name,
                      area: customer.area,
                      full: draft.fullBottles,
                      empty: draft.emptyBottles,
                      bill: draft.bill,
                    ),
                  const SizedBox(height: 12),
                  const SectionLabel(
                    title: 'Payment Method',
                    urdu: 'ادائیگی کا طریقہ',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _MethodTile(
                          tileKey: const Key('pay-cash'),
                          icon: Icons.payments_outlined,
                          title: PaymentMethod.cash.title,
                          urdu: PaymentMethod.cash.urdu,
                          selected: draft.method == PaymentMethod.cash,
                          onTap: () => store.setMethod(PaymentMethod.cash),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MethodTile(
                          tileKey: const Key('pay-online'),
                          icon: Icons.smartphone_outlined,
                          title: PaymentMethod.online.title,
                          urdu: PaymentMethod.online.urdu,
                          selected: draft.method == PaymentMethod.online,
                          onTap: () => store.setMethod(PaymentMethod.online),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _UnpaidTile(
                    selected: draft.method == PaymentMethod.unpaid,
                    onTap: () => store.setMethod(PaymentMethod.unpaid),
                  ),
                  const SizedBox(height: 12),
                  if (draft.method == PaymentMethod.unpaid)
                    _UnpaidNotice(
                      balance: customer?.balance ?? 0,
                      bill: draft.bill,
                    )
                  else ...[
                    _AmountField(
                      controller: _amount,
                      invalid: _amountError,
                      onChanged: (value) {
                        store.setAmount(int.tryParse(value), touched: true);
                        if (_amountError) setState(() => _amountError = false);
                      },
                    ),
                    if (_amountError) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Enter the amount received.',
                        style: aquaText(13, FontWeight.w600, AquaColors.error),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _AmountChips(
                      bill: draft.bill,
                      selected: draft.amount,
                      onSelected: (value) => _setChip(store, value),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _amountHint(draft.amount, draft.bill),
                      style: aquaText(
                        13,
                        FontWeight.w600,
                        AquaColors.secondary,
                      ),
                    ),
                    if (draft.method == PaymentMethod.online) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Payment provider',
                        style: aquaText(14, FontWeight.w700, AquaColors.navy),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final provider in PaymentProvider.values)
                            _ProviderChip(
                              label: provider.label,
                              selected: draft.provider == provider,
                              onTap: () => store.setProvider(provider),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ProofPicker(
                        path: draft.proofPath,
                        picking: _picking,
                        onPick: () => _pickProof(store),
                        onClear: () => store.setProof(null),
                      ),
                      if (draft.awaitingVerification) ...[
                        const SizedBox(height: 8),
                        const StatusBadge(
                          label: 'Awaiting Verification',
                          tone: StatusTone.warning,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A screenshot does not confirm the transfer. The office still has to verify it.',
                          style: aquaText(
                            13,
                            FontWeight.w500,
                            AquaColors.secondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('reference-field'),
                        controller: _reference,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: store.setReference,
                        decoration: InputDecoration(
                          labelText: 'Transaction reference (optional)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AquaColors.border,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: [
                  PrimaryButton(
                    key: const Key('review-entry'),
                    label: 'Review Entry',
                    urduLabel: 'اندراج دیکھیں',
                    onPressed: () => _review(store),
                  ),
                  SecondaryButton(
                    label: 'Back',
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _amountHint(int? amount, int bill) {
    final received = amount ?? 0;
    if (amount == null) return 'Delivery total ${formatRs(bill)}';
    if (received > bill) return 'Change to return ${formatRs(received - bill)}';
    if (received < bill) {
      return '${formatRs(bill - received)} will remain outstanding.';
    }
    return 'Amount matches this delivery.';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.name,
    required this.area,
    required this.full,
    required this.empty,
    required this.bill,
  });

  final String name;
  final String area;
  final int full;
  final int empty;
  final int bill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: aquaCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: aquaText(18, FontWeight.w800, AquaColors.navy)),
          Text(
            area,
            style: aquaText(13, FontWeight.w500, AquaColors.secondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  bottleSummary(full, empty),
                  style: aquaText(14, FontWeight.w700, AquaColors.navy),
                ),
              ),
              Text(
                formatRs(bill),
                style: aquaText(18, FontWeight.w800, AquaColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.urdu,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String urdu;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AquaColors.tint : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: tileKey,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AquaColors.primary : AquaColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? AquaColors.primary : AquaColors.secondary,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: aquaText(
                  13,
                  FontWeight.w800,
                  AquaColors.navy,
                  height: 1.1,
                ),
              ),
              Text(
                urdu,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: urduText(11, AquaColors.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnpaidTile extends StatelessWidget {
  const _UnpaidTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AquaColors.errorTint : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('pay-unpaid'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AquaColors.error : AquaColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                color: selected ? AquaColors.error : AquaColors.secondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Not Received',
                      style: aquaText(14, FontWeight.w700, AquaColors.navy),
                    ),
                    Text(
                      'ادائیگی نہیں ہوئی',
                      style: urduText(12, AquaColors.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnpaidNotice extends StatelessWidget {
  const _UnpaidNotice({required this.balance, required this.bill});

  final int balance;
  final int bill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AquaColors.errorTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AquaColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment will remain outstanding.',
            style: aquaText(15, FontWeight.w800, AquaColors.error),
          ),
          const SizedBox(height: 6),
          Text(
            'This delivery is not marked paid.',
            style: aquaText(13, FontWeight.w500, AquaColors.navy),
          ),
          const SizedBox(height: 8),
          Text(
            'Existing balance ${formatRs(balance)}',
            style: aquaText(13, FontWeight.w600, AquaColors.secondary),
          ),
          Text(
            'This delivery ${formatRs(bill)}',
            style: aquaText(13, FontWeight.w600, AquaColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.invalid,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool invalid;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount Received',
          style: aquaText(14, FontWeight.w700, AquaColors.navy),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('amount-field'),
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          style: aquaText(28, FontWeight.w800, AquaColors.navy),
          decoration: InputDecoration(
            prefixText: 'Rs. ',
            prefixStyle: aquaText(20, FontWeight.w700, AquaColors.secondary),
            filled: true,
            fillColor: invalid ? AquaColors.errorTint : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: invalid ? AquaColors.error : AquaColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: invalid ? AquaColors.error : AquaColors.border,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountChips extends StatelessWidget {
  const _AmountChips({
    required this.bill,
    required this.selected,
    required this.onSelected,
  });

  final int bill;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final amounts = <int>{150, 300, 1500, if (bill > 0) bill}.toList()..sort();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final amount in amounts)
          _ProviderChip(
            label: formatRs(amount),
            selected: selected == amount,
            onTap: () => onSelected(amount),
          ),
      ],
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AquaColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AquaColors.primary : AquaColors.border,
            ),
          ),
          child: Text(
            label,
            style: aquaText(
              13,
              FontWeight.w700,
              selected ? Colors.white : AquaColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProofPicker extends StatelessWidget {
  const _ProofPicker({
    required this.path,
    required this.picking,
    required this.onPick,
    required this.onClear,
  });

  final String? path;
  final bool picking;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final file = path == null ? null : File(path!);
    final hasFile = file != null && file.existsSync();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: const Key('upload-proof'),
          onPressed: picking ? null : onPick,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: AquaColors.primary,
            side: const BorderSide(color: AquaColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: picking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_outlined),
          label: Text(
            path == null ? 'Upload Payment Screenshot' : 'Replace Screenshot',
            style: aquaText(14, FontWeight.w700, AquaColors.primary),
          ),
        ),
        if (path != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: hasFile
                    ? Image.file(file, width: 64, height: 64, fit: BoxFit.cover)
                    : Container(
                        width: 64,
                        height: 64,
                        color: AquaColors.tint,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AquaColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  path!.split(Platform.pathSeparator).last,
                  style: aquaText(13, FontWeight.w600, AquaColors.navy),
                ),
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, color: AquaColors.secondary),
                tooltip: 'Remove screenshot',
              ),
            ],
          ),
        ],
      ],
    );
  }
}
