import 'dart:io';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/rider_store.dart';
import '../core/theme.dart';
import '../widgets/aqua_widgets.dart';

class TodayEntriesScreen extends StatefulWidget {
  const TodayEntriesScreen({super.key});

  @override
  State<TodayEntriesScreen> createState() => _TodayEntriesScreenState();
}

class _TodayEntriesScreenState extends State<TodayEntriesScreen> {
  EntryFilter _filter = EntryFilter.all;

  void _addDelivery() => HomeTab.of(context).select(0);

  @override
  Widget build(BuildContext context) {
    final store = RiderScope.of(context);
    final saved = store.today;
    final visible = store.filtered(_filter);
    return ColoredBox(
      color: AquaColors.background,
      child: Column(
        children: [
          const RiderHeader(subtitle: "Today's Entries"),
          Expanded(
            child: saved.isEmpty
                ? _EmptyState(onAdd: _addDelivery)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      Text(
                        "Today's Entries",
                        style: aquaText(24, FontWeight.w800, AquaColors.navy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatEntryDate(DateTime.now()),
                        style: aquaText(
                          14,
                          FontWeight.w600,
                          AquaColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${saved.length} saved ${saved.length == 1 ? 'entry' : 'entries'}',
                        style: aquaText(
                          14,
                          FontWeight.w500,
                          AquaColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _StatsRow(
                        stops: saved.length,
                        bottles: store.todayFullBottles,
                        collected: store.todayCollected,
                      ),
                      const SizedBox(height: 8),
                      _Filters(
                        selected: _filter,
                        counts: {
                          for (final filter in EntryFilter.values)
                            filter: store.countFor(filter),
                        },
                        onSelected: (filter) =>
                            setState(() => _filter = filter),
                      ),
                      const SizedBox(height: 8),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No entries for this filter.',
                            textAlign: TextAlign.center,
                            style: aquaText(
                              14,
                              FontWeight.w600,
                              AquaColors.secondary,
                            ),
                          ),
                        )
                      else
                        for (final entry in visible) ...[
                          _EntryCard(
                            entry: entry,
                            onTap: () => _openDetail(context, entry),
                          ),
                          const SizedBox(height: 8),
                        ],
                    ],
                  ),
          ),
          if (saved.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: PrimaryButton(
                key: const Key('new-delivery'),
                label: 'New Delivery Entry',
                urduLabel: 'نئی ترسیل',
                onPressed: _addDelivery,
              ),
            ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, DeliveryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EntryDetail(entry: entry),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AquaColors.secondary,
          ),
          const SizedBox(height: 8),
          Text(
            'No Entries Yet',
            style: aquaText(22, FontWeight.w800, AquaColors.navy),
          ),
          const SizedBox(height: 6),
          Text(
            'Your saved deliveries will appear here.',
            textAlign: TextAlign.center,
            style: aquaText(15, FontWeight.w500, AquaColors.secondary),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            key: const Key('add-delivery'),
            label: 'Add Delivery',
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.stops,
    required this.bottles,
    required this.collected,
  });

  final int stops;
  final int bottles;
  final int collected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(value: '$stops', label: 'Stops'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(value: '$bottles', label: 'Bottles'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Stat(value: formatRs(collected), label: 'Received'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: aquaCard(),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: aquaText(14, FontWeight.w800, AquaColors.navy),
          ),
          Text(
            label,
            style: aquaText(11, FontWeight.w600, AquaColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final EntryFilter selected;
  final Map<EntryFilter, int> counts;
  final ValueChanged<EntryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in EntryFilter.values)
          _FilterChip(
            label: '${_name(filter)} ${counts[filter] ?? 0}',
            selected: selected == filter,
            onTap: () => onSelected(filter),
          ),
      ],
    );
  }

  String _name(EntryFilter filter) {
    return switch (filter) {
      EntryFilter.all => 'All',
      EntryFilter.cash => 'Cash',
      EntryFilter.online => 'Online',
      EntryFilter.unpaid => 'Unpaid',
    };
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final DeliveryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AquaColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.customerName,
                      style: aquaText(16, FontWeight.w800, AquaColors.navy),
                    ),
                  ),
                  Text(
                    formatEntryTime(entry.savedAt),
                    style: aquaText(12, FontWeight.w600, AquaColors.secondary),
                  ),
                ],
              ),
              Text(
                entry.area,
                style: aquaText(13, FontWeight.w500, AquaColors.secondary),
              ),
              const SizedBox(height: 8),
              Text(
                bottleSummary(entry.fullBottles, entry.emptyBottles),
                style: aquaText(14, FontWeight.w700, AquaColors.navy),
              ),
              Text(
                paymentLine(method: entry.method, amount: entry.amount),
                style: aquaText(14, FontWeight.w600, AquaColors.secondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(
                    label: entry.statusLabel,
                    tone: toneForStatus(entry.statusLabel),
                  ),
                  Text(
                    entry.synced ? kSyncedLabel : kPendingSyncLabel,
                    style: aquaText(
                      11,
                      FontWeight.w700,
                      entry.synced
                          ? AquaColors.success
                          : const Color(0xFF8A5A00),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryDetail extends StatelessWidget {
  const _EntryDetail({required this.entry});

  final DeliveryEntry entry;

  @override
  Widget build(BuildContext context) {
    final proof = entry.proofPath == null ? null : File(entry.proofPath!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AquaColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            entry.customerName,
            style: aquaText(20, FontWeight.w800, AquaColors.navy),
          ),
          Text(
            entry.area,
            style: aquaText(14, FontWeight.w500, AquaColors.secondary),
          ),
          Text(
            entry.address,
            style: aquaText(13, FontWeight.w500, AquaColors.secondary),
          ),
          Text(
            entry.phone,
            style: aquaText(13, FontWeight.w600, AquaColors.navy),
          ),
          const SizedBox(height: 8),
          Text(
            bottleSummary(entry.fullBottles, entry.emptyBottles),
            style: aquaText(16, FontWeight.w700, AquaColors.navy),
          ),
          Text(
            paymentLine(method: entry.method, amount: entry.amount),
            style: aquaText(15, FontWeight.w600, AquaColors.navy),
          ),
          if (entry.provider != null)
            Text(
              entry.provider!.label,
              style: aquaText(14, FontWeight.w600, AquaColors.secondary),
            ),
          if (entry.reference != null)
            Text(
              'Ref ${entry.reference}',
              style: aquaText(13, FontWeight.w600, AquaColors.secondary),
            ),
          if (entry.unpaidPortion > 0)
            Text(
              'Outstanding ${formatRs(entry.unpaidPortion)}',
              style: aquaText(14, FontWeight.w700, AquaColors.error),
            ),
          const SizedBox(height: 8),
          StatusBadge(
            label: entry.statusLabel,
            tone: toneForStatus(entry.statusLabel),
          ),
          const SizedBox(height: 8),
          SyncLabel(synced: entry.synced),
          if (proof != null && proof.existsSync()) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                proof,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Close',
            icon: Icons.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
