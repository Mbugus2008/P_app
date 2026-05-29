import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/parcel_controller.dart';
import '../database/database_helper.dart';
import '../models/app_location.dart';
import '../utilities/Apis.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _agentCodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _db = DatabaseHelper();
  final _api = ApiClient();
  final _controller = Get.find<ParcelController>();

  List<AppLocation> _locations = <AppLocation>[];
  String? _selectedLocation;
  String _selectedType = 'User';
  bool _isSubmitting = false;

  static const List<String> _types = <String>[
    'User',
    'Supervisor',
    'Deport',
    'Fuel',
    'Parcel',
  ];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _agentCodeCtrl.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    var locations = await _db.getAllLocations();
    if (locations.isEmpty) {
      await _controller.syncLocationsOnStartup();
      locations = await _db.getAllLocations();
    }

    if (!mounted) return;
    setState(() {
      _locations = locations;
      if (_locations.isNotEmpty) {
        _selectedLocation = _locationValue(_locations.first);
      }
    });
  }

  String _locationValue(AppLocation location) {
    final name = location.name?.trim() ?? '';
    return name.isNotEmpty ? name : location.code.trim();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    final creator = _controller.loggedInUser;
    if (creator == null) {
      Get.snackbar('Error', 'No active user session. Please login again.');
      return;
    }
    if (!creator.isAdmin) {
      Get.snackbar('Access denied', 'Only Admin users can create users.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _api.createUser(
        agentCode: _agentCodeCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        mobileNo: _mobileCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        location: _selectedLocation ?? '',
        accountType: _selectedType,
        createdByAgentCode: creator.agentCode,
      );

      await _controller.syncUsersOnStartup();

      if (!mounted) return;
      Get.back(result: true);
      Get.snackbar('Success', 'User created successfully.');
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Create user failed', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final creator = _controller.loggedInUser;
    final isAdmin = creator?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Add User')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isAdmin)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Text(
                      'Only Admin users can create new users.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _agentCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Agent Code *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Agent code is required'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Mobile number is required'
                              : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  items:
                      _types
                          .map(
                            (type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                  decoration: const InputDecoration(
                    labelText: 'User Type *',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedType = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLocation,
                  items:
                      _locations.map((loc) {
                        final label = _locationValue(loc);
                        return DropdownMenuItem<String>(
                          value: label,
                          child: Text(label),
                        );
                      }).toList(),
                  decoration: const InputDecoration(
                    labelText: 'Location *',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Location is required'
                              : null,
                  onChanged:
                      (value) => setState(() => _selectedLocation = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Password is required';
                    if (value.length < 4)
                      return 'Password must be at least 4 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password *',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value != _passwordCtrl.text.trim()) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: (!_isSubmitting && isAdmin) ? _createUser : null,
                    icon:
                        _isSubmitting
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.person_add_alt_1),
                    label: Text(_isSubmitting ? 'Creating...' : 'Create User'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
