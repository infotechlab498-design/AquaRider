import 'package:flutter/material.dart';

import '../../../data/admin_format.dart';

import 'package:riderfrontend/adminDashboard/data/dashboard_models.dart';

import '../../../theme/admin_tokens.dart';
import '../admin_shell.dart';

class ActivityLedgerTable extends StatelessWidget {
  const ActivityLedgerTable({
    required this.page,
    required this.search,
    required this.status,
    required this.onStatus,
    required this.onPrevious,
    required this.onNext,
    this.loading = false,
    super.key,
  });

  final ActivityLedgerPage? page;
  final TextEditingController search;
  final String status;
  final ValueChanged<String> onStatus;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final rows = page?.rows ?? const <ActivityLedgerRow>[];
    final current = page?.page ?? 1;
    final pages = page?.totalPages;
    final total = page?.totalRecords;
    return AdminSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Activity ledger',
                style: adminType(
                  16,
                  FontWeight.w700,
                  AdminTokens.text,
                  height: 1.2,
                ),
              ),
              SizedBox(
                width: 240,
                height: 40,
                child: TextField(
                  key: const Key('ledger-search'),
                  controller: search,
                  style: adminType(
                    13,
                    FontWeight.w500,
                    AdminTokens.text,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Search the ledger',
                    hintStyle: adminType(
                      13,
                      FontWeight.w400,
                      AdminTokens.border,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AdminTokens.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AdminTokens.line),
                    ),
                  ),
                ),
              ),
              DropdownButton<String>(
                key: const Key('ledger-status'),
                value: status,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All statuses')),
                  DropdownMenuItem(value: 'Synced', child: Text('Synced')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Failed', child: Text('Failed')),
                ],
                onChanged: (value) {
                  if (value != null) onStatus(value);
                },
              ),
              if (total != null)
                Text(
                  '$total records',
                  style: adminType(
                    12.5,
                    FontWeight.w600,
                    AdminTokens.textSecondary,
                  ),
                ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(
              minHeight: 2,
              color: AdminTokens.primary,
            ),
          ],
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              'No activity was returned for this period.',
              style: adminType(
                13.5,
                FontWeight.w600,
                AdminTokens.textSecondary,
                height: 1.4,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [
                      for (final row in rows) ...[
                        _LedgerCard(row: row),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                }
                return Column(
                  children: [
                    const _LedgerHeader(),
                    const Divider(height: 16, color: AdminTokens.line),
                    for (final row in rows) _LedgerLine(row: row),
                  ],
                );
              },
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                pages == null ? 'Page $current' : 'Page $current of $pages',
                style: adminType(
                  12.5,
                  FontWeight.w600,
                  AdminTokens.textSecondary,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: onPrevious,
                style: adminOutlineButton(),
                child: const Text('Previous'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onNext,
                style: adminOutlineButton(),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerHeader extends StatelessWidget {
  const _LedgerHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _cell('Reference', 120, header: true),
        _flex('Customer', header: true),
        _flex('Rider', header: true),
        _flex('Type', header: true),
        _cell('Amount', 110, header: true),
        _cell('When', 130, header: true),
        _cell('Sync', 80, header: true),
      ],
    );
  }
}

class _LedgerLine extends StatelessWidget {
  const _LedgerLine({required this.row});

  final ActivityLedgerRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _cell(row.reference.isEmpty ? '—' : row.reference, 120),
          _flex(row.customer.isEmpty ? '—' : row.customer),
          _flex(row.rider.isEmpty ? '—' : row.rider),
          _flex(row.transactionType.isEmpty ? '—' : row.transactionType),
          _cell(row.amount == null ? '—' : formatPkr(row.amount!), 110),
          _cell(
            row.occurredAt == null ? '—' : formatAdminStamp(row.occurredAt!),
            130,
          ),
          _cell(row.syncStatus ?? '—', 80),
        ],
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.row});

  final ActivityLedgerRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AdminTokens.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.reference.isEmpty ? 'No reference' : row.reference,
            style: adminType(13, FontWeight.w700, AdminTokens.text),
          ),
          Text(
            row.customer.isEmpty ? 'Customer not reported' : row.customer,
            style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
          ),
          Text(
            '${row.transactionType.isEmpty ? 'Type not reported' : row.transactionType} · ${row.amount == null ? 'Amount not reported' : formatPkr(row.amount!)}',
            style: adminType(12.5, FontWeight.w600, AdminTokens.text),
          ),
          Text(
            row.syncStatus ?? 'Sync status not reported',
            style: adminType(12, FontWeight.w600, AdminTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

Widget _cell(String text, double width, {bool header = false}) {
  return SizedBox(
    width: width,
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: adminType(
        header ? 11 : 12.5,
        header ? FontWeight.w700 : FontWeight.w600,
        header ? AdminTokens.textSecondary : AdminTokens.text,
        height: 1.25,
      ),
    ),
  );
}

Widget _flex(String text, {bool header = false}) {
  return Expanded(
    child: Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: adminType(
        header ? 11 : 12.5,
        header ? FontWeight.w700 : FontWeight.w600,
        header ? AdminTokens.textSecondary : AdminTokens.text,
        height: 1.25,
      ),
    ),
  );
}