import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import 'package:riderfrontend/api/route_api.dart';
import 'package:riderfrontend/customerApp/customer_theme.dart';
import 'package:riderfrontend/screens/login.dart';

class CustomerRegistrationScreen extends StatefulWidget {
  const CustomerRegistrationScreen({super.key});

  @override
  State<CustomerRegistrationScreen> createState() => _CustomerRegistrationScreenState();
}

class _CustomerRegistrationScreenState extends State<CustomerRegistrationScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _street = TextEditingController();
  final _house = TextEditingController();
  final _landmark = TextEditingController();
  final _instructions = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _errors = <String, String>{};
  var _hidePassword = true;
  var _hideConfirm = true;
  var _terms = false;
  var _busy = false;
  var _locating = false;
  String? _banner;
  String? _locationNote;
  double? _latitude;
  double? _longitude;
  String? _customerCode;
  String? _registeredName;

  @override
  void dispose() {
    for (final field in [_first, _last, _phone, _email, _city, _area, _street, _house, _landmark, _instructions, _password, _confirm]) {
      field.dispose();
    }
    super.dispose();
  }

  bool _validate() {
    _errors.clear();
    if (_first.text.trim().isEmpty) _errors['first'] = 'First name is required.';
    if (_last.text.trim().isEmpty) _errors['last'] = 'Last name is required.';
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 15) _errors['phone'] = 'Enter a valid phone number.';
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) _errors['email'] = 'Enter a valid email address.';
    if (_city.text.trim().isEmpty || _area.text.trim().isEmpty || _street.text.trim().isEmpty || _house.text.trim().isEmpty) {
      _errors['address'] = 'City, area, street, and house number are required.';
    }
    final password = _password.text;
    if (password.length < 8 || !RegExp(r'\d').hasMatch(password) || !RegExp(r'[a-z]').hasMatch(password)) {
      _errors['password'] = 'Use at least 8 characters, with a number and a lowercase letter.';
    }
    if (_confirm.text != password) _errors['confirm'] = 'Passwords do not match.';
    if (!_terms) _errors['terms'] = 'Accept the terms to create an account.';
    return _errors.isEmpty;
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationNote = null;
    });
    try {
      final location = Location();
      var service = await location.serviceEnabled();
      if (!service) service = await location.requestService();
      if (!service) {
        setState(() => _locationNote = 'Location is off. Enter the address manually.');
        return;
      }
      var permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != PermissionStatus.granted && permission != PermissionStatus.grantedLimited) {
        setState(() => _locationNote = 'Location permission was denied. Enter the address manually.');
        return;
      }
      final here = await location.getLocation().timeout(const Duration(seconds: 12));
      setState(() {
        _latitude = here.latitude;
        _longitude = here.longitude;
        _locationNote = 'Current location selected.';
      });
    } catch (_) {
      if (mounted) setState(() => _locationNote = 'Location could not be read. Enter the address manually.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _banner = null);
    if (!_validate()) {
      setState(() {});
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ApiScope.of(context).registerCustomer({
        'firstName': _first.text.trim(),
        'lastName': _last.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'city': _city.text.trim(),
        'area': _area.text.trim(),
        'street': _street.text.trim(),
        'houseNumber': _house.text.trim(),
        'landmark': _landmark.text.trim(),
        'instructions': _instructions.text.trim(),
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
        'password': _password.text,
        'confirmPassword': _confirm.text,
        'acceptedTerms': true,
      });
      if (!mounted) return;
      setState(() {
        _busy = false;
        _customerCode = result.customerCode;
        _registeredName = result.fullName;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      final message = error.message.trim();
      setState(() {
        _busy = false;
        _banner = message.isEmpty ? 'The account was not created.' : message;
        if (message.toLowerCase().contains('phone')) _errors['phone'] = message;
        if (message.toLowerCase().contains('email')) _errors['email'] = message;
        if (message.toLowerCase().contains('password')) _errors['password'] = message;
        if (message.toLowerCase().contains('address') || message.toLowerCase().contains('city')) {
          _errors['address'] = message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = 'Cannot reach the route server.';
      });
    }
  }

  void _login() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(
          initialUsername: customerTestUsername,
          initialPassword: customerTestPassword,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_customerCode != null) return _success();
    return Scaffold(
      key: const Key('customer-registration-screen'),
      backgroundColor: customerPage,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              key: const Key('customer-registration-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('customer-registration-back'),
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: customerNavy),
                    ),
                    Text('AquaRider', style: customerType(16, FontWeight.w700, customerNavy)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Create Your Customer Account', style: customerType(26, FontWeight.w700, customerNavy, height: 1.15)),
                const SizedBox(height: 8),
                Text('Register once to manage your recurring deliveries.', style: customerType(14, FontWeight.w500, customerMuted)),
                if (_banner != null) ...[
                  const SizedBox(height: 16),
                  Text(_banner!, key: const Key('customer-registration-banner'), style: customerType(13, FontWeight.w600, customerError)),
                ],
                const SizedBox(height: 20),
                _section('Personal information', [
                  _field('First Name', _first, 'first'),
                  _field('Last Name', _last, 'last'),
                  _field('Phone Number', _phone, 'phone', hint: '+92 300 0000000'),
                  _field('Email Address', _email, 'email'),
                ]),
                _section('Delivery address', [
                  _field('City', _city, 'city'),
                  _field('Area / Locality', _area, 'area'),
                  _field('Street Address', _street, 'street'),
                  _field('House / Building Number', _house, 'house'),
                  _field('Landmark', _landmark, 'landmark'),
                  _field('Delivery instructions', _instructions, 'instructions'),
                  if (_errors['address'] != null)
                    Text(_errors['address']!, style: customerType(12.5, FontWeight.w600, customerError)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('customer-use-location'),
                    onPressed: _locating ? null : _locate,
                    icon: const Icon(Icons.my_location_outlined, size: 18),
                    label: Text(_locating ? 'Reading location…' : 'Use My Current Location'),
                  ),
                  if (_locationNote != null) ...[
                    const SizedBox(height: 8),
                    Text(_locationNote!, style: customerType(12.5, FontWeight.w600, customerMuted)),
                  ],
                  if (_latitude != null && _longitude != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Selected location: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                      style: customerType(13, FontWeight.w600, customerNavy),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(_latitude!, _longitude!),
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                            MarkerLayer(markers: [
                              Marker(
                                point: LatLng(_latitude!, _longitude!),
                                width: 32,
                                height: 32,
                                child: const Icon(Icons.location_on, color: customerPrimary, size: 32),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ]),
                _section('Account security', [
                  _field('Create Password', _password, 'password', obscure: _hidePassword, onToggle: () => setState(() => _hidePassword = !_hidePassword)),
                  Text(
                    _password.text.isEmpty
                        ? 'At least 8 characters, with a number and a lowercase letter.'
                        : (_errors['password'] == null ? 'Password meets the account rules.' : 'Password needs a change.'),
                    style: customerType(12.5, FontWeight.w600, _errors['password'] == null && _password.text.isNotEmpty ? customerSuccess : customerMuted),
                  ),
                  const SizedBox(height: 8),
                  _field('Confirm Password', _confirm, 'confirm', obscure: _hideConfirm, onToggle: () => setState(() => _hideConfirm = !_hideConfirm)),
                ]),
                Material(
                  color: customerSurface,
                  child: CheckboxListTile(
                    key: const Key('customer-terms'),
                    contentPadding: EdgeInsets.zero,
                    value: _terms,
                    onChanged: (value) => setState(() => _terms = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('I agree to the Terms & Conditions and Privacy Policy.', style: customerType(13, FontWeight.w600, customerNavy)),
                  ),
                ),
                if (_errors['terms'] != null)
                  Text(_errors['terms']!, style: customerType(12.5, FontWeight.w600, customerError)),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('customer-register-submit'),
                  onPressed: _busy ? null : _submit,
                  style: customerPrimaryButton(),
                  child: Text(_busy ? 'Creating account…' : 'Create Customer Account'),
                ),
                TextButton(onPressed: _busy ? null : _login, child: const Text('Already registered? Login')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _success() {
    return Scaffold(
      key: const Key('customer-registration-success'),
      backgroundColor: customerPage,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Icon(Icons.check_circle, color: customerSuccess, size: 48),
                const SizedBox(height: 12),
                Text('Customer account created', style: customerType(26, FontWeight.w700, customerNavy, height: 1.15)),
                const SizedBox(height: 8),
                Text(_registeredName ?? '', style: customerType(15, FontWeight.w600, customerMuted)),
                const SizedBox(height: 16),
                Text('Customer ID: $_customerCode', key: const Key('customer-registration-id'), style: customerType(18, FontWeight.w700, customerNavy)),
                const SizedBox(height: 8),
                Text(
                  'This Customer ID identifies your account. Sign in with the email and password you just created.',
                  style: customerType(14, FontWeight.w500, customerMuted),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('customer-continue-login'),
                  onPressed: _login,
                  style: customerPrimaryButton(),
                  child: const Text('Continue to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customerSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: customerLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: customerType(16, FontWeight.w700, customerNavy)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String keyName, {
    String? hint,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    final error = _errors[keyName];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: Key('customer-$keyName'),
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: onToggle == null
              ? null
              : IconButton(
                  onPressed: onToggle,
                  icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
        ),
      ),
    );
  }
}
