import 'package:trimline_parcel/models/Parcel_Details.dart';

enum WhoToPay { Sender, Receiver }

typedef Who_to_Pay = WhoToPay;

enum ParcelStatus { pending, inTransit, received, collected }

enum PaymentMethod { cash, mpesa, pending }

class Parcel {
  String? Document_No;
  String? Batch_No;
  DateTime? Date_sent;
  String? Sender_Name;
  String? Sender_ID;
  String? Sender_Phone;
  String? From;
  String? To;
  String? Receiver_Name;
  String? Receiver_ID;
  String? Receiver_Phone;
  ParcelStatus? Status;
  String? Driver;
  String? Vehicle;
  WhoToPay? Who_to_Pay;
  double? Amount_Paid;
  bool? Paid;
  PaymentMethod? paymentMethod;
  String? mpesaCode;
  DateTime? Date_Collected;
  DateTime? Date_Delivered;
  DateTime? Out_For_Delivery_Time;
  DateTime? Date_Returned;
  String? Notes;
  bool isSynced;
  bool receiptPrinted;
  List<Parcel_Details> parcelDetails;

  Parcel({
    this.Document_No,
    this.Batch_No,
    this.Date_sent,
    this.Sender_Name,
    this.Sender_ID,
    this.Sender_Phone,
    this.From,
    this.To,
    this.Receiver_Name,
    this.Receiver_ID,
    this.Receiver_Phone,
    this.Status,
    this.Driver,
    this.Vehicle,
    this.Who_to_Pay = WhoToPay.Sender,
    this.Amount_Paid = 0,
    this.Paid = false,
    this.paymentMethod = PaymentMethod.pending,
    this.mpesaCode,
    this.Date_Collected,
    this.Date_Delivered,
    this.Out_For_Delivery_Time,
    this.Date_Returned,
    this.Notes,
    this.isSynced = false,
    this.receiptPrinted = false,
    List<Parcel_Details>? parcelDetails,
  }) : parcelDetails = parcelDetails ?? <Parcel_Details>[];

  Map<String, dynamic> toJson() {
    return {
      'Document_No': Document_No,
      'Batch_No': Batch_No,
      'Date_sent': Date_sent?.toIso8601String(),
      'Sender_Name': Sender_Name,
      'Sender_ID': Sender_ID,
      'Sender_Phone': Sender_Phone,
      'From': From,
      'To': To,
      'Receiver_Name': Receiver_Name,
      'Receiver_ID': Receiver_ID,
      'Receiver_Phone': Receiver_Phone,
      'Status': Status?.name,
      'Driver': Driver,
      'Vehicle': Vehicle,
      'Who_to_Pay': Who_to_Pay?.name,
      'Amount_Paid': Amount_Paid,
      'Paid': Paid,
      'Payment_Method': paymentMethod?.name,
      'Mpesa_Code': mpesaCode,
      'Receipt_Printed': receiptPrinted,
      'Date_Collected': Date_Collected?.toIso8601String(),
      'Date_Delivered': Date_Delivered?.toIso8601String(),
      'Out_For_Delivery_Time': Out_For_Delivery_Time?.toIso8601String(),
      'Date_Returned': Date_Returned?.toIso8601String(),
      'Notes': Notes,
      'Is_Synced': isSynced,
      'Receipt_Printed': receiptPrinted,
      'Details': parcelDetails.map((d) => d.toJson()).toList(),
    };
  }

