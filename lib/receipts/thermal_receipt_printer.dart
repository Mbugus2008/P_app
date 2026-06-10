import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';

import '../models/parcel_model.dart';

class ThermalReceiptPrinter {
  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;
  static const int _lineWidthChars = 32;
  static final String _divider = '-' * _lineWidthChars;

  static const List<String> _receiptHeaderLines = [
    'REMBO CLASSIC SERVICES LTD',
    'For all your quality services & safety',
    'KITENGELA BOOKING OFFICE',
    'P.O BOX 482 - 0242 KITENGELA',
    'MOBILE: 0757 718 594',
    'MAIN STAGE, BLOCK B, SHOP NO. 1',
    'MAIN OFFICE MOBILE: 0115 118 735',
    'BETTY BUSINESS CENTRE',
    'OPP. KITENGELA MALL',
    '3RD FLOOR, RM 313',
  ];

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
    return '${displayName.toUpperCase()} | ${_maskPhone(phone)}';
  }

  // Pads the label to a fixed width so every value starts at the same column.
  static const int _labelWidth = 10;
  String _labelValue(String label, String value) {
    final left = label.toUpperCase().padRight(_labelWidth);
    final maxValueLen = _lineWidthChars - _labelWidth;
    var right = value;
    if (maxValueLen > 0 && right.length > maxValueLen) {
      right = right.substring(0, maxValueLen);
    }
    return '$left$right';
  }

  // Wraps long text across multiple lines to fit the receipt width.
  List<String> _wrapText(String text, {int width = _lineWidthChars}) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (current.isEmpty) {
        current = word;
      } else if ((current.length + 1 + word.length) <= width) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [text] : lines;
  }

  Future<void> printParcelReceipt(Parcel parcel) async {
    final isConnected = await this.isConnected();
    if (!isConnected) {
      throw Exception('Printer not connected');
    }

    // Header
    _printer.printNewLine();
    _printer.printCustom(_receiptHeaderLines.first, 1, 1);
    _printer.printCustom(_receiptHeaderLines[1], 1, 1);
    for (final line in _receiptHeaderLines.skip(2)) {
      _printer.printCustom(line, 0, 1);
    }
    _printer.printCustom(_divider, 0, 1);

    // Parcel info
    _printer.printCustom(_labelValue('DOC:', parcel.Document_No ?? '-'), 0, 0);
    _printer.printCustom(
      _labelValue(
        'DATE:',
        DateFormat(
          'dd/MM/yyyy HH:mm',
        ).format(parcel.Date_sent ?? DateTime.now()),
      ),
      0,
      0,
    );
    _printer.printCustom(_divider, 0, 1);

    // Route and parties
    _printer.printCustom(_labelValue('ROUTE:', 'KITENGELA => NAIROBI'), 0, 0);
    _printer.printCustom(
      _labelValue(
        'SENDER:',
        _partyValue(parcel.Sender_Name, parcel.Sender_Phone),
      ),
      0,
      0,
    );
    _printer.printCustom(
      _labelValue(
        'RECEIVER:',
        _partyValue(parcel.Receiver_Name, parcel.Receiver_Phone),
      ),
      0,
      0,
    );
    _printer.printCustom(_divider, 0, 1);

    // Parcel details
    final hasDetailNote = parcel.Details?.trim().isNotEmpty == true;
    final detailItems = parcel.parcelDetails;
    if (hasDetailNote || detailItems.isNotEmpty) {
      _printer.printCustom('DETAILS:', 0, 0);
      if (hasDetailNote) {
        for (final line in _wrapText(parcel.Details!.trim())) {
          _printer.printCustom(line, 0, 0);
        }
      }
      for (final item in detailItems) {
        final qty = item.No_Of_Items ?? 0;
        final desc = (item.Description ?? '').trim();
        final amount = item.Amount ?? 0.0;
        final label = '${qty > 0 ? '$qty x ' : ''}${desc.isEmpty ? '-' : desc}';
        for (final line in _wrapText(
          amount > 0 ? '$label  KES ${amount.toStringAsFixed(0)}' : label,
        )) {
          _printer.printCustom(line, 0, 0);
        }
        final remarks = (item.Remarks ?? '').trim();
        if (remarks.isNotEmpty) {
          for (final line in _wrapText('  ($remarks)')) {
            _printer.printCustom(line, 0, 0);
          }
        }
      }
      _printer.printCustom(_divider, 0, 1);
    }

    // Payment
    final isPayLater =
        parcel.paymentMethod == PaymentMethod.pending || parcel.Paid != true;
    final amountText = 'KES ${(parcel.Amount_Paid ?? 0.0).toStringAsFixed(0)}';
    if (isPayLater) {
      _printer.printCustom(_labelValue('TO PAY:', amountText), 0, 0);
      _printer.printCustom(_labelValue('STATUS:', 'PAY ON COLLECTION'), 0, 0);
    } else {
      _printer.printCustom(_labelValue('PAID:', amountText), 0, 0);
      _printer.printCustom(
        _labelValue(
          'METHOD:',
          parcel.paymentMethod == PaymentMethod.mpesa ? 'M-Pesa' : 'Cash',
        ),
        0,
        0,
      );
      if (parcel.paymentMethod == PaymentMethod.mpesa &&
          parcel.mpesaCode?.isNotEmpty == true) {
        _printer.printCustom(_labelValue('MPESA:', parcel.mpesaCode!), 0, 0);
      }
    }
    _printer.printCustom(_divider, 0, 1);

    // Disclaimer
    _printer.printCustom('Cash not carried — company not liable for cash loss.', 0, 0);
    _printer.printCustom('Goods at owners risk. Conditions at offices.', 0, 0);
    _printer.printCustom('Insure goods over KSh 1,000.', 0, 1);

    // Footer
    _printer.printNewLine();
    _printer.printCustom('Thank you for your business!', 0, 1);
    _printer.printCustom(_divider, 0, 1);
    _printer.printNewLine();
    _printer.printNewLine();
    _printer.paperCut();
  }

  Future<void> printParcelLabel(Parcel parcel) async {
    final isConnected = await this.isConnected();
    if (!isConnected) {
      throw Exception('Printer not connected');
    }

    final docNo = parcel.Document_No ?? '-';

    // Header - company info
    _printer.printNewLine();
    _printer.printCustom(_receiptHeaderLines[0], 1, 1);
    for (final line in _receiptHeaderLines.skip(1)) {
      _printer.printCustom(line, 0, 1);
    }
    _printer.printCustom(_divider, 0, 1);

    // Main title - "PARCEL LABEL" centred and bigger
    _printer.printCustom('PARCEL LABEL', 2, 1);
    _printer.printCustom(_divider, 0, 1);

    // Doc No - extra large, centred and bold
    _printer.printCustom(docNo.toUpperCase(), 3, 1);
    _printer.printCustom(_divider, 0, 1);

    // Parcel info
    _printer.printCustom(
      _labelValue(
        'DATE:',
        DateFormat(
          'dd/MM/yyyy HH:mm',
        ).format(parcel.Date_sent ?? DateTime.now()),
      ),
      0,
      0,
    );
    _printer.printCustom(_divider, 0, 1);

    // Route
    _printer.printCustom(_labelValue('ROUTE:', 'KITENGELA => NAIROBI'), 0, 0);
    _printer.printCustom(_divider, 0, 1);

    // Parties
    _printer.printCustom(
      _labelValue(
        'SENDER:',
        _partyValue(parcel.Sender_Name, parcel.Sender_Phone),
      ),
      0,
      0,
    );
    _printer.printCustom(
      _labelValue(
        'RECEIVER:',
        _partyValue(parcel.Receiver_Name, parcel.Receiver_Phone),
      ),
      0,
      0,
    );
    _printer.printCustom(_divider, 0, 1);

    // Parcel details
    final hasDetailNote = parcel.Details?.trim().isNotEmpty == true;
    final detailItems = parcel.parcelDetails;
    if (hasDetailNote || detailItems.isNotEmpty) {
      _printer.printCustom('DETAILS:', 0, 0);
      if (hasDetailNote) {
        for (final line in _wrapText(parcel.Details!.trim())) {
          _printer.printCustom(line, 0, 0);
        }
      }
      for (final item in detailItems) {
        final qty = item.No_Of_Items ?? 0;
        final desc = (item.Description ?? '').trim();
        final amount = item.Amount ?? 0.0;
        final label = '${qty > 0 ? '$qty x ' : ''}${desc.isEmpty ? '-' : desc}';
        for (final line in _wrapText(
          amount > 0 ? '$label  KES ${amount.toStringAsFixed(0)}' : label,
        )) {
          _printer.printCustom(line, 0, 0);
        }
        final remarks = (item.Remarks ?? '').trim();
        if (remarks.isNotEmpty) {
          for (final line in _wrapText('  ($remarks)')) {
            _printer.printCustom(line, 0, 0);
          }
        }
      }
      _printer.printCustom(_divider, 0, 1);
    }

    // Payment
    final isPayLater =
        parcel.paymentMethod == PaymentMethod.pending || parcel.Paid != true;
    final amountText = 'KES ${(parcel.Amount_Paid ?? 0.0).toStringAsFixed(0)}';
    if (isPayLater) {
      _printer.printCustom(_labelValue('TO PAY:', amountText), 0, 0);
      _printer.printCustom(_labelValue('STATUS:', 'PAY ON COLLECTION'), 0, 0);
    } else {
      _printer.printCustom(_labelValue('PAID:', amountText), 0, 0);
      _printer.printCustom(
        _labelValue(
          'METHOD:',
          parcel.paymentMethod == PaymentMethod.mpesa ? 'M-Pesa' : 'Cash',
        ),
        0,
        0,
      );
      if (parcel.paymentMethod == PaymentMethod.mpesa &&
          parcel.mpesaCode?.isNotEmpty == true) {
        _printer.printCustom(_labelValue('MPESA:', parcel.mpesaCode!), 0, 0);
      }
    }

    _printer.printCustom(_divider, 0, 1);
    _printer.printNewLine();
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
    _printer.printCustom(_receiptHeaderLines.first, 1, 1);
    _printer.printCustom(_receiptHeaderLines[1], 1, 1);
    _printer.printCustom('Test Print OK', 1, 1);
    _printer.printCustom(_divider, 0, 1);
    _printer.printNewLine();
    _printer.printNewLine();
    _printer.paperCut();
  }
}
