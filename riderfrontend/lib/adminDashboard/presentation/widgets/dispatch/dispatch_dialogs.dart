import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

Future<String?> showDispatchCancelDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _CancelOrderDialog(),
  );
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog();

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  final _reason = TextEditingController();
  var _empty = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _empty = true);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Cancel order',
        style: adminType(18, FontWeight.w700, AdminTokens.text),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A reason is sent with the cancellation.',
              style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('dispatch-cancel-reason'),
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
            if (_empty) ...[
              const SizedBox(height: 8),
              Text(
                'Enter a reason.',
                style: adminType(12.5, FontWeight.w600, AdminTokens.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('dispatch-cancel-confirm'),
          onPressed: _submit,
          child: const Text('Cancel order'),
        ),
      ],
    );
  }
}

class DispatchReassignDialog extends StatefulWidget {
  const DispatchReassignDialog({required this.orderId, super.key});

  final String orderId;

  @override
  State<DispatchReassignDialog> createState() => _DispatchReassignDialogState();
}

class _DispatchReassignDialogState extends State<DispatchReassignDialog> {
  var _started = false;
  var _loading = true;
  var _saving = false;
  String? _error;
  List<EligibleRider> _riders = const [];
  String? _selectedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final api = ApiScope.of(context);
    final load = await guardAdminLoad(
      () => api.dispatchEligibleRiders(orderId: widget.orderId),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (load.failed) {
        _error = load.error;
        _riders = const [];
      } else {
        _riders = load.value ?? const [];
        _error = null;
      }
    });
  }

  Future<void> _submit() async {
    final riderId = _selectedId;
    if (riderId == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ApiScope.of(context).dispatchReassignRider(
        widget.orderId,
        riderId: riderId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result.notice);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message.trim().isEmpty
            ? 'The rider could not be assigned.'
            : error.message.trim();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = adminUnreachableMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Reassign rider',
        style: adminType(18, FontWeight.w700, AdminTokens.text),
      ),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AdminTokens.primary),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  if (_riders.isEmpty && _error == null)
                    Text(
                      'No eligible riders were returned.',
                      style: adminType(
                        13.5,
                        FontWeight.w600,
                        AdminTokens.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  if (_riders.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: RadioGroup<String>(
                        groupValue: _selectedId,
                        onChanged: (value) {
                          if (_saving) return;
                          setState(() => _selectedId = value);
                        },
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final rider in _riders)
                              RadioListTile<String>(
                                key: Key('dispatch-rider-${rider.id}'),
                                value: rider.id,
                                title: Text(
                                  rider.fullName.isEmpty
                                      ? rider.riderCode
                                      : rider.fullName,
                                  style: adminType(
                                    14,
                                    FontWeight.w700,
                                    AdminTokens.text,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    rider.riderCode,
                                    rider.routeName,
                                  ].where((part) => part.isNotEmpty).join(' · '),
                                  style: adminType(
                                    12.5,
                                    FontWeight.w500,
                                    AdminTokens.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('dispatch-reassign-confirm'),
          onPressed: _selectedId == null || _saving ? null : _submit,
          child: Text(_saving ? 'Saving…' : 'Reassign rider'),
        ),
      ],
    );
  }
}

Future<String?> showDispatchAssignmentDialog(
  BuildContext context, {
  required List<DispatchOrderRow> orders,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _AssignmentDialog(orders: orders),
  );
}

class _AssignmentDialog extends StatefulWidget {
  const _AssignmentDialog({required this.orders});

  final List<DispatchOrderRow> orders;

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  var _started = false;
  var _loading = true;
  var _saving = false;
  String? _error;
  List<EligibleRider> _riders = const [];
  String? _selectedId;

  bool get _allAssigned => widget.orders.every((order) => order.hasRider);

  bool get _noneAssigned => widget.orders.every((order) => !order.hasRider);

  String? get _sharedRiderId {
    final assigned = widget.orders.where((order) => order.hasRider).toList();
    if (assigned.isEmpty || assigned.length != widget.orders.length) return null;
    final id = assigned.first.riderId.trim();
    if (id.isEmpty) return null;
    if (assigned.every((order) => order.riderId.trim() == id)) return id;
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final load = await guardAdminLoad(
      () => ApiScope.of(context).dispatchEligibleRiders(),
    );
    if (!mounted) return;
    final hidden = _sharedRiderId;
    setState(() {
      _loading = false;
      if (load.failed) {
        _error = load.error;
        _riders = const [];
      } else {
        _riders = [
          for (final rider in load.value ?? const <EligibleRider>[])
            if (rider.id != hidden) rider,
        ];
        _error = null;
      }
    });
  }

  Future<void> _submit() async {
    final riderId = _selectedId;
    if (riderId == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = ApiScope.of(context);
    final failures = <String>[];
    var assigned = 0;
    var reassigned = 0;
    var unchanged = 0;
    for (final order in widget.orders) {
      if (order.hasRider && order.riderId.trim() == riderId) {
        unchanged++;
        continue;
      }
      try {
        if (order.hasRider) {
          await api.dispatchReassignRider(order.id, riderId: riderId);
          reassigned++;
        } else {
          await api.dispatchAssignRider(order.id, riderId: riderId);
          assigned++;
        }
      } on ApiException catch (error) {
        final message = error.message.trim().isEmpty
            ? 'The rider could not be saved.'
            : error.message.trim();
        failures.add('${order.displayReference}: $message');
      } catch (_) {
        failures.add('${order.displayReference}: $adminUnreachableMessage');
      }
    }
    if (!mounted) return;
    final updated = assigned + reassigned;
    if (updated == 0) {
      setState(() {
        _saving = false;
        _error = failures.isEmpty
            ? 'Those orders are already assigned to this rider.'
            : failures.join('\n');
      });
      return;
    }
    final notice = StringBuffer();
    if (assigned > 0 && reassigned == 0) {
      notice.write(assigned == 1 ? 'Rider assigned.' : '$assigned orders assigned.');
    } else if (reassigned > 0 && assigned == 0) {
      notice.write(reassigned == 1 ? 'Rider reassigned.' : '$reassigned orders reassigned.');
    } else {
      notice.write('$updated orders updated.');
    }
    if (unchanged > 0) {
      notice.write(' $unchanged already had this rider.');
    }
    if (failures.isNotEmpty) {
      notice.write(' ${failures.join(' ')}');
    }
    Navigator.of(context).pop(notice.toString());
  }

  String get _title {
    if (_noneAssigned) return 'Assign rider';
    if (_allAssigned) return 'Reassign rider';
    return 'Assign and reassign';
  }

  String get _help {
    if (_noneAssigned) return 'Choose the rider for these deliveries.';
    if (_allAssigned) {
      return 'These orders already have a rider. Choose who should take them.';
    }
    return 'Unassigned orders will be assigned to the rider you choose. Orders that already have a rider will move to that rider.';
  }

  String get _confirmLabel {
    if (_noneAssigned) return 'Assign rider';
    if (_allAssigned) return 'Reassign rider';
    return 'Save rider';
  }

  @override
  Widget build(BuildContext context) {
    final shared = _sharedRiderId;
    return AlertDialog(
      key: const Key('dispatch-assignment-dialog'),
      title: Text(_title, style: adminType(18, FontWeight.w700, AdminTokens.text)),
      content: SizedBox(
        width: 460,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: AdminTokens.primary)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_help, style: adminType(13, FontWeight.w500, AdminTokens.textSecondary, height: 1.35)),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final order in widget.orders)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${order.displayReference} · ${order.customerName} · ${order.hasRider ? (order.riderName.trim().isEmpty ? order.riderCode : order.riderName) : 'Unassigned'}',
                              style: adminType(12.5, FontWeight.w600, AdminTokens.text),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (shared != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'The current rider is hidden so you can choose someone else.',
                      style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: adminType(13, FontWeight.w600, AdminTokens.error, height: 1.35)),
                  ],
                  if (_riders.isEmpty && _error == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      shared == null
                          ? 'No active riders were returned.'
                          : 'No other active riders were returned.',
                      style: adminType(13.5, FontWeight.w600, AdminTokens.textSecondary, height: 1.4),
                    ),
                  ],
                  if (_riders.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: RadioGroup<String>(
                        groupValue: _selectedId,
                        onChanged: (value) {
                          if (_saving) return;
                          setState(() => _selectedId = value);
                        },
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final rider in _riders)
                              RadioListTile<String>(
                                key: Key('dispatch-bulk-rider-${rider.id}'),
                                value: rider.id,
                                title: Text(
                                  rider.fullName.isEmpty ? rider.riderCode : rider.fullName,
                                  style: adminType(14, FontWeight.w700, AdminTokens.text),
                                ),
                                subtitle: Text(
                                  [rider.riderCode, rider.routeName, rider.status]
                                      .where((part) => part.trim().isNotEmpty)
                                      .join(' · '),
                                  style: adminType(12.5, FontWeight.w500, AdminTokens.textSecondary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton(
          key: const Key('dispatch-assignment-confirm'),
          onPressed: _selectedId == null || _saving ? null : _submit,
          child: Text(_saving ? 'Saving…' : _confirmLabel),
        ),
      ],
    );
  }
}
