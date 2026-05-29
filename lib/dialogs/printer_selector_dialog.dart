import 'dart:async';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../receipts/thermal_receipt_printer.dart';

class PrinterSelectorDialog extends StatefulWidget {
  final VoidCallback? onPrint;

  const PrinterSelectorDialog({super.key, this.onPrint});

  @override
  State<PrinterSelectorDialog> createState() => _PrinterSelectorDialogState();
}

class _PrinterSelectorDialogState extends State<PrinterSelectorDialog> {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  final ThermalReceiptPrinter _printer = ThermalReceiptPrinter();

  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isPrinting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _scanDevices();
  }

  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('printer_name');
    final savedAddress = prefs.getString('printer_mac');
    if (savedAddress != null) {
      setState(() {
        _selectedDevice = BluetoothDevice(
          (savedName?.trim().isNotEmpty ?? false) ? savedName : 'Saved Printer',
          savedAddress,
        );
      });
    }
  }

  Future<void> _savePrinter(String? name, String? address) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmedAddress = address?.trim();
    final trimmedName = name?.trim();

    if (trimmedAddress != null && trimmedAddress.isNotEmpty) {
      await prefs.setString('printer_mac', trimmedAddress);
      await prefs.setString(
        'printer_name',
        (trimmedName != null && trimmedName.isNotEmpty)
            ? trimmedName
            : 'Saved Printer',
      );
    } else {
      await prefs.remove('printer_name');
      await prefs.remove('printer_mac');
    }
  }

  Future<void> _scanDevices() async {
    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      final bonded = await _bluetooth.getBondedDevices();
      setState(() {
        _devices = bonded;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to scan: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _connectAndPrint() async {
    if (_selectedDevice == null) {
      setState(() {
        _error = 'Please select a printer first before saving.';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    final connected = await _printer.connect(_selectedDevice!);
    if (!connected) {
      setState(() {
        _error = 'Failed to connect to ${_selectedDevice!.name}';
        _isConnecting = false;
      });
      return;
    }

    await _savePrinter(_selectedDevice!.name, _selectedDevice!.address);

    if (widget.onPrint != null) {
      setState(() {
        _isConnecting = false;
        _isPrinting = true;
      });

      try {
        widget.onPrint!();
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        setState(() {
          _error = 'Print failed: $e';
          _isPrinting = false;
        });
      }
    } else {
      setState(() => _isConnecting = false);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _testPrint() async {
    if (_selectedDevice == null) {
      setState(() {
        _error = 'Please select a printer first before saving.';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    final connected = await _printer.connect(_selectedDevice!);
    if (!connected) {
      setState(() {
        _error = 'Failed to connect';
        _isConnecting = false;
      });
      return;
    }

    await _savePrinter(_selectedDevice!.name, _selectedDevice!.address);

    try {
      await _printer.printTest();
      setState(() => _isConnecting = false);
    } catch (e) {
      setState(() {
        _error = 'Test print failed: $e';
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Bluetooth Printer'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(8),
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
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_devices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No paired Bluetooth printers found.\nPlease pair your printer in Android Bluetooth settings.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final isSelected =
                        _selectedDevice?.address == device.address;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.print,
                        color: isSelected ? Colors.green : Colors.grey,
                      ),
                      title: Text(device.name ?? 'Unknown'),
                      subtitle: Text(device.address ?? ''),
                      trailing:
                          isSelected
                              ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                              : null,
                      onTap: () => setState(() => _selectedDevice = device),
                      selected: isSelected,
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _isScanning ? null : _scanDevices,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(_isScanning ? 'Scanning...' : 'Refresh'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (_selectedDevice != null)
          TextButton(
            onPressed: _isConnecting || _isPrinting ? null : _testPrint,
            child: Text(_isConnecting ? 'Connecting...' : 'Test Print'),
          ),
        ElevatedButton(
          onPressed:
              (_selectedDevice == null || _isConnecting || _isPrinting)
                  ? null
                  : _connectAndPrint,
          child: Text(
            _isConnecting
                ? 'Connecting...'
                : _isPrinting
                ? 'Printing...'
                : 'Print Receipt',
          ),
        ),
      ],
    );
  }
}
