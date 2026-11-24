import 'package:flutter/material.dart';

import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/account_type_screen.dart';
import 'package:riderfrontend/customerApp/customer_request_screen.dart';
import 'package:riderfrontend/customerApp/customer_theme.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({required this.session, required this.onOpen, super.key});

  final AuthSession session;
  final ValueChanged<Widget> onOpen;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  var _started = false;
  var _loading = true;
  var _sessionExpired = false;
  String? _error;
  CustomerProfile? _profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await ApiScope.of(context).customerProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      final expired = error.statusCode == 401;
      setState(() {
        _sessionExpired = expired;
        _error = expired ? 'Your session has expired. Sign in again.' : error.message;
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

  Future<void> _policy(String title) async {
    final kind = title.toLowerCase().contains('term') ? 'terms' : 'privacy';
    var body = 'The document could not be loaded.';
    try {
      body = (await ApiScope.of(context).policyDocument(kind)).body;
    } on ApiException catch (error) {
      body = error.message;
    } catch (_) {
      body = 'The document could not be loaded.';
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Text(body))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  String _since(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  Future<void> _openAddress([CustomerAddress? address]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerAddressEditor(address: address)));
    if (mounted) _load();
  }

  Future<void> _deactivate(CustomerProfile profile, CustomerAddress address) async {
    final active = profile.addresses.where((item) => item.isActive).length;
    if (active <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keep at least one active address.')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Deactivate this address?'),
        content: const Text('The address stays on file. An active delivery schedule is not moved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiScope.of(context).deactivateCustomerAddress(address.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
    if (mounted) _load();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to open this account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ApiScope.of(context).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AccountTypeSelectionScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final identity = profile == null ? const SizedBox.shrink() : _identity(profile);
        final addresses = profile == null ? const SizedBox.shrink() : _addresses(profile);
        final security = _group('Account & Security', Icons.vpn_key_outlined, [
          _row(Icons.person_outline, 'Edit profile', profile == null ? null : () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerProfileEditor(profile: profile)));
            if (mounted) _load();
          }),
          _row(Icons.lock_outline, 'Change password', profile == null ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerChangePasswordScreen(email: profile.email))), const Key('customer-open-password')),
          _row(Icons.list_alt, 'My requests', () => widget.onOpen(const CustomerRequestsScreen())),
        ]);
        final preferences = _group('Delivery preferences', Icons.local_shipping_outlined, [
          _row(Icons.edit_location_alt_outlined, 'Request schedule address change', () => widget.onOpen(const CustomerRequestForm(type: 'AddressChange'))),
          _row(Icons.verified_user_outlined, 'Privacy policy', () => _policy('Privacy Policy')),
          _row(Icons.description_outlined, 'Terms & conditions', () => _policy('Terms & Conditions')),
        ]);
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFF0F7FD)),
            const Positioned(top: 0, left: 0, right: 0, height: 168, child: Image(image: AssetImage('assets/customer_home/images/customer_home_header_bg.png'), fit: BoxFit.cover, alignment: Alignment.topCenter)),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      key: const Key('customer-profile-screen'),
                      padding: const EdgeInsets.only(bottom: 28),
                      children: [
                        _header(profile),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            children: [
                              if (_loading) const LinearProgressIndicator(color: Color(0xFF0875E8)),
                              if (_error != null) ...[
                                Text(_error!, style: customerType(14, FontWeight.w600, const Color(0xFFDC2626))),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(onPressed: _sessionExpired ? _logout : _load, child: Text(_sessionExpired ? 'Sign in' : 'Try again')),
                                ),
                              ],
                              if (profile != null)
                                wide
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: Column(children: [identity, const SizedBox(height: 16), addresses])),
                                          const SizedBox(width: 16),
                                          Expanded(child: Column(children: [security, const SizedBox(height: 16), preferences, const SizedBox(height: 16), _logoutButton()])),
                                        ],
                                      )
                                    : Column(children: [identity, const SizedBox(height: 12), addresses, const SizedBox(height: 16), security, const SizedBox(height: 16), preferences, const SizedBox(height: 16), _logoutButton()]),
                            ],
                          ),
                        ),
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
  }

  Widget _header(CustomerProfile? profile) {
    final first = profile?.firstName.trim() ?? '';
    final last = profile?.lastName.trim() ?? '';
    final initials = '${first.isEmpty ? 'C' : first[0]}${last.isEmpty ? '' : last[0]}'.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/customer_home/branding/aquarider_logo.png', height: 36, fit: BoxFit.contain),
              const Spacer(),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => widget.onOpen(const CustomerNotificationsScreen()),
                  style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(32, 32), fixedSize: const Size(32, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  icon: const Icon(Icons.notifications_none_rounded, size: 16, color: Color(0xFF102448)),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: SizedBox(width: 32, height: 32, child: Center(child: Text(initials, style: customerType(11, FontWeight.w700, const Color(0xFF0875E8))))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('My Profile', style: customerType(26, FontWeight.w700, const Color(0xFF102448), height: 1.1)),
        ],
      ),
    );
  }

  Widget _identity(CustomerProfile profile) {
    final name = '${profile.firstName} ${profile.lastName}'.trim();
    final initials = '${profile.firstName.isEmpty ? '' : profile.firstName[0]}${profile.lastName.isEmpty ? '' : profile.lastName[0]}'.toUpperCase();
    final active = profile.accountStatus.toLowerCase() == 'active';
    return _card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 340;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: customerType(20, FontWeight.w700, const Color(0xFF102448), height: 1.15)),
              Text('Customer ID · ${profile.customerCode}', style: customerType(13, FontWeight.w500, const Color(0xFF526477))),
              const SizedBox(height: 6),
              _contact(Icons.mail_outline, profile.email),
              _contact(Icons.phone_outlined, profile.phone),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: active ? const Color(0xFFE5F8EC) : const Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(999)),
                child: Text('${profile.accountStatus} · since ${_since(profile.createdAt)}', style: customerType(12, FontWeight.w600, active ? const Color(0xFF16834A) : const Color(0xFFDC2626))),
              ),
            ],
          );
          final avatar = Container(
            width: narrow ? 64 : 84,
            height: narrow ? 64 : 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFE7F3FF), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFDCE8F2))),
            child: Text(initials.isEmpty ? 'C' : initials, style: customerType(narrow ? 18 : 22, FontWeight.w700, const Color(0xFF0875E8))),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (narrow) ...[avatar, const SizedBox(height: 10), details] else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [avatar, const SizedBox(width: 14), Expanded(child: details)]),
              const SizedBox(height: 12),
              _note(profile.linked ? 'Route customer ${profile.deliveryCustomerCode ?? ''} ${profile.deliveryCustomerName ?? ''}'.trim() : 'No active delivery schedule yet'),
            ],
          );
        },
      ),
    );
  }

  Widget _addresses(CustomerProfile profile) {
    final rows = profile.addresses;
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_outlined, color: Color(0xFF0875E8), size: 20),
            const SizedBox(width: 6),
            Expanded(child: Text('Saved Addresses', style: customerType(18, FontWeight.w700, const Color(0xFF102448)))),
            TextButton.icon(
              key: const Key('customer-add-address'),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
              onPressed: () => _openAddress(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add address'),
            ),
          ],
        ),
        _note('Saving an address won\'t change an active schedule. Address changes for future deliveries require office approval.'),
        const SizedBox(height: 8),
        if (rows.isEmpty) _card(child: Text('No saved addresses yet.', style: customerType(14, FontWeight.w500, const Color(0xFF526477)))),
        for (final address in rows) ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFE7F3FF), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.home_outlined, color: Color(0xFF0875E8)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${address.label}${address.isDefault ? ' · Default' : ''}${address.isActive ? '' : ' · Inactive'}', style: customerType(15, FontWeight.w700, const Color(0xFF102448)))),
                    if (address.isDefault) Text('Default', style: customerType(12, FontWeight.w700, const Color(0xFF16834A))),
                  ],
                ),
                const SizedBox(height: 6),
                Text(address.summary, style: customerType(13, FontWeight.w400, const Color(0xFF526477))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(onPressed: () => _openAddress(address), icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
                    if (address.isActive && !address.isDefault)
                      TextButton(
                        onPressed: () async {
                        try {
                          await ApiScope.of(context).defaultCustomerAddress(address.id);
                        } on ApiException catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
                        }
                        if (mounted) _load();
                      }, child: const Text('Set default')),
                    if (address.isActive)
                      TextButton.icon(
                        onPressed: () => _deactivate(profile, address),
                        icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                        label: Text('Deactivate', style: customerType(14, FontWeight.w600, const Color(0xFFDC2626))),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _group(String title, IconData icon, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, size: 18, color: const Color(0xFF0875E8)), const SizedBox(width: 6), Expanded(child: Text(title, style: customerType(18, FontWeight.w700, const Color(0xFF102448))))]),
        const SizedBox(height: 8),
        _card(
          padding: EdgeInsets.zero,
          child: Column(children: [for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(height: 1, color: Color(0xFFDCE8F2)), rows[i]]]),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String label, VoidCallback? onTap, [Key? key]) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFE7F3FF), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: const Color(0xFF0875E8)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: customerType(15, FontWeight.w600, const Color(0xFF102448)))),
            const Icon(Icons.chevron_right, color: Color(0xFF526477)),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        key: const Key('customer-logout'),
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: _logout,
        icon: const Icon(Icons.logout),
        label: Text('Log out', style: customerType(16, FontWeight.w600, Colors.white)),
      ),
    );
  }

  Widget _contact(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0875E8)),
          const SizedBox(width: 6),
          Expanded(child: Text(value, style: customerType(13, FontWeight.w500, const Color(0xFF102448)))),
        ],
      ),
    );
  }

  Widget _note(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFEAF4FC), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF0875E8)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: customerType(13, FontWeight.w500, const Color(0xFF526477)))),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE8F2)),
        boxShadow: const [BoxShadow(color: Color(0x120875E8), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class CustomerAddressEditor extends StatefulWidget {
  const CustomerAddressEditor({this.address, super.key});

  final CustomerAddress? address;

  @override
  State<CustomerAddressEditor> createState() => _CustomerAddressEditorState();
}

class _CustomerAddressEditorState extends State<CustomerAddressEditor> {
  late final _label = TextEditingController(text: widget.address?.label ?? 'Home');
  late final _city = TextEditingController(text: widget.address?.city ?? '');
  late final _area = TextEditingController(text: widget.address?.area ?? '');
  late final _street = TextEditingController(text: widget.address?.street ?? '');
  late final _house = TextEditingController(text: widget.address?.houseNumber ?? '');
  late final _landmark = TextEditingController(text: widget.address?.landmark ?? '');
  late final _instructions = TextEditingController(text: widget.address?.instructions ?? '');
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _city.dispose();
    _area.dispose();
    _street.dispose();
    _house.dispose();
    _landmark.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty || _city.text.trim().isEmpty || _area.text.trim().isEmpty || _street.text.trim().isEmpty || _house.text.trim().isEmpty) {
      setState(() => _error = 'Label, city, area, street, and house number are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = {
      'label': _label.text.trim(),
      'city': _city.text.trim(),
      'area': _area.text.trim(),
      'street': _street.text.trim(),
      'houseNumber': _house.text.trim(),
      'landmark': _landmark.text.trim(),
      'instructions': _instructions.text.trim(),
    };
    try {
      final existing = widget.address;
      if (existing == null) {
        await ApiScope.of(context).saveCustomerAddress(body);
      } else {
        await ApiScope.of(context).saveCustomerAddress(body, id: existing.id);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('customer-address-editor'),
      backgroundColor: customerPage,
      appBar: AppBar(
        backgroundColor: customerPage,
        foregroundColor: customerNavy,
        elevation: 0,
        title: Text(widget.address == null ? 'Add address' : 'Edit address'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('This address is saved on your account. It does not move an active delivery schedule.', style: customerType(14, FontWeight.w600, customerNavy)),
          const SizedBox(height: 12),
          TextField(controller: _label, decoration: customerField('Label')),
          const SizedBox(height: 8),
          TextField(controller: _city, decoration: customerField('City')),
          const SizedBox(height: 8),
          TextField(controller: _area, decoration: customerField('Area')),
          const SizedBox(height: 8),
          TextField(controller: _street, decoration: customerField('Street')),
          const SizedBox(height: 8),
          TextField(controller: _house, decoration: customerField('House number')),
          const SizedBox(height: 8),
          TextField(controller: _landmark, decoration: customerField('Landmark')),
          const SizedBox(height: 8),
          TextField(controller: _instructions, decoration: customerField('Delivery instructions')),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: customerType(13, FontWeight.w600, customerError)),
          ],
          const SizedBox(height: 16),
          FilledButton(style: customerPrimaryButton(), onPressed: _busy ? null : _save, child: const Text('Save address')),
        ],
      ),
    );
  }
}