  factory Parcel.fromJson(Map<String, dynamic> json) {
    dynamic read(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key)) return json[key];
      }
      return null;
    }

    return Parcel(
      Document_No: read(['Document_No', 'document_No', 'documentNo']) as String?,
      Batch_No: read(['Batch_No', 'batch_No', 'batchNo']) as String?,
      Date_sent: _parseDate(read(['Date_sent', 'date_sent', 'dateSent'])),
      Sender_Name:
          read(['Sender_Name', 'sender_Name', 'senderName']) as String?,
      Sender_ID: read(['Sender_ID', 'sender_ID', 'senderId']) as String?,
      Sender_Phone:
          read(['Sender_Phone', 'sender_Phone', 'senderPhone']) as String?,
      From: read(['From', 'from']) as String?,
      To: read(['To', 'to']) as String?,
      Receiver_Name:
          read(['Receiver_Name', 'receiver_Name', 'receiverName']) as String?,
      Receiver_ID:
          read(['Receiver_ID', 'receiver_ID', 'receiverId']) as String?,
      Receiver_Phone:
          read(['Receiver_Phone', 'receiver_Phone', 'receiverPhone'])
              as String?,
      Status: _parseStatus(read(['Status', 'status'])),
      Driver: read(['Driver', 'driver']) as String?,
      Vehicle: read(['Vehicle', 'vehicle']) as String?,
      Who_to_Pay: _parseWhoToPay(
        read(['Who_to_Pay', 'who_to_Pay', 'whoToPay']),
      ),
      Amount_Paid:
          (read(['Amount_Paid', 'amount_Paid', 'amountPaid']) as num?)
              ?.toDouble(),
      Paid: _parseBool(read(['Paid', 'paid'])),
      paymentMethod: _parsePaymentMethod(
        read(['Payment_Method', 'payment_Method', 'paymentMethod']),
      ),
      mpesaCode: read(['Mpesa_Code', 'mpesa_Code', 'mpesaCode'])?.toString(),
      Date_Collected: _parseDate(
        read(['Date_Collected', 'date_Collected', 'dateCollected']),
      ),
      Date_Delivered: _parseDate(
        read(['Date_Delivered', 'date_Delivered', 'dateDelivered']),
      ),
      Out_For_Delivery_Time: _parseDate(
        read([
          'Out_For_Delivery_Time',
          'out_For_Delivery_Time',
          'outForDeliveryTime',
        ]),
      ),
      Date_Returned: _parseDate(
        read(['Date_Returned', 'date_Returned', 'dateReturned']),
      ),
      Notes: read(['Notes', 'notes']) as String?,
      isSynced: _parseBool(read(['Is_Synced', 'is_Synced', 'isSynced'])),
      receiptPrinted: _parseBool(
        read(['Receipt_Printed', 'receipt_Printed', 'receiptPrinted']),
      ),
      parcelDetails:
          (read(['Details', 'details']) as List?)
              ?.map(
                (item) => Parcel_Details.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          <Parcel_Details>[],
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'Document_No': Document_No,
      'Batch_No': Batch_No,
      'Date_sent': Date_sent?.toIso8601String(),
      'Sender_Name': Sender_Name,
      'Sender_ID': Sender_ID,
      'Sender_Phone': Sender_Phone,
      'From_Location': From,
      'To_Location': To,
      'Receiver_Name': Receiver_Name,
      'Receiver_ID': Receiver_ID,
      'Receiver_Phone': Receiver_Phone,
      'Status': Status?.name,
      'Driver': Driver,
      'Vehicle': Vehicle,
      'WhoToPay': Who_to_Pay?.name,
      'Amount_Paid': Amount_Paid,
      'Paid': (Paid ?? false) ? 1 : 0,
      'Payment_Method': paymentMethod?.name,
      'Mpesa_Code': mpesaCode,
      'Date_Collected': Date_Collected?.toIso8601String(),
      'Date_Delivered': Date_Delivered?.toIso8601String(),
      'Out_For_Delivery_Time': Out_For_Delivery_Time?.toIso8601String(),
      'Date_Returned': Date_Returned?.toIso8601String(),
      'Description': Notes,
      'Is_Synced': (isSynced) ? 1 : 0,
      'Receipt_Printed': (receiptPrinted) ? 1 : 0,
    };
  }

  factory Parcel.fromDbMap(Map<String, dynamic> map) {
    return Parcel(
      Document_No: map['Document_No'] as String?,
      Batch_No: map['Batch_No'] as String?,
      Date_sent: _parseDate(map['Date_sent']),
      Sender_Name: map['Sender_Name'] as String?,
      Sender_ID: map['Sender_ID'] as String?,
      Sender_Phone: map['Sender_Phone'] as String?,
      From: map['From_Location'] as String?,
      To: map['To_Location'] as String?,
      Receiver_Name: map['Receiver_Name'] as String?,
      Receiver_ID: map['Receiver_ID'] as String?,
      Receiver_Phone: map['Receiver_Phone'] as String?,
      Status: _parseStatus(map['Status']),
      Driver: map['Driver'] as String?,
      Vehicle: map['Vehicle'] as String?,
      Who_to_Pay: _parseWhoToPay(map['WhoToPay']),
      Amount_Paid: (map['Amount_Paid'] as num?)?.toDouble(),
      Paid: (map['Paid'] as int? ?? 0) == 1,
      paymentMethod: _parsePaymentMethod(map['Payment_Method']),
      mpesaCode: map['Mpesa_Code']?.toString(),
      Date_Collected: _parseDate(map['Date_Collected']),
      Date_Delivered: _parseDate(map['Date_Delivered']),
      Out_For_Delivery_Time: _parseDate(map['Out_For_Delivery_Time']),
      Date_Returned: _parseDate(map['Date_Returned']),
      Notes: map['Description'] as String?,
      isSynced: (map['Is_Synced'] as int? ?? 0) == 1,
      receiptPrinted: (map['Receipt_Printed'] as int? ?? 0) == 1,
    );
  }

  /// Serializes to NAV-compatible JSON for API sync.
  /// Maps mobile status values to NAV enum values.
  Map<String, dynamic> toNavJson() {
    int navStatus;
    switch (Status) {
      case ParcelStatus.pending:
        navStatus = 0;
        break;
      case ParcelStatus.inTransit:
        navStatus = 1;
        break;
      case ParcelStatus.received:
        navStatus = 2;
        break;
      case ParcelStatus.collected:
        navStatus = 3;
        break;
      default:
        navStatus = 0;
    }

    return {
      'Document_No': Document_No,
      'Batch_No': Batch_No,
      'Date_sent': Date_sent?.toIso8601String(),
      'Sender_Name': Sender_Name,
      'Sender_ID': Sender_ID,
      'Sender_Phone': Sender_Phone,
      'From': From,
      'To': To,
      'Receiver_Name': Receiver_Name,
      'Receiver_ID': Receiver_ID,
      'Receiver_Phone': Receiver_Phone,
      'Status': navStatus,
      'Driver': Driver,
      'Vehicle': Vehicle,
      'Who_to_Pay': Who_to_Pay == WhoToPay.Receiver ? 1 : 0,
      'Amount_Paid': Amount_Paid,
      'Paid': Paid,
      'Payment_Method': _toNavPaymentMethod(paymentMethod),
      'Mpesa_Code': mpesaCode,
      'Date_Collected': Date_Collected?.toIso8601String(),
      'Date_Delivered': Date_Delivered?.toIso8601String(),
      'Out_For_Delivery_Time': Out_For_Delivery_Time?.toIso8601String(),
      'Date_Returned': Date_Returned?.toIso8601String(),
      'Notes': Notes,
    };
  }

  static String? _toNavPaymentMethod(PaymentMethod? method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.mpesa:
        return 'M-Pesa';
      case PaymentMethod.pending:
        return 'Pending';
      default:
        return null;
    }
  }

  Parcel copyWith({
    String? Document_No,
    String? Batch_No,
    DateTime? Date_sent,
    String? Sender_Name,
    String? Sender_ID,
    String? Sender_Phone,
    String? From,
    String? To,
    String? Receiver_Name,
    String? Receiver_ID,
    String? Receiver_Phone,
    ParcelStatus? Status,
    String? Driver,
    String? Vehicle,
    WhoToPay? Who_to_Pay,
    double? Amount_Paid,
    bool? Paid,
    PaymentMethod? paymentMethod,
    String? mpesaCode,
    DateTime? Date_Collected,
    DateTime? Date_Delivered,
    DateTime? Out_For_Delivery_Time,
    DateTime? Date_Returned,
    String? Notes,
    bool? isSynced,
    bool? receiptPrinted,
    List<Parcel_Details>? parcelDetails,
  }) {
    return Parcel(
      Document_No: Document_No ?? this.Document_No,
      Batch_No: Batch_No ?? this.Batch_No,
      Date_sent: Date_sent ?? this.Date_sent,
      Sender_Name: Sender_Name ?? this.Sender_Name,
      Sender_ID: Sender_ID ?? this.Sender_ID,
      Sender_Phone: Sender_Phone ?? this.Sender_Phone,
      From: From ?? this.From,
      To: To ?? this.To,
      Receiver_Name: Receiver_Name ?? this.Receiver_Name,
      Receiver_ID: Receiver_ID ?? this.Receiver_ID,
      Receiver_Phone: Receiver_Phone ?? this.Receiver_Phone,
      Status: Status ?? this.Status,
      Driver: Driver ?? this.Driver,
      Vehicle: Vehicle ?? this.Vehicle,
      Who_to_Pay: Who_to_Pay ?? this.Who_to_Pay,
      Amount_Paid: Amount_Paid ?? this.Amount_Paid,
      Paid: Paid ?? this.Paid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      mpesaCode: mpesaCode ?? this.mpesaCode,
      Date_Collected: Date_Collected ?? this.Date_Collected,
      Date_Delivered: Date_Delivered ?? this.Date_Delivered,
      Out_For_Delivery_Time:
          Out_For_Delivery_Time ?? this.Out_For_Delivery_Time,
      Date_Returned: Date_Returned ?? this.Date_Returned,
      Notes: Notes ?? this.Notes,
      isSynced: isSynced ?? this.isSynced,
      receiptPrinted: receiptPrinted ?? this.receiptPrinted,
      parcelDetails: parcelDetails ?? this.parcelDetails,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static ParcelStatus _parseStatus(dynamic value) {
    if (value is num) {
      switch (value.toInt()) {
        case 1:
          return ParcelStatus.inTransit;
        case 2:
          return ParcelStatus.received;
        case 3:
          return ParcelStatus.collected;
        default:
          return ParcelStatus.pending;
      }
    }

    final raw = value?.toString().trim().toLowerCase() ?? '';
    switch (raw) {
      case 'open':
      case 'pending':
      case '0':
        return ParcelStatus.pending;
      case 'intransit':
      case 'in_transist':
      case 'in_transit':
      case 'outfordelivery':
      case '1':
        return ParcelStatus.inTransit;
      case 'waiting_collection':
      case 'waitingcollection':
      case 'received':
      case 'delivered':
      case '2':
        return ParcelStatus.received;
      case 'collected':
      case 'returned':
      case '3':
        return ParcelStatus.collected;
      default:
        return ParcelStatus.pending;
    }
  }

  static WhoToPay _parseWhoToPay(dynamic value) {
    if (value is num) {
      return value.toInt() == 1 ? WhoToPay.Receiver : WhoToPay.Sender;
    }

    switch (value?.toString().toLowerCase()) {
      case '1':
      case 'receiver':
        return WhoToPay.Receiver;
      default:
        return WhoToPay.Sender;
    }
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final raw = value.toString().trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  static PaymentMethod _parsePaymentMethod(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'mpesa':
      case 'm-pesa':
        return PaymentMethod.mpesa;
      default:
        return PaymentMethod.pending;
    }
  }
}
