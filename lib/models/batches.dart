import 'dart:convert';

enum BatchStatus { pending, inTransit, received, collected }

class Batches {
  Batches({
    this.batchNo,
    this.date,
    this.user,
    this.userAgentCode,
    this.userName,
    this.status = BatchStatus.pending,
    List<String>? parcelDocumentNos,
    this.parcelCount,
    this.totalAmount,
    this.sourceLocation,
    this.destinationLocation,
    this.fromLocation,
    this.toLocation,
    this.vehicle,
    this.driver,
    this.dispatchDateTime,
    this.receivedDateTime,
    this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.syncStatus,
  }) : parcelDocumentNos = parcelDocumentNos ?? <String>[];

  String? batchNo;
  DateTime? date;
  String? user;
  String? userAgentCode;
  String? userName;
  BatchStatus? status;
  List<String> parcelDocumentNos;
  int? parcelCount;
  double? totalAmount;
  String? sourceLocation;
  String? destinationLocation;
  String? fromLocation;
  String? toLocation;
  String? vehicle;
  String? driver;
  DateTime? dispatchDateTime;
  DateTime? receivedDateTime;
  DateTime? createdAt;
  DateTime? updatedAt;
  bool isSynced;
  String? syncStatus;

  Batches copyWith({
    String? batchNo,
    DateTime? date,
    String? user,
    String? userAgentCode,
    String? userName,
    BatchStatus? status,
    List<String>? parcelDocumentNos,
    int? parcelCount,
    double? totalAmount,
    String? sourceLocation,
    String? destinationLocation,
    String? fromLocation,
    String? toLocation,
    String? vehicle,
    String? driver,
    DateTime? dispatchDateTime,
    DateTime? receivedDateTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    String? syncStatus,
  }) {
    return Batches(
      batchNo: batchNo ?? this.batchNo,
      date: date ?? this.date,
      user: user ?? this.user,
      userAgentCode: userAgentCode ?? this.userAgentCode,
      userName: userName ?? this.userName,
      status: status ?? this.status,
      parcelDocumentNos: parcelDocumentNos ?? this.parcelDocumentNos,
      parcelCount: parcelCount ?? this.parcelCount,
      totalAmount: totalAmount ?? this.totalAmount,
      sourceLocation: sourceLocation ?? this.sourceLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      vehicle: vehicle ?? this.vehicle,
      driver: driver ?? this.driver,
      dispatchDateTime: dispatchDateTime ?? this.dispatchDateTime,
      receivedDateTime: receivedDateTime ?? this.receivedDateTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Batch_No': batchNo,
      'Date': date?.toIso8601String(),
      'User': user,
      'User_Agent_Code': userAgentCode,
      'User_Name': userName,
      'Status': status?.name,
      'Parcel_Document_Nos': parcelDocumentNos,
      'Parcel_Count': parcelCount ?? parcelDocumentNos.length,
      'Total_Amount': totalAmount,
      'Source': sourceLocation ?? fromLocation,
      'Destination': destinationLocation ?? toLocation,
      'From_Location': fromLocation ?? sourceLocation,
      'To_Location': toLocation ?? destinationLocation,
      'Vehicle': vehicle,
      'Driver': driver,
      'Dispatch_DateTime': dispatchDateTime?.toIso8601String(),
      'Received_DateTime': receivedDateTime?.toIso8601String(),
      'Created_At': createdAt?.toIso8601String(),
      'Updated_At': updatedAt?.toIso8601String(),
      'Is_Synced': isSynced,
      'Sync_Status': syncStatus,
    };
  }