class CustomerProfileEditor extends StatefulWidget {
  const CustomerProfileEditor({required this.profile, super.key});

  final CustomerProfile profile;

  @override
  State<CustomerProfileEditor> createState() => _CustomerProfileEditorState();
}

class _CustomerProfileEditorState extends State<CustomerProfileEditor> {
  late final _first = TextEditingController(text: widget.profile.firstName);
  late final _last = TextEditingController(text: widget.profile.lastName);
  late final _phone = TextEditingController(text: widget.profile.phone);
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) {
      setState(() => _error = 'First name and last name are required.');
      return;
    }
    if (digits.length < 10 || digits.length > 15) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiScope.of(context).updateCustomerProfile(firstName: _first.text.trim(), lastName: _last.text.trim(), phone: _phone.text.trim());
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('customer-profile-editor'),
      backgroundColor: customerPage,
      appBar: AppBar(backgroundColor: customerPage, foregroundColor: customerNavy, elevation: 0, title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Customer ID ${widget.profile.customerCode} and ${widget.profile.accountStatus} cannot be changed here.', style: customerType(14, FontWeight.w600, customerNavy)),
          const SizedBox(height: 8),
          Text('Email ${widget.profile.email} stays the login. Email changes are not available because a verification message is not configured.', style: customerType(13, FontWeight.w500, customerMuted)),
          const SizedBox(height: 12),
          TextField(key: const Key('customer-profile-first'), controller: _first, decoration: customerField('First name')),
          const SizedBox(height: 8),
          TextField(key: const Key('customer-profile-last'), controller: _last, decoration: customerField('Last name')),
          const SizedBox(height: 8),
          TextField(key: const Key('customer-profile-phone'), controller: _phone, decoration: customerField('Phone')),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: customerType(13, FontWeight.w600, customerError)),
          ],
          const SizedBox(height: 16),
          FilledButton(key: const Key('customer-profile-save'), style: customerPrimaryButton(), onPressed: _busy ? null : _save, child: const Text('Save')),
        ],
      ),
    );
  }
}

