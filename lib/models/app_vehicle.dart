class AppVehicle {
  AppVehicle({
    required this.code,
    this.vehicleNumber,
    this.vehicleType,
    this.category,
    this.status,
    this.fleetNo,
    this.startDate,
  });

  final String code;
  final String? vehicleNumber;
  final String? vehicleType;
  final String? category;
  final String? status;
  final String? fleetNo;
  final DateTime? startDate;

  factory AppVehicle.fromApi(Map<String, dynamic> json) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    DateTime? readDate(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
      return null;
    }

    final code = readString(['Code', 'code']);

    return AppVehicle(
      code: code,
      vehicleNumber:
          readString([
                'Vehicle_Number',
                'vehicleNumber',
                'VehicleNumber',
              ]).isEmpty
              ? null
              : readString([
                'Vehicle_Number',
                'vehicleNumber',
                'VehicleNumber',
              ]),
      vehicleType:
          readString(['Vehicle_Type', 'vehicleType', 'VehicleType']).isEmpty
              ? null
              : readString(['Vehicle_Type', 'vehicleType', 'VehicleType']),
      category:
          readString(['Category', 'category']).isEmpty
              ? null
              : readString(['Category', 'category']),
      status:
          readString(['Status', 'status']).isEmpty
              ? null
              : readString(['Status', 'status']),
      fleetNo:
          readString(['Fleet_No', 'fleetNo', 'FleetNo']).isEmpty
              ? null
              : readString(['Fleet_No', 'fleetNo', 'FleetNo']),
      startDate: readDate(['Start_Date', 'startDate', 'StartDate']),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'Code': code,
      'Vehicle_Number': vehicleNumber,
      'Vehicle_Type': vehicleType,
      'Category': category,
      'Status': status,
      'Fleet_No': fleetNo,
      'Start_Date': startDate?.toIso8601String(),
    };
  }

  factory AppVehicle.fromDbMap(Map<String, dynamic> map) {
    return AppVehicle(
      code: (map['Code'] ?? '').toString(),
      vehicleNumber: map['Vehicle_Number']?.toString(),
      vehicleType: map['Vehicle_Type']?.toString(),
      category: map['Category']?.toString(),
      status: map['Status']?.toString(),
      fleetNo: map['Fleet_No']?.toString(),
      startDate:
          map['Start_Date'] == null
              ? null
              : DateTime.tryParse(map['Start_Date'].toString()),
    );
  }
}
