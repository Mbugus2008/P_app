import 'dart:async';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/parcel_controller.dart';
import '../database/database_helper.dart';
import '../models/app_location.dart';
import '../pages/parcel_dashboard_page.dart';
import '../receipts/thermal_receipt_printer.dart';
import '../utils/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.requireSetup = false});

  final bool requireSetup;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  final ThermalReceiptPrinter _printer = ThermalReceiptPrinter();
  final ParcelController _parcelController = Get.find<ParcelController>();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const Duration _scanTimeout = Duration(seconds: 12);

  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  String? _savedPrinterName;
  String? _savedPrinterMac;

  List<AppLocation> _locations = [];
  String? _selectedLocation;

  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isRoutingAfterSetup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedPrinter();
    _loadLocations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_scanDevices());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_isScanning) {
      unawaited(_scanDevices());
    }
  }

  Future<void> _loadLocations() async {
    final locations = await _dbHelper.getAllLocations();
    final saved = _parcelController.currentLocation.trim();
    final savedRecord = _parcelController.currentLocationRecord;
    String? selectedValue;

    if (saved.isNotEmpty) {
      final matched = _findLocationBySavedValue(locations, saved);
      selectedValue = matched != null ? _locationValue(matched) : saved;
    } else if (savedRecord != null) {
      selectedValue = _locationValue(savedRecord);
    }

    setState(() {
      _locations = locations;
      _selectedLocation =
          selectedValue != null && selectedValue.isNotEmpty
              ? selectedValue
              : null;
    });
  }

  Future<void> _onLocationChanged(String? value) async {
    if (value == null || value.isEmpty) return;

    final selectedRecord = _findLocationBySavedValue(_locations, value);
    if (selectedRecord != null) {
      await _parcelController.setCurrentLocationRecord(selectedRecord);
    } else {
      await _parcelController.setCurrentLocation(value);
    }
    setState(() => _selectedLocation = value);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location set to $value')));
    }
    await _routeToDashboardIfSetupComplete();
  }

  String _locationValue(AppLocation location) {
    final name = location.name?.trim() ?? '';
    return name.isNotEmpty ? name : location.code;
  }

  bool _equalsIgnoreCase(String left, String right) {
    return left.toLowerCase() == right.toLowerCase();
  }

  AppLocation? _findLocationBySavedValue(
    List<AppLocation> locations,
    String value,
  ) {
    final target = value.trim();
    if (target.isEmpty) return null;

    for (final location in locations) {
      final code = location.code.trim();
      final name = location.name?.trim() ?? '';

      if (_equalsIgnoreCase(code, target) ||
          (name.isNotEmpty && _equalsIgnoreCase(name, target))) {
        return location;
      }
    }
    return null;
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPrinterName = prefs.getString('printer_name');
      _savedPrinterMac = prefs.getString('printer_mac');
      if (_savedPrinterMac != null) {
        _selectedDevice = BluetoothDevice(
          (_savedPrinterName?.trim().isNotEmpty ?? false)
              ? _savedPrinterName
              : 'Saved Printer',
          _savedPrinterMac,
        );
      }
    });
  }

  Future<void> _savePrinter(String? name, String? address) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedAddress = address?.trim();
    final trimmedName = name?.trim();

    if (trimmedAddress != null && trimmedAddress.isNotEmpty) {
      await prefs.setString('printer_mac', trimmedAddress);
      if (trimmedName != null && trimmedName.isNotEmpty) {
        await prefs.setString('printer_name', trimmedName);
      } else {
        await prefs.setString('printer_name', 'Saved Printer');
      }
    } else {
      await prefs.remove('printer_name');
      await prefs.remove('printer_mac');
    }
    await _loadSavedPrinter();
    await _routeToDashboardIfSetupComplete();
  }

  Future<void> _routeToDashboardIfSetupComplete() async {
    if (!widget.requireSetup || _isRoutingAfterSetup || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasLocation =
        (prefs.getString('user_location') ?? '').trim().isNotEmpty;
    final hasPrinter = (prefs.getString('printer_mac') ?? '').trim().isNotEmpty;

    if (!hasLocation || !hasPrinter) return;

    _isRoutingAfterSetup = true;
    await Get.offAll(() => const ParcelDashboardPage());
  }

  bool get _canExitWithoutPrinter {
    return widget.requireSetup && !_isScanning && _devices.isEmpty;
  }

  Future<void> _continueWithoutPrinter() async {
    if (!_canExitWithoutPrinter || _isRoutingAfterSetup || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasLocation =
        (prefs.getString('user_location') ?? '').trim().isNotEmpty;

    if (!hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your location first.')),
      );
      return;
    }

    _isRoutingAfterSetup = true;
    await Get.offAll(() => const ParcelDashboardPage());
  }

  Future<void> _scanDevices() async {
    if (!mounted) return;

    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      final bonded = await _bluetooth.getBondedDevices().timeout(_scanTimeout);
      if (!mounted) return;
      setState(() {
        _devices = bonded;
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e is TimeoutException
                ? 'Bluetooth scan timed out. Tap Refresh or reopen Bluetooth and return to this page.'
                : 'Failed to scan: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _testPrint() async {
    if (_selectedDevice == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a printer first before saving.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    await _savePrinter(_selectedDevice!.name, _selectedDevice!.address);

    final connected = await _printer.connect(_selectedDevice!);
    if (!connected) {
      setState(() {
        _error =
            'Failed to connect to ${_selectedDevice!.name}. Printer was saved.';
        _isConnecting = false;
      });
      return;
    }

    try {
      await _printer.printTest();
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test print sent successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Test print failed: $e';
        _isConnecting = false;
      });
    }
  }

  Future<void> _clearPrinter() async {
    await _savePrinter(null, null);
    setState(() => _selectedDevice = null);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Printer cleared')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        actions: [
          if (_canExitWithoutPrinter)
            TextButton(
              onPressed: _continueWithoutPrinter,
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isConnecting ? null : _testPrint,
        icon:
            _isConnecting
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Icon(Icons.print),
        label: Text(_isConnecting ? 'Connecting...' : 'Test Print & Save'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Location',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your current location. This is used to show incoming batches and received parcels.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_locations.isEmpty)
                    Text(
                      'No locations available. Sync reference data first.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLocation,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items:
                          _locations.map((loc) {
                            final label = loc.name ?? loc.code;
                            return DropdownMenuItem<String>(
                              value: label,
                              child: Text(label),
                            );
                          }).toList(),
                      onChanged: _onLocationChanged,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Current printer card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Printer',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_savedPrinterMac != null)
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.print,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _savedPrinterName ?? 'Unknown Printer',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _savedPrinterMac!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: _clearPrinter,
                          tooltip: 'Clear printer',
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.print_disabled, color: Colors.grey.shade400),
                        const SizedBox(width: 12),
                        Text(
                          'No printer selected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Device list header
            Row(
              children: [
                Text(
                  'Paired Bluetooth Devices',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isScanning ? null : _scanDevices,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(_isScanning ? 'Scanning...' : 'Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Scrollable device list
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ),

            if (_isScanning)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_devices.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No paired Bluetooth printers found.\nPair your printer in Android Bluetooth settings first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (_canExitWithoutPrinter) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _continueWithoutPrinter,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Continue without printer'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                itemCount: _devices.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final isSelected = _selectedDevice?.address == device.address;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color:
                            isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.print,
                        color: isSelected ? AppColors.primary : Colors.grey,
                      ),
                      title: Text(device.name ?? 'Unknown Device'),
                      subtitle: Text(device.address ?? ''),
                      trailing:
                          isSelected
                              ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              )
                              : null,
                      onTap: () => setState(() => _selectedDevice = device),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
