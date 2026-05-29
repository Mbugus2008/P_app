class AppLocation {
  AppLocation({required this.code, this.name});

  final String code;
  final String? name;

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
    );
  }

  Map<String, dynamic> toDbMap() {
    return {'Code': code, 'Name': name};
  }

  factory AppLocation.fromDbMap(Map<String, dynamic> map) {
    return AppLocation(
      code: (map['Code'] ?? '').toString(),
      name: map['Name']?.toString(),
    );
  }
}