  /// Serializes to NAV-compatible JSON for API sync.
  /// Maps mobile status values to NAV enum values.
  Map<String, dynamic> toNavJson() {
    int navStatus;
    switch (status) {
      case BatchStatus.pending:
        navStatus = 0;
        break;
      case BatchStatus.inTransit:
        navStatus = 1;
        break;
      case BatchStatus.received:
        navStatus = 2;
        break;
      case BatchStatus.collected:
        navStatus = 3;
        break;
      default:
        navStatus = 0;
    }

    return {
      'Batch_No': batchNo,
      'Date': date?.toIso8601String(),
      'User': user,
      'User_Agent_Code': userAgentCode,
      'User_Name': userName,
      'Status': navStatus,
      'Parcel_Document_Nos': parcelDocumentNos.join(','),
      'Parcel_Count': parcelCount ?? parcelDocumentNos.length,
      'Total_Amount': totalAmount,
      'Source': sourceLocation ?? fromLocation,
      'Destination': destinationLocation ?? toLocation,
      'From_Location': fromLocation ?? sourceLocation,
      'To_Location': toLocation ?? destinationLocation,
      'Vehicle': vehicle,
      'Driver': driver,
      'Dispatch_DateTime': dispatchDateTime?.toIso8601String(),
      'Received_DateTime': receivedDateTime?.toIso8601String(),
      'Created_At': createdAt?.toIso8601String(),
      'Updated_At': updatedAt?.toIso8601String(),
      'Is_Synced': isSynced,
      'Sync_Status': syncStatus,
    };
  }

