import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import '../models/parcel_model.dart';

class ThermalReceiptPrinter {
  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;

  Future<bool> connect(BluetoothDevice device) async {
    try {
      final isConnected = await _printer.isConnected;
      if (isConnected ?? false) return true;
      return await _printer.connect(device);
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _printer.disconnect();
    } catch (_) {}
  }

  Future<bool> isConnected() async {
    try {
      return await _printer.isConnected ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> printParcelReceipt(Parcel parcel) async {
    final isConnected = await this.isConnected();
    if (!isConnected) {
      throw Exception('Printer not connected');
    }

    // Initialize printer
    _printer.printNewLine();
    _printer.printCustom('TRIMLINE PARCEL', 2, 1); // size 2, center
    _printer.printCustom('--------------------', 0, 1);
    _printer.printCustom('PARCEL RECEIPT', 1, 1);
    _printer.printNewLine();

    // Parcel info
    _printer.printCustom('Doc No: ${parcel.Document_No ?? '-'}', 1, 0);
    _printer.printCustom(
      'Date: ${DateFormat('dd MMM yyyy HH:mm').format(parcel.Date_sent ?? DateTime.now())}',
      0,
      0,
    );
    _printer.printCustom('--------------------', 0, 1);

    // Route
    _printer.printLeftRight('FROM:', parcel.From ?? '-', 0);
    _printer.printLeftRight('TO:', parcel.To ?? '-', 0);
    _printer.printCustom('--------------------', 0, 1);

    // Sender
    _printer.printCustom('SENDER', 1, 0);
    _printer.printLeftRight('Name:', parcel.Sender_Name ?? '-', 0);
    _printer.printLeftRight('Phone:', parcel.Sender_Phone ?? '-', 0);
    _printer.printLeftRight('ID:', parcel.Sender_ID ?? '-', 0);
    _printer.printCustom('--------------------', 0, 1);

    // Receiver
    _printer.printCustom('RECEIVER', 1, 0);
    _printer.printLeftRight('Name:', parcel.Receiver_Name ?? '-', 0);
    _printer.printLeftRight('Phone:', parcel.Receiver_Phone ?? '-', 0);
    _printer.printLeftRight('ID:', parcel.Receiver_ID ?? '-', 0);
    _printer.printCustom('--------------------', 0, 1);

    // Items
    if (parcel.parcelDetails.isNotEmpty) {
      _printer.printCustom('ITEMS', 1, 0);
      double total = 0;
      for (final detail in parcel.parcelDetails) {
        final desc = (detail.Description ?? 'Item').substring(
          0,
          detail.Description!.length > 12 ? 12 : detail.Description!.length,
        );
        final amt = detail.Amount ?? 0.0;
        total += amt;
        _printer.printLeftRight(desc, 'KES ${amt.toStringAsFixed(0)}', 0);
      }
      _printer.printCustom('--------------------', 0, 1);
      _printer.printLeftRight('TOTAL:', 'KES ${total.toStringAsFixed(0)}', 1);
    }

    // Payment
    _printer.printCustom('--------------------', 0, 1);
    _printer.printLeftRight(
      'PAID:',
      'KES ${(parcel.Amount_Paid ?? 0.0).toStringAsFixed(0)}',
      1,
    );
    _printer.printLeftRight(
      'METHOD:',
      parcel.paymentMethod == PaymentMethod.mpesa ? 'M-Pesa' : 'Cash',
      0,
    );
    if (parcel.paymentMethod == PaymentMethod.mpesa &&
        parcel.mpesaCode?.isNotEmpty == true) {
      _printer.printLeftRight('MPESA CODE:', parcel.mpesaCode!, 0);
    }
    _printer.printCustom('--------------------', 0, 1);

    // QR Code
    if (parcel.Document_No?.isNotEmpty == true) {
      _printer.printQRcode(parcel.Document_No!, 200, 200, 1);
      _printer.printNewLine();
    }

    // Footer
    _printer.printCustom('Thank you!', 0, 1);
    _printer.printCustom('--------------------', 0, 1);
    _printer.printNewLine();
    _printer.printNewLine();
    _printer.paperCut();
  }

  Future<void> printTest() async {
    final isConnected = await this.isConnected();
    if (!isConnected) {
      throw Exception('Printer not connected');
    }
    _printer.printNewLine();
    _printer.printCustom('TRIMLINE PARCEL', 2, 1);
    _printer.printCustom('Test Print OK', 1, 1);
    _printer.printCustom('--------------------', 0, 1);
    _printer.printNewLine();
    _printer.printNewLine();
    _printer.paperCut();
  }
}
