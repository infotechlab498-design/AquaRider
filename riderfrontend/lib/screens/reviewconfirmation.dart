import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/rider_store.dart';
import '../core/theme.dart';
import '../widgets/aqua_widgets.dart';
import 'session_nav.dart';

class ReviewSaveConfirmationScreen extends StatefulWidget {
  const ReviewSaveConfirmationScreen({super.key});

  @override
  State<ReviewSaveConfirmationScreen> createState() =>
      _ReviewSaveConfirmationScreenState();
}

class _ReviewSaveConfirmationScreenState
    extends State<ReviewSaveConfirmationScreen> {
  var _failed = false;

  Future<void> _save() async {
    final store = RiderScope.of(context);
    if (store.saving) return;
    setState(() => _failed = false);
    try {
      final entry = await store.saveDraft();
      if (!mounted || entry == null) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => EntrySavedScreen(entry: entry)),
        (route) => route.isFirst,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = RiderScope.of(context);
    final draft = store.draft;
    final customer = draft.customer;
    return Scaffold(
      backgroundColor: AquaColors.background,
      body: SafeArea(
        child: Column(
          children: [
            FlowHeader(
              title: 'Review & Confirm',
              step: 'STEP 3 OF 3',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    'Review & Confirm Entry',
                    style: aquaText(22, FontWeight.w800, AquaColors.navy),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check the details before saving.',
                    style: aquaText(15, FontWeight.w500, AquaColors.secondary),
                  ),
                  const SizedBox(height: 12),
                  if (customer != null) _CustomerBlock(customer: customer),
                  const SizedBox(height: 8),
                  _BottleBlock(
                    full: draft.fullBottles,
                    empty: draft.emptyBottles,
                  ),
                  const SizedBox(height: 8),
                  _PaymentBlock(draft: draft),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AquaColors.warningTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SyncLabel(synced: false),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Could not save on this phone. Try again.',
                      style: aquaText(13, FontWeight.w600, AquaColors.error),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: [
                  PrimaryButton(
                    key: const Key('save-entry'),
                    label: 'Save Entry',
                    urduLabel: 'اندراج محفوظ کریں',
                    loading: store.saving,
                    onPressed: _save,
                  ),
                  SecondaryButton(
                    key: const Key('edit-details'),
                    label: 'Edit Details',
                    onPressed: () {
                      popToRiderHome(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EntrySavedScreen extends StatelessWidget {
  const EntrySavedScreen({required this.entry, super.key});

  final DeliveryEntry entry;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        popToRiderHome(context);
      },
      child: Scaffold(
        backgroundColor: AquaColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    color: AquaColors.successTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: AquaColors.success,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Entry Saved Successfully',
                  textAlign: TextAlign.center,
                  style: aquaText(22, FontWeight.w800, AquaColors.navy),
                ),
                const SizedBox(height: 6),
                Text(
                  'اندراج محفوظ ہوگیا',
                  style: urduText(16, AquaColors.secondary),
                ),
                const SizedBox(height: 12),
                Text(
                  entry.customerName,
                  style: aquaText(16, FontWeight.w700, AquaColors.navy),
                ),
                Text(
                  bottleSummary(entry.fullBottles, entry.emptyBottles),
                  style: aquaText(14, FontWeight.w500, AquaColors.secondary),
                ),
                const SizedBox(height: 4),
                Text(
                  paymentLine(method: entry.method, amount: entry.amount),
                  style: aquaText(14, FontWeight.w600, AquaColors.navy),
                ),
                const SizedBox(height: 12),
                SyncLabel(synced: entry.synced),
                const Spacer(),
                PrimaryButton(
                  key: const Key('add-next'),
                  label: 'Add Next Customer',
                  urduLabel: 'اگلا گاہک شامل کریں',
                  onPressed: () {
                    popToRiderHome(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerBlock extends StatelessWidget {
  const _CustomerBlock({required this.customer});

  final Customer customer;

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
            'Customer',
            style: aquaText(12, FontWeight.w700, AquaColors.secondary),
          ),
          const SizedBox(height: 4),
          Text(
            customer.name,
            style: aquaText(18, FontWeight.w800, AquaColors.navy),
          ),
          Text(
            customer.area,
            style: aquaText(14, FontWeight.w500, AquaColors.secondary),
          ),
          Text(
            customer.phone,
            style: aquaText(13, FontWeight.w500, AquaColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _BottleBlock extends StatelessWidget {
  const _BottleBlock({required this.full, required this.empty});

  final int full;
  final int empty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: aquaCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bottle Details',
            style: aquaText(12, FontWeight.w700, AquaColors.secondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Count(label: 'Full delivered', value: full),
              ),
              Expanded(
                child: _Count(label: 'Empties collected', value: empty),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: aquaText(28, FontWeight.w800, AquaColors.navy, height: 1),
        ),
        const SizedBox(height: 4),
        Text(label, style: aquaText(12, FontWeight.w600, AquaColors.secondary)),
      ],
    );
  }
}

class _PaymentBlock extends StatelessWidget {
  const _PaymentBlock({required this.draft});

  final DeliveryDraft draft;

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
            'Payment',
            style: aquaText(12, FontWeight.w700, AquaColors.secondary),
          ),
          const SizedBox(height: 8),
          Text(
            draft.method.title,
            style: aquaText(16, FontWeight.w800, AquaColors.navy),
          ),
          Text(draft.method.urdu, style: urduText(13, AquaColors.secondary)),
          const SizedBox(height: 8),
          if (draft.method != PaymentMethod.unpaid)
            Text(
              'Amount received ${formatRs(draft.settledAmount)}',
              style: aquaText(15, FontWeight.w700, AquaColors.navy),
            ),
          if (draft.method == PaymentMethod.online) ...[
            const SizedBox(height: 4),
            Text(
              draft.provider.label,
              style: aquaText(14, FontWeight.w600, AquaColors.secondary),
            ),
          ],
          if (draft.reference.trim().isNotEmpty &&
              draft.method == PaymentMethod.online) ...[
            const SizedBox(height: 4),
            Text(
              'Ref ${draft.reference.trim()}',
              style: aquaText(13, FontWeight.w600, AquaColors.secondary),
            ),
          ],
          if (draft.unpaidPortion > 0) ...[
            const SizedBox(height: 8),
            Text(
              draft.method == PaymentMethod.unpaid
                  ? 'Payment will remain outstanding.'
                  : '${formatRs(draft.unpaidPortion)} will remain outstanding.',
              style: aquaText(14, FontWeight.w700, AquaColors.error),
            ),
          ],
          if (draft.awaitingVerification) ...[
            const SizedBox(height: 8),
            const StatusBadge(
              label: 'Awaiting Verification',
              tone: StatusTone.warning,
            ),
          ],
          if ((draft.customer?.balance ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Existing balance ${formatRs(draft.customer!.balance)}',
              style: aquaText(13, FontWeight.w600, AquaColors.secondary),
            ),
          ],
        ],
      ),
    );
  }
}
