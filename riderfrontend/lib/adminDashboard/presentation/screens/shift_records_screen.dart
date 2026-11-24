import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/data/admin_shift_models.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class ShiftRecordsScreen extends StatefulWidget {
  const ShiftRecordsScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<ShiftRecordsScreen> createState() => _ShiftRecordsScreenState();
}

class _ShiftRecordsScreenState extends State<ShiftRecordsScreen> {
  final _search = TextEditingController();
  var _started = false;
  var _loading = true;
  DateTime _date = _today();
  String? _riderId;
  AdminLoad<ShiftDayRecord>? _day;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _dateIso =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

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
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final api = ApiScope.of(context);
    final day = await guardAdminLoad(
      () => api.adminShiftDay(date: _dateIso, riderId: _riderId),
    );
    if (!mounted) return;
    final record = day.value;
    if (record != null &&
        _riderId == null &&
        record.selected != null &&
        record.selected!.riderId.isNotEmpty) {
      _riderId = record.selected!.riderId;
    }
    setState(() {
      _day = day;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    final record = day?.value;
    final query = _search.text.trim().toLowerCase();
    final riders = [
      for (final rider in record?.riders ?? const <ShiftRiderDay>[])
        if (query.isEmpty ||
            rider.riderName.toLowerCase().contains(query) ||
            rider.riderCode.toLowerCase().contains(query))
          rider,
    ];
    final selected = record?.selected;
    return AdminShell(
      screenKey: const Key('shift-records-screen'),
      session: widget.session,
      activeKey: AdminNav.shiftRecords,
      serverReachable: adminServerReachable([?day]),
      search: _search,
      onSearch: (_) => setState(() {}),
      searchHint: 'Search rider name or code',
      onNavigate: widget.onNavigate,
      trailing: IconButton(
        tooltip: 'Refresh',
        onPressed: _loading ? null : _reload,
        icon: const Icon(Icons.refresh, color: AdminTokens.secondary),
      ),
      body: _loading && record == null
          ? const AdminLoadingPane(label: 'Loading shift records…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(
                  'Shift Records',
                  style: adminType(26, FontWeight.w700, AdminTokens.text, height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  'The bottles a rider loaded, the bottles assigned for delivery, and the odometer saved when the shift started or ended.',
                  style: adminType(13.5, FontWeight.w500, AdminTokens.textSecondary),
                ),
                const SizedBox(height: 16),
                if (day?.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      day!.error!,
                      style: adminType(13, FontWeight.w600, AdminTokens.error),
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('shift-date'),
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(_longDate(_date)),
                    ),
                    if (riders.isNotEmpty)
                      SizedBox(
                        width: 280,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('shift-rider-$_riderId'),
                          initialValue: riders.any((rider) => rider.riderId == _riderId)
                              ? _riderId
                              : riders.first.riderId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Rider',
                            isDense: true,
                          ),
                          items: [
                            for (final rider in riders)
                              DropdownMenuItem(
                                value: rider.riderId,
                                child: Text(
                                  rider.riderCode.isEmpty
                                      ? rider.riderName
                                      : '${rider.riderName} · ${rider.riderCode}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null || value == _riderId) return;
                            setState(() => _riderId = value);
                            _reload();
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (record == null || riders.isEmpty)
                  _card(
                    child: Text(
                      record == null
                          ? 'Shift records were not loaded.'
                          : 'No riders were returned for this date.',
                      style: adminType(14, FontWeight.w600, AdminTokens.text),
                    ),
                  )
                else if (selected == null)
                  _card(
                    child: Text(
                      'This rider has no shift record for the selected date.',
                      style: adminType(14, FontWeight.w600, AdminTokens.text),
                    ),
                  )
                else ...[
                  _summary(selected),
                  const SizedBox(height: 12),
                  _loaded(selected),
                  const SizedBox(height: 12),
                  _deliver(selected),
                  const SizedBox(height: 12),
                  _photos(selected),
                  const SizedBox(height: 12),
                  _odometer(record.odometer, selected.riderName),
                ],
              ],
            ),
    );
  }

  Widget _summary(ShiftRiderDay rider) {
    final van = [
      if (rider.vehicleName.isNotEmpty) rider.vehicleName,
      if (rider.plate.isNotEmpty) rider.plate,
      if (rider.fleetCode.isNotEmpty) rider.fleetCode,
    ].join(' · ');
    final place = [
      if (rider.routeName.isNotEmpty) rider.routeName,
      if (rider.depotName.isNotEmpty) rider.depotName,
    ].join(' · ');
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rider.riderName.isEmpty ? 'Rider' : rider.riderName,
                  style: adminType(18, FontWeight.w700, AdminTokens.text),
                ),
              ),
              _statusChip(rider),
            ],
          ),
          if (rider.riderCode.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(rider.riderCode, style: adminType(13, FontWeight.w600, AdminTokens.textSecondary)),
          ],
          const SizedBox(height: 8),
          Text(
            van.isEmpty ? 'No vehicle is assigned.' : van,
            style: adminType(14, FontWeight.w600, AdminTokens.text),
          ),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(place, style: adminType(13, FontWeight.w500, AdminTokens.textSecondary)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _metric('Route date', _longDate(_date)),
              _metric('Started', _clock(rider.startedAt)),
              _metric('Ended', _clock(rider.endedAt)),
              _metric('Opening km', rider.openingOdometer?.toString() ?? '—'),
              _metric('Closing km', rider.closingOdometer?.toString() ?? '—'),
              _metric(
                'Distance',
                rider.openingOdometer != null && rider.closingOdometer != null
                    ? '${rider.closingOdometer! - rider.openingOdometer!} km'
                    : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loaded(ShiftRiderDay rider) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bottles loaded on the van', style: adminType(16, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 4),
          Text(
            rider.status == 'NotStarted'
                ? 'The shift has not been started, so no load count was saved.'
                : '${rider.loaded.length} items · ${rider.loadedUnits} loaded · depot expected ${rider.expectedUnits}',
            style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 10),
          if (rider.loaded.isEmpty)
            Text(
              'No van stock was saved for this shift.',
              style: adminType(13, FontWeight.w600, AdminTokens.text),
            )
          else
            for (final line in rider.loaded) _loadRow(line),
        ],
      ),
    );
  }

  Widget _loadRow(LoadedBottle line) {
    final unit = line.unitLabel.isEmpty ? '' : ' ${line.unitLabel}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.productName, style: adminType(14, FontWeight.w700, AdminTokens.text)),
                Text(
                  'Depot expected ${line.depotExpected}$unit · loaded ${line.loaded}$unit · ${line.loadStatus}',
                  style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                ),
                Text(
                  line.closing == null
                      ? 'Closing count was not recorded.'
                      : 'Closing count ${line.closing}$unit',
                  style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deliver(ShiftRiderDay rider) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bottles to deliver', style: adminType(16, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 4),
          Text(
            rider.orderCount == 0
                ? 'No orders are assigned for this date.'
                : '${rider.orderCount} orders · ${rider.toDeliverUnits} units',
            style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 10),
          if (rider.toDeliver.isEmpty)
            Text(
              'No product quantities were returned for this date.',
              style: adminType(13, FontWeight.w600, AdminTokens.text),
            )
          else
            for (final line in rider.toDeliver)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${line.productName} · ${line.quantity}${line.unitLabel.isEmpty ? '' : ' ${line.unitLabel}'}',
                  style: adminType(14, FontWeight.w600, AdminTokens.text),
                ),
              ),
        ],
      ),
    );
  }

  Widget _photos(ShiftRiderDay rider) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Photos saved with the shift', style: adminType(16, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _photo('Opening odometer', rider.openingPhotoStored, rider.openingOdometerPhoto),
              _photo('Closing odometer', rider.closingPhotoStored, rider.closingOdometerPhoto),
              _photo('Opening inspection', rider.openingInspectionStored, rider.openingInspectionPhoto),
              _photo('Closing inspection', rider.closingInspectionStored, rider.closingInspectionPhoto),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photo(String label, bool stored, String? encoded) {
    final bytes = _decode(encoded);
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: adminType(13, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 6),
          if (bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes, height: 140, width: 220, fit: BoxFit.cover),
            )
          else
            Text(
              stored ? 'A photo is stored, but it could not be shown.' : 'No photo was stored.',
              style: adminType(12, FontWeight.w500, AdminTokens.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _odometer(List<OdometerDay> rows, String name) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Odometer record · $name', style: adminType(16, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 4),
          Text(
            'Every shift saved for this rider. The date above filters the load and the delivery bottles. This list keeps the earlier days.',
            style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              'No odometer reading has been saved for this rider.',
              style: adminType(13, FontWeight.w600, AdminTokens.text),
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${row.serviceDate} · ${row.status == 'Closed' ? 'Day closed' : 'Day started'} · opening ${row.openingOdometer} km'
                  '${row.closingOdometer == null ? '' : ' · closing ${row.closingOdometer} km'}'
                  '${row.distanceKm == null ? '' : ' · ${row.distanceKm} km'}',
                  style: adminType(13, FontWeight.w600, AdminTokens.text),
                ),
              ),
        ],
      ),
    );
  }

  Widget _statusChip(ShiftRiderDay rider) {
    final open = rider.status == 'Open';
    final closed = rider.status == 'Closed';
    final color = open
        ? AdminTokens.success
        : closed
        ? AdminTokens.primary
        : AdminTokens.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(rider.statusLabel, style: adminType(12, FontWeight.w700, color)),
    );
  }

  Widget _metric(String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: adminType(11, FontWeight.w600, AdminTokens.textSecondary)),
          Text(value, style: adminType(14, FontWeight.w700, AdminTokens.text)),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTokens.line),
      ),
      child: child,
    );
  }

  String _longDate(DateTime value) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String _clock(String? value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Uint8List? _decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }
}
