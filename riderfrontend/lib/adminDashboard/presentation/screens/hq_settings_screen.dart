import 'package:flutter/material.dart';

import 'package:riderfrontend/adminDashboard/presentation/admin_load.dart';
import 'package:riderfrontend/adminDashboard/presentation/admin_nav.dart';
import 'package:riderfrontend/adminDashboard/presentation/widgets/admin_shell.dart';
import 'package:riderfrontend/adminDashboard/theme/admin_tokens.dart';
import 'package:riderfrontend/api/route_api.dart';

class HqSettingsScreen extends StatefulWidget {
  const HqSettingsScreen({required this.onNavigate, this.session, super.key});

  final AuthSession? session;
  final ValueChanged<String> onNavigate;

  @override
  State<HqSettingsScreen> createState() => _HqSettingsScreenState();
}

class _HqSettingsScreenState extends State<HqSettingsScreen> {
  final _legal = TextEditingController();
  final _display = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _website = TextEditingController();
  final _footer = TextEditingController();
  final _search = TextEditingController();
  var _started = false;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _legal.dispose();
    _display.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _website.dispose();
    _footer.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await ApiScope.of(context).hqSettings();
      if (!mounted) return;
      _legal.text = settings.legalName;
      _display.text = settings.displayName;
      _email.text = settings.supportEmail;
      _phone.text = settings.supportPhone;
      _address.text = settings.supportAddress;
      _website.text = settings.website;
      _footer.text = settings.receiptFooter;
      setState(() {
        _error = null;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiScope.of(context).updateHqSettings({
        'legalName': _legal.text.trim(),
        'displayName': _display.text.trim(),
        'supportEmail': _email.text.trim(),
        'supportPhone': _phone.text.trim(),
        'supportAddress': _address.text.trim(),
        'website': _website.text.trim(),
        'receiptFooter': _footer.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('HQ settings saved. Policy contact lines use these values.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      activeKey: AdminNav.settings,
      session: widget.session,
      serverReachable: _error != adminUnreachableMessage,
      search: _search,
      onSearch: (_) {},
      searchHint: 'HQ settings',
      onNavigate: widget.onNavigate,
      body: ListView(
        key: const Key('hq-settings-screen'),
        padding: const EdgeInsets.all(16),
        children: [
          Text('HQ Settings', style: adminType(24, FontWeight.w700, AdminTokens.text)),
          const SizedBox(height: 8),
          Text(
            'These contact lines fill the published privacy policy and terms. Leave a line blank and the policy says that office contact is not set.',
            style: adminType(13, FontWeight.w500, AdminTokens.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!, style: adminType(14, FontWeight.w600, AdminTokens.error)),
          _field(_legal, 'Legal name'),
          _field(_display, 'Display name'),
          _field(_email, 'Support email'),
          _field(_phone, 'Support phone'),
          _field(_address, 'Registered address'),
          _field(_website, 'Website'),
          _field(_footer, 'Receipt footer'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(onPressed: _loading || _saving ? null : _save, child: const Text('Save settings')),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(controller: controller, decoration: InputDecoration(labelText: label)),
    );
  }
}
