class AppLocation {
  AppLocation({required this.code, this.name, this.phoneNo});

  final String code;
  final String? name;
  final String? phoneNo;

  factory AppLocation.fromApi(Map<String, dynamic> json) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    return AppLocation(
      code: readString(['Code', 'code']),
      name:
          readString(['Name', 'name']).isEmpty
              ? null
              : readString(['Name', 'name']),
      phoneNo:
          readString(['Phone_No', 'phoneNo', 'phone_No']).isEmpty
              ? null
              : readString(['Phone_No', 'phoneNo', 'phone_No']),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {'Code': code, 'Name': name, 'Phone_No': phoneNo};
  }

  factory AppLocation.fromDbMap(Map<String, dynamic> map) {
    return AppLocation(
      code: (map['Code'] ?? '').toString(),
      name: map['Name']?.toString(),
      phoneNo: map['Phone_No']?.toString(),
    );
  }
}