class CustomerChangePasswordScreen extends StatefulWidget {
  const CustomerChangePasswordScreen({required this.email, super.key});

  final String email;

  @override
  State<CustomerChangePasswordScreen> createState() => _CustomerChangePasswordScreenState();
}

class _CustomerChangePasswordScreenState extends State<CustomerChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _busy = false;
  var _showCurrent = false;
  var _showNext = false;
  var _showConfirm = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _problem() {
    if (_current.text.isEmpty) return 'Enter the current password.';
    if (_next.text != _confirm.text) return 'The new passwords do not match.';
    if (_next.text.length < 8 || !_next.text.contains(RegExp(r'[a-z]')) || !_next.text.contains(RegExp(r'\d'))) {
      return 'Use at least 8 characters, one lowercase letter, and one digit.';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ApiScope.of(context);
      await api.changePassword(currentPassword: _current.text, newPassword: _next.text);
      if (!mounted) return;
      await api.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const AccountTypeSelectionScreen()), (_) => false);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('customer-change-password'),
      backgroundColor: customerPage,
      appBar: AppBar(backgroundColor: customerPage, foregroundColor: customerNavy, elevation: 0, title: const Text('Change password')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('The current password is checked on the server. After a change, this phone signs out.', style: customerType(14, FontWeight.w600, customerNavy)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('customer-password-current'),
            controller: _current,
            obscureText: !_showCurrent,
            decoration: customerField('Current password').copyWith(
              suffixIcon: IconButton(onPressed: () => setState(() => _showCurrent = !_showCurrent), icon: Icon(_showCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('customer-password-next'),
            controller: _next,
            obscureText: !_showNext,
            decoration: customerField('New password').copyWith(
              suffixIcon: IconButton(onPressed: () => setState(() => _showNext = !_showNext), icon: Icon(_showNext ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('customer-password-confirm'),
            controller: _confirm,
            obscureText: !_showConfirm,
            decoration: customerField('Confirm new password').copyWith(
              suffixIcon: IconButton(onPressed: () => setState(() => _showConfirm = !_showConfirm), icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, key: const Key('customer-password-error'), style: customerType(13, FontWeight.w600, customerError)),
          ],
          const SizedBox(height: 16),
          FilledButton(key: const Key('customer-password-save'), style: customerPrimaryButton(), onPressed: _busy ? null : _save, child: const Text('Update password')),
          TextButton(
            onPressed: () async {
              try {
                await ApiScope.of(context).forgotPassword(widget.email);
              } on ApiException {
                // The same sentence is shown whether or not the account exists.
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ask your fleet admin to reset this password.')));
            },
            child: const Text('Forgot password'),
          ),
        ],
      ),
    );
  }
}
