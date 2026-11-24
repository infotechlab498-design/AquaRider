import 'package:flutter/material.dart';

import '../ui/route_ui.dart';
import '../widgets/rider_inbox_button.dart';
import '../widgets/rider_wave_background.dart';

const _navy = Color(0xFF102448);
const _blue = Color(0xFF0875E8);
const _muted = Color(0xFF6A7C90);
const _line = Color(0xFFE3EEF7);
const _iconPath = 'assets/rider_settings/icons';

class RiderSettingsPane extends StatelessWidget {
  const RiderSettingsPane({
    required this.canPop,
    required this.name,
    required this.initials,
    required this.riderCode,
    required this.routeLine,
    required this.onShift,
    required this.stopsCompleted,
    required this.connected,
    required this.printerLabel,
    required this.autoSync,
    required this.ordersTab,
    required this.autoPrint,
    required this.language,
    required this.paper80,
    required this.company,
    required this.customer,
    required this.ledger,
    required this.gps,
    required this.failedCount,
    required this.onEdit,
    required this.onDefaults,
    required this.onCompliance,
    required this.onAutoSync,
    required this.onOrdersTab,
    required this.onLanguage,
    required this.onStatus,
    required this.onConfigure,
    required this.onPair,
    required this.onAutoPrint,
    required this.onPaper,
    required this.onCompany,
    required this.onCustomer,
    required this.onLedger,
    required this.onGps,
    required this.onTestPrint,
    super.key,
  });