  factory Batches.fromJson(Map<String, dynamic> json) {
    dynamic read(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key)) return json[key];
      }
      return null;
    }

    final docs = _parseStringList(
      read(['Parcel_Document_Nos', 'parcel_Document_Nos', 'parcelDocumentNos']),
    );

    return Batches(
      batchNo: read(['Batch_No', 'batch_No', 'batchNo']) as String?,
      date: _parseDate(read(['Date', 'date'])),
      user: read(['User', 'user']) as String?,
      userAgentCode:
          read(['User_Agent_Code', 'user_Agent_Code', 'userAgentCode'])
              as String?,
      userName: read(['User_Name', 'user_Name', 'userName']) as String?,
      status: _parseStatus(read(['Status', 'status'])),
      parcelDocumentNos: docs,
      parcelCount:
          read(['Parcel_Count', 'parcel_Count', 'parcelCount']) is num
              ? (read(['Parcel_Count', 'parcel_Count', 'parcelCount']) as num)
                  .toInt()
              : null,
      totalAmount:
          (read(['Total_Amount', 'total_Amount', 'totalAmount']) as num?)
              ?.toDouble(),
      sourceLocation:
          (read([
                'Source',
                'source',
                'sourceLocation',
                'From_Location',
                'from_Location',
                'fromLocation',
              ]))
              as String?,
      destinationLocation:
          (read([
                'Destination',
                'destination',
                'destinationLocation',
                'To_Location',
                'to_Location',
                'toLocation',
              ]))
              as String?,
      fromLocation:
          (read([
                'From_Location',
                'from_Location',
                'fromLocation',
                'Source',
                'source',
              ]))
              as String?,
      toLocation:
          (read([
                'To_Location',
                'to_Location',
                'toLocation',
                'Destination',
                'destination',
              ]))
              as String?,
      vehicle: read(['Vehicle', 'vehicle']) as String?,
      driver: read(['Driver', 'driver']) as String?,
      dispatchDateTime: _parseDate(
        read(['Dispatch_DateTime', 'dispatch_Date_Time', 'dispatchDateTime']),
      ),
      receivedDateTime: _parseDate(
        read(['Received_DateTime', 'received_Date_Time', 'receivedDateTime']),
      ),
      createdAt: _parseDate(read(['Created_At', 'created_At', 'createdAt'])),
      updatedAt: _parseDate(read(['Updated_At', 'updated_At', 'updatedAt'])),
      isSynced: _parseBool(read(['Is_Synced', 'is_Synced', 'isSynced'])),
      syncStatus:
          read(['Sync_Status', 'sync_Status', 'syncStatus']) as String?,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'Batch_No': batchNo,
      'Date': date?.toIso8601String(),
      'User': user,
      'User_Agent_Code': userAgentCode,
      'User_Name': userName,
      'Status': status?.name,
      'Parcel_Document_Nos': jsonEncode(parcelDocumentNos),
      'Parcel_Count': parcelCount ?? parcelDocumentNos.length,
      'Total_Amount': totalAmount,
      'Source': sourceLocation ?? fromLocation,
      'Destination': destinationLocation ?? toLocation,
      'From_Location': fromLocation ?? sourceLocation,
      'To_Location': toLocation ?? destinationLocation,
      'Vehicle': vehicle,
      'Driver': driver,
      'Dispatch_DateTime': dispatchDateTime?.toIso8601String(),
      'Received_DateTime': receivedDateTime?.toIso8601String(),
      'Created_At': createdAt?.toIso8601String(),
      'Updated_At': updatedAt?.toIso8601String(),
      'Is_Synced': isSynced ? 1 : 0,
      'Sync_Status': syncStatus,
    };
  }

  factory Batches.fromDbMap(Map<String, dynamic> map) {
    final docs = _parseStringList(
      map['Parcel_Document_Nos'] ?? map['parcelDocumentNos'],
    );

    return Batches(
      batchNo: (map['Batch_No'] ?? map['batchNo']) as String?,
      date: _parseDate(map['Date'] ?? map['date']),
      user: (map['User'] ?? map['user']) as String?,
      userAgentCode:
          (map['User_Agent_Code'] ?? map['userAgentCode']) as String?,
      userName: (map['User_Name'] ?? map['userName']) as String?,
      status: _parseStatus(map['Status'] ?? map['status']),
      parcelDocumentNos: docs,
      parcelCount:
          (map['Parcel_Count'] ?? map['parcelCount']) is num
              ? ((map['Parcel_Count'] ?? map['parcelCount']) as num).toInt()
              : null,
      totalAmount:
          ((map['Total_Amount'] ?? map['totalAmount']) as num?)?.toDouble(),
      sourceLocation:
          (map['Source'] ??
                  map['sourceLocation'] ??
                  map['From_Location'] ??
                  map['fromLocation'])
              as String?,
      destinationLocation:
          (map['Destination'] ??
                  map['destinationLocation'] ??
                  map['To_Location'] ??
                  map['toLocation'])
              as String?,
      fromLocation:
          (map['From_Location'] ?? map['fromLocation'] ?? map['Source'])
              as String?,
      toLocation:
          (map['To_Location'] ?? map['toLocation'] ?? map['Destination'])
              as String?,
      vehicle: (map['Vehicle'] ?? map['vehicle']) as String?,
      driver: (map['Driver'] ?? map['driver']) as String?,
      dispatchDateTime: _parseDate(
        map['Dispatch_DateTime'] ?? map['dispatchDateTime'],
      ),
      receivedDateTime: _parseDate(
        map['Received_DateTime'] ?? map['receivedDateTime'],
      ),
      createdAt: _parseDate(map['Created_At'] ?? map['createdAt']),
      updatedAt: _parseDate(map['Updated_At'] ?? map['updatedAt']),
      isSynced: _parseBool(map['Is_Synced'] ?? map['isSynced']),
      syncStatus: (map['Sync_Status'] ?? map['syncStatus']) as String?,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final raw = value.toString().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return <String>[];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) return <String>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Fall back to comma-separated parsing below.
    }

    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static BatchStatus _parseStatus(dynamic value) {
    if (value is num) {
      switch (value.toInt()) {
        case 1:
          return BatchStatus.inTransit;
        case 2:
          return BatchStatus.received;
        case 3:
          return BatchStatus.collected;
        default:
          return BatchStatus.pending;
      }
    }

    final raw = value?.toString().trim().toLowerCase() ?? '';
    switch (raw) {
      case 'open':
      case 'pending':
      case '0':
        return BatchStatus.pending;
      case 'intransit':
      case 'in_transit':
      case 'in-transit':
      case '1':
        return BatchStatus.inTransit;
      case 'received':
      case '2':
        return BatchStatus.received;
      case 'collected':
      case '3':
        return BatchStatus.collected;
      default:
        return BatchStatus.pending;
    }
  }
}
