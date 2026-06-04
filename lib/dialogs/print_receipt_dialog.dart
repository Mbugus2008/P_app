import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/parcel_model.dart';
import '../receipts/thermal_receipt_printer.dart';
import 'printer_selector_dialog.dart';

enum _ReceiptType { cash, label, both }

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  isSelected ? theme.colorScheme.primary : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected
                        ? theme.colorScheme.primary
                        : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrintReceiptDialog extends StatefulWidget {
  final Parcel parcel;
  final VoidCallback onSkip;

  const PrintReceiptDialog({
    super.key,
    required this.parcel,
    required this.onSkip,
  });

  @override
  State<PrintReceiptDialog> createState() => _PrintReceiptDialogState();
}

class _PrintReceiptDialogState extends State<PrintReceiptDialog> {
  final ThermalReceiptPrinter _printer = ThermalReceiptPrinter();
  bool _isPrinting = false;
  String? _error;
  _ReceiptType _selectedType = _ReceiptType.cash;

  String _maskPhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return '-';
    if (phone.length <= 4) return List.filled(phone.length, '*').join();

    const maskedCount = 4;
    final available = phone.length - maskedCount;
    if (available <= 0) return List.filled(phone.length, '*').join();

    final startLen = (available / 2).floor();
    final endStart = startLen + maskedCount;
    return '${phone.substring(0, startLen)}${List.filled(maskedCount, '*').join()}${phone.substring(endStart)}';
  }

  String _partyValue(String? name, String? phone) {
    final displayName = (name ?? '').trim().isEmpty ? '-' : name!.trim();
    return '$displayName | ${_maskPhone(phone)}';
  }

  Future<void> _doPrint() async {
    switch (_selectedType) {
      case _ReceiptType.cash:
        await _printer.printParcelReceipt(widget.parcel);
        break;
      case _ReceiptType.label:
        await _printer.printParcelLabel(widget.parcel);
        break;
      case _ReceiptType.both:
        await _printer.printParcelReceipt(widget.parcel);
        await _printer.printParcelLabel(widget.parcel);
        break;
    }
  }

  Future<void> _print() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMac = prefs.getString('printer_mac');

    if (savedMac == null || savedMac.isEmpty) {
      // No saved printer — open selector
      final result = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => PrinterSelectorDialog(
              onPrint: () async {
                await _doPrint();
              },
            ),
      );
      if (result == true && mounted) {
        setState(() {
          _isPrinting = false;
          _error = null;
        });
      }
      return;
    }

    // Try to print with saved printer
    setState(() {
      _isPrinting = true;
      _error = null;
    });

    try {
      final device = BluetoothDevice('Saved Printer', savedMac);
      final connected = await _printer.connect(device);
      if (!connected) {
        // Connection failed — open selector
        if (mounted) {
          setState(() => _isPrinting = false);
          final result = await showDialog<bool>(
            context: context,
            builder:
                (ctx) => PrinterSelectorDialog(
                  onPrint: () async {
                    await _doPrint();
                  },
                ),
          );
          if (result == true && mounted) {
            setState(() {
              _isPrinting = false;
              _error = null;
            });
          }
        }
        return;
      }

      await _doPrint();
      if (mounted) {
        setState(() {
          _isPrinting = false;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Print failed: $e';
        _isPrinting = false;
      });
    }
  }

  void _skip() {
    widget.onSkip();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Print Receipt'),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(icon: const Icon(Icons.close), onPressed: _skip),
            ],
          ),
          body: Column(
            children: [
              // Receipt preview
              Expanded(
                child: Container(
                  color: Colors.grey.shade100,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        width: 320,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildReceiptPreview(parcel, theme),
                      ),
                    ),
                  ),
                ),
              ),
              // Receipt type selector
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TypeChip(
                      label: 'Cash Receipt',
                      icon: Icons.receipt_long,
                      isSelected: _selectedType == _ReceiptType.cash,
                      onTap:
                          _isPrinting
                              ? null
                              : () => setState(
                                () => _selectedType = _ReceiptType.cash,
                              ),
                    ),
                    const SizedBox(width: 8),
                    _TypeChip(
                      label: 'Parcel Label',
                      icon: Icons.label,
                      isSelected: _selectedType == _ReceiptType.label,
                      onTap:
                          _isPrinting
                              ? null
                              : () => setState(
                                () => _selectedType = _ReceiptType.label,
                              ),
                    ),
                    const SizedBox(width: 8),
                    _TypeChip(
                      label: 'Both',
                      icon: Icons.print,
                      isSelected: _selectedType == _ReceiptType.both,
                      onTap:
                          _isPrinting
                              ? null
                              : () => setState(
                                () => _selectedType = _ReceiptType.both,
                              ),
                    ),
                  ],
                ),
              ),
              // Error
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade50,
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isPrinting ? null : _skip,
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isPrinting ? null : _print,
                        icon:
                            _isPrinting
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.print),
                        label: Text(_isPrinting ? 'Printing...' : 'Print'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptPreview(Parcel parcel, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PARCEL CASH RECEIPT',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'REMBO CLASSIC SERVICES LTD',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'For all your quality services & safety',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          'KITENGELA BOOKING OFFICE',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'P.O BOX 482 - 0242 KITENGELA',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        Text(
          'MOBILE: 0757 718 594',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        Text(
          'MAIN STAGE, BLOCK B, SHOP NO. 1',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        Text(
          'MAIN OFFICE MOBILE: 0115 118 735',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        Text(
          'KULE PLAZA, SUITE NO. 25',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        Text(
          'OPPOSITE RUBIS KITENGELA',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const Divider(),
        const SizedBox(height: 6),
        _buildPreviewRow('Doc No:', parcel.Document_No ?? '-', bold: true),
        _buildPreviewRow(
          'Date:',
          DateFormat(
            'dd/MM/yyyy HH:mm',
          ).format(parcel.Date_sent ?? DateTime.now()),
        ),
        const Divider(),
        Text(
          'KITENGELA => NAIROBI',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        _buildPartyRow(
          'SENDER:',
          _partyValue(parcel.Sender_Name, parcel.Sender_Phone),
        ),
        _buildPreviewRow(
          'RECEIVER:',
          _partyValue(parcel.Receiver_Name, parcel.Receiver_Phone),
        ),
        const Divider(),
        _buildPreviewRow(
          'PAID:',
          'KES ${(parcel.Amount_Paid ?? 0.0).toStringAsFixed(0)}',
          bold: true,
        ),
        _buildPreviewRow(
          'METHOD:',
          parcel.paymentMethod == PaymentMethod.mpesa ? 'M-Pesa' : 'Cash',
        ),
        if (parcel.paymentMethod == PaymentMethod.mpesa &&
            parcel.mpesaCode?.isNotEmpty == true)
          _buildPreviewRow('MPESA CODE:', parcel.mpesaCode!),
        const Divider(),
        const Text(
          'Thank you!',
          style: TextStyle(fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPreviewRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showPrintReceiptDialog({
  required BuildContext context,
  required Parcel parcel,
  required VoidCallback onSkip,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PrintReceiptDialog(parcel: parcel, onSkip: onSkip),
  );
}