  final bool canPop;
  final String name;
  final String initials;
  final String riderCode;
  final String routeLine;
  final bool onShift;
  final int stopsCompleted;
  final bool connected;
  final String printerLabel;
  final bool autoSync;
  final bool ordersTab;
  final bool autoPrint;
  final String language;
  final bool paper80;
  final bool company;
  final bool customer;
  final bool ledger;
  final bool gps;
  final int failedCount;
  final VoidCallback onEdit;
  final VoidCallback onDefaults;
  final VoidCallback onCompliance;
  final ValueChanged<bool> onAutoSync;
  final ValueChanged<bool> onOrdersTab;
  final VoidCallback onLanguage;
  final VoidCallback onStatus;
  final VoidCallback onConfigure;
  final VoidCallback onPair;
  final ValueChanged<bool> onAutoPrint;
  final ValueChanged<bool> onPaper;
  final ValueChanged<bool> onCompany;
  final ValueChanged<bool> onCustomer;
  final ValueChanged<bool> onLedger;
  final ValueChanged<bool> onGps;
  final VoidCallback onTestPrint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Stack(
          fit: StackFit.expand,
          children: [
            const RiderWaveBackground(),
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 980 : 560),
                  child: ListView(
                    key: const Key('rider-settings-screen'),
                    padding: EdgeInsets.fromLTRB(16, 8, 16, canPop ? 24 : 12),
                    children: [
                      _topBar(context),
                      const SizedBox(height: 14),
                      Text('Settings & Profile', style: routeType(26, FontWeight.w800, _navy, 30, -0.3)),
                      const SizedBox(height: 4),
                      Text('Manage your account, app preferences and device.', style: routeType(13, FontWeight.w500, _muted, 18)),
                      const SizedBox(height: 16),
                      _profile(),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionAsset('$_iconPath/ic_route_compliance.png', 'Route Compliance'),
                                  const SizedBox(height: 8),
                                  _compliance(),
                                  const SizedBox(height: 16),
                                  _sectionAsset('$_iconPath/ic_orders_list.png', 'App Preferences'),
                                  const SizedBox(height: 8),
                                  _preferences(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionAsset('$_iconPath/ic_printer.png', 'Printing & Receipts'),
                                  const SizedBox(height: 8),
                                  _printing(),
                                  if (failedCount > 0) ...[
                                    const SizedBox(height: 12),
                                    _failed(),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _sectionAsset('$_iconPath/ic_route_compliance.png', 'Route Compliance'),
                        const SizedBox(height: 8),
                        _compliance(),
                        const SizedBox(height: 16),
                        _sectionAsset('$_iconPath/ic_orders_list.png', 'App Preferences'),
                        const SizedBox(height: 8),
                        _preferences(),
                        const SizedBox(height: 16),
                        _sectionAsset('$_iconPath/ic_printer.png', 'Printing & Receipts'),
                        const SizedBox(height: 8),
                        _printing(),
                        if (failedCount > 0) ...[
                          const SizedBox(height: 12),
                          _failed(),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        if (canPop)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, color: _navy, size: 18),
              ),
            ),
          ),
        Image.asset('assets/customer_home/branding/aquarider_logo.png', height: 36, fit: BoxFit.contain),
        const Spacer(),
        Material(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x220875E8),
          shape: const CircleBorder(),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: Transform.scale(
                scale: 0.78,
                child: const RiderInboxButton(iconColor: _navy),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0x220875E8),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onEdit,
            child: const SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.person_outline, color: _navy, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profile() {
    return _card(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(name, style: routeType(18, FontWeight.w800, _navy, 22)),
                        if (riderCode.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFE7F3FF), borderRadius: BorderRadius.circular(8)),
                            child: Text(riderCode, style: routeType(11, FontWeight.w700, _blue, 14)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 14, color: _muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(routeLine, maxLines: 2, overflow: TextOverflow.ellipsis, style: routeType(12, FontWeight.w500, _muted, 16)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: const Key('settings-edit'),
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD5E6F6)),
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('$_iconPath/ic_edit.png', width: 14, height: 14),
                    const SizedBox(width: 4),
                    Text('Edit', style: routeType(12, FontWeight.w700, _blue, 16)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 360;
              final chips = [
                _shiftChip(),
                _dividerDot(stacked),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.outlined_flag, size: 15, color: _blue),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$stopsCompleted Stops Completed Today',
                        style: routeType(12, FontWeight.w700, _blue, 16),
                      ),
                    ),
                  ],
                ),
                _dividerDot(stacked),
                TextButton(
                  onPressed: onDefaults,
                  style: TextButton.styleFrom(
                    foregroundColor: _blue,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: routeType(12, FontWeight.w700, _blue, 16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('$_iconPath/ic_printer_configure.png', width: 15, height: 15),
                      const SizedBox(width: 4),
                      const Text('Defaults'),
                    ],
                  ),
                ),
              ];
              if (stacked) {
                return Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: chips);
              }
              return Row(
                children: [
                  chips[0],
                  chips[1],
                  Expanded(child: chips[2]),
                  chips[3],
                  chips[4],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dividerDot(bool stacked) {
    if (stacked) return const SizedBox.shrink();
    return Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 8), color: _line);
  }

  Widget _shiftChip() {
    final color = onShift ? const Color(0xFF168A45) : _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onShift ? const Color(0xFFE6F7ED) : const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: onShift ? const Color(0xFF22A45A) : const Color(0xFF8AA0B5), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(onShift ? 'On Shift' : 'Signed in', style: routeType(12, FontWeight.w700, color, 16)),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6EC8FF), Color(0xFF0875E8)]),
        boxShadow: [BoxShadow(color: Color(0x330875E8), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            const Positioned(left: 0, right: 0, bottom: -2, height: 30, child: CustomPaint(painter: _AvatarWavePainter())),
            Center(child: Text(initials.isEmpty ? 'AR' : initials, style: routeType(22, FontWeight.w800, Colors.white, 26))),
          ],
        ),
      ),
    );
  }

  Widget _compliance() {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: InkWell(
        key: const Key('settings-compliance'),
        borderRadius: BorderRadius.circular(18),
        onTap: onCompliance,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFE8F4FF), borderRadius: BorderRadius.circular(14)),
              child: Image.asset('$_iconPath/ic_map_alert.png', width: 24, height: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Route Compliance & Alerts', style: routeType(14, FontWeight.w800, _navy, 18)),
                  const SizedBox(height: 2),
                  Text('Location sharing, deviation alerts and explanations.', style: routeType(12, FontWeight.w500, _muted, 16)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9AADC0)),
          ],
        ),
      ),
    );
  }

  Widget _preferences() {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          _switchRow(
            '$_iconPath/ic_auto_sync.png',
            'Auto Sync',
            'Sales and collections are sent to the server automatically.',
            autoSync,
            onAutoSync,
            const Key('settings-auto-sync'),
          ),
          const Divider(height: 1, color: _line),
          _switchRow(
            '$_iconPath/ic_orders_list.png',
            'Show Orders Tab',
            "Shows the Orders filter on today's route.",
            ordersTab,
            onOrdersTab,
            const Key('settings-orders-tab'),
          ),
          const Divider(height: 1, color: _line),
          InkWell(
            key: const Key('settings-language'),
            onTap: onLanguage,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  _assetBubble('$_iconPath/ic_language.png'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Language', style: routeType(14, FontWeight.w800, _navy, 18)),
                        Text(language, style: routeType(12, FontWeight.w500, _muted, 16)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF9AADC0)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _printing() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _PrinterArt(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bluetooth Thermal Printer', style: routeType(15, FontWeight.w800, _navy, 20)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: connected ? const Color(0xFF22A45A) : const Color(0xFFE23B4A), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            printerLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: routeType(12, FontWeight.w700, connected ? const Color(0xFF168A45) : const Color(0xFFE23B4A), 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('$_iconPath/ic_printer_status.png', 'Status', onStatus, key: const Key('settings-printer-status')),
              _pill('$_iconPath/ic_printer_configure.png', 'Configure', onConfigure, key: const Key('settings-printer-configure')),
              _pill('$_iconPath/ic_bluetooth.png', 'Pair', onPair, filled: true, key: const Key('settings-printer-pair')),
            ],
          ),
          const SizedBox(height: 8),
          _switchRow(
            '$_iconPath/ic_receipt.png',
            'Auto Print Single Receipt',
            'Sends the slip when a receipt opens and a printer is already connected.',
            autoPrint,
            onAutoPrint,
            const Key('settings-auto-print'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 8),
            child: Row(
              children: [
                Image.asset('$_iconPath/ic_paper_size.png', width: 16, height: 16),
                const SizedBox(width: 6),
                Text('Receipt Paper Size', style: routeType(13, FontWeight.w800, _navy, 18)),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(child: _paperChoice('58mm (Standard)', !paper80, const Key('settings-paper-58'), () => onPaper(false))),
              const SizedBox(width: 8),
              Expanded(child: _paperChoice('80mm', paper80, const Key('settings-paper-80'), () => onPaper(true))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 14, bottom: 8),
            child: Text('Receipt Header & Details', style: routeType(13, FontWeight.w800, _navy, 18)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 430 ? 4 : 2;
              final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _check('$_iconPath/ic_company_header.png', 'Company\nHeader', company, onCompany, width),
                  _check('$_iconPath/ic_customer_details.png', 'Customer\nDetails', customer, onCustomer, width),
                  _check('$_iconPath/ic_ledger_summary.png', 'Ledger\nSummary', ledger, onLedger, width),
                  _check('$_iconPath/ic_gps_test_slip.png', 'GPS on\nTest Slip', gps, onGps, width),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('settings-test-print'),
              onPressed: onTestPrint,
              style: OutlinedButton.styleFrom(
                foregroundColor: _blue,
                side: const BorderSide(color: Color(0xFFD5E6F6)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('$_iconPath/ic_printer.png', width: 18, height: 18),
                  const SizedBox(width: 8),
                  Text('Print Test Receipt', style: routeType(14, FontWeight.w700, _blue, 18)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _failed() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E5), borderRadius: BorderRadius.circular(16)),
      child: Text(
        '$failedCount activities today did not reach the server. Open History to review them.',
        style: routeType(12, FontWeight.w600, const Color(0xFFB26A00), 16),
      ),
    );
  }

  Widget _sectionAsset(String asset, String title) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE5F3FF), borderRadius: BorderRadius.circular(8)),
          child: Image.asset(asset, width: 15, height: 15),
        ),
        const SizedBox(width: 8),
        Text(title, style: routeType(16, FontWeight.w800, _blue, 20)),
      ],
    );
  }

  Widget _switchRow(String asset, String title, String subtitle, bool value, ValueChanged<bool> onChanged, Key key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _assetBubble(asset),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: routeType(14, FontWeight.w800, _navy, 18)),
                Text(subtitle, style: routeType(12, FontWeight.w500, _muted, 16)),
              ],
            ),
          ),
          SizedBox(
            width: 52,
            height: 32,
            child: FittedBox(
              child: Switch(
                key: key,
                value: value,
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected) ? _blue : const Color(0xFFD5DEE8);
                }),
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetBubble(String asset) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Color(0xFFE8F4FF), shape: BoxShape.circle),
      child: Image.asset(asset, width: 18, height: 18),
    );
  }

  Widget _pill(String asset, String label, VoidCallback onPressed, {bool filled = false, Key? key}) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(filled ? Colors.white : _blue, BlendMode.srcIn),
          child: Image.asset(asset, width: 15, height: 15),
        ),
        const SizedBox(width: 4),
        Text(label, style: routeType(12, FontWeight.w700, filled ? Colors.white : _navy, 16)),
      ],
    );
    if (filled) {
      return FilledButton(
        key: key,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const StadiumBorder(),
        ),
        child: child,
      );
    }
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _navy,
        side: const BorderSide(color: Color(0xFFD5E6F6)),
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const StadiumBorder(),
      ),
      child: child,
    );
  }

  Widget _paperChoice(String label, bool selected, Key key, VoidCallback onTap) {
    return Material(
      color: selected ? const Color(0xFFE8F4FF) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _blue : const Color(0xFFD5E6F6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 16, color: selected ? _blue : const Color(0xFF9AADC0)),
              const SizedBox(width: 6),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: routeType(12, FontWeight.w700, selected ? _blue : _muted, 16))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _check(String asset, String label, bool value, ValueChanged<bool> onChanged, double width) {
    return Material(
      color: value ? const Color(0xFFF4F9FD) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: value ? const Color(0xFFD6E8F8) : _line)),
          child: Row(
            children: [
              Icon(value ? Icons.check_box : Icons.check_box_outline_blank, size: 18, color: value ? _blue : const Color(0xFFB7C6D6)),
              const SizedBox(width: 4),
              Image.asset(asset, width: 14, height: 14),
              const SizedBox(width: 4),
              Expanded(child: Text(label, style: routeType(11, FontWeight.w700, _navy, 13))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(14)}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x140875C8), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Material(
        color: const Color(0xF7FFFFFF),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _PrinterArt extends StatelessWidget {
  const _PrinterArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: const Color(0xFFF3F8FD), borderRadius: BorderRadius.circular(16)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            child: Container(
              width: 26,
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFFD5E4F2))),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Tick(),
                  _Tick(),
                  _Tick(width: 10),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              width: 44,
              height: 26,
              decoration: BoxDecoration(color: const Color(0xFF5C6772), borderRadius: BorderRadius.circular(6)),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0xFF4DB2FF), BlendMode.srcIn),
                    child: Image.asset('$_iconPath/ic_bluetooth.png', width: 11, height: 11),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({this.width = 14});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(width: width, height: 1.4, color: const Color(0xFFB7C9DA));
  }
}

class _AvatarWavePainter extends CustomPainter {
  const _AvatarWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x66FFFFFF);
    final path = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.05, size.width * 0.5, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.85, size.width, size.height * 0.35)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
