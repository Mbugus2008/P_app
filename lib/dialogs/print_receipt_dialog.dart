import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parcel_model.dart';
import '../receipts/thermal_receipt_printer.dart';
import 'printer_selector_dialog.dart';

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

  Future<void> _print() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMac = prefs.getString('printer_mac');

    if (savedMac == null || savedMac.isEmpty) {
      // No saved printer — open selector
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => PrinterSelectorDialog(
          onPrint: () async {
            await _printer.printParcelReceipt(widget.parcel);
          },
        ),
      );
      if (result == true && mounted) {
        Navigator.of(context).pop(true);
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
            builder: (ctx) => PrinterSelectorDialog(
              onPrint: () async {
                await _printer.printParcelReceipt(widget.parcel);
              },
            ),
          );
          if (result == true && mounted) {
            Navigator.of(context).pop(true);
          }
        }
        return;
      }

      await _printer.printParcelReceipt(widget.parcel);
      if (mounted) Navigator.of(context).pop(true);
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
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _skip,
              ),
            ],
          ),
          body: Column(
            children: [
              // Receipt preview
              Expanded(
                child: Container(
                  color: Colors.grey.shade100,
                  padding: const EdgeInsets.all(16),
                  child: Center(
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
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'TRIMLINE PARCEL',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const Divider(),
        Text(
          'PARCEL RECEIPT',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _buildPreviewRow('Doc No:', parcel.Document_No ?? '-', bold: true),
        _buildPreviewRow('Date:', parcel.Date_sent?.toString().substring(0, 16) ?? '-'),
        const Divider(),
        _buildPreviewRow('FROM:', parcel.From ?? '-'),
        _buildPreviewRow('TO:', parcel.To ?? '-'),
        const Divider(),
        Text('SENDER', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
        _buildPreviewRow('Name:', parcel.Sender_Name ?? '-'),
        _buildPreviewRow('Phone:', parcel.Sender_Phone ?? '-'),
        const Divider(),
        Text('RECEIVER', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
        _buildPreviewRow('Name:', parcel.Receiver_Name ?? '-'),
        _buildPreviewRow('Phone:', parcel.Receiver_Phone ?? '-'),
        const Divider(),
        if (parcel.parcelDetails.isNotEmpty) ...[
          Text('ITEMS', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
          ...parcel.parcelDetails.map((d) => _buildPreviewRow(
                d.Description ?? 'Item',
                'KES ${(d.Amount ?? 0.0).toStringAsFixed(0)}',
              )),
          const Divider(),
        ],
        _buildPreviewRow(
          'PAID:',
          'KES ${(parcel.Amount_Paid ?? 0.0).toStringAsFixed(0)}',
          bold: true,
        ),
        _buildPreviewRow(
          'METHOD:',
          parcel.paymentMethod == PaymentMethod.mpesa ? 'M-Pesa' : 'Cash',
        ),
        if (parcel.paymentMethod == PaymentMethod.mpesa && parcel.mpesaCode?.isNotEmpty == true)
          _buildPreviewRow('MPESA CODE:', parcel.mpesaCode!),
        const Divider(),
        const Text('Thank you!', style: TextStyle(fontStyle: FontStyle.italic)),
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
