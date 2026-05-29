class AppUser {
  AppUser({
    required this.agentCode,
    this.name,
    this.mobileNo,
    this.password,
    this.location,
    this.accountType,
  });

  final String agentCode;
  final String? name;
  final String? mobileNo;
  final String? password;
  final String? location;
  final String? accountType;

  bool get isAdmin => (accountType ?? '').trim().toLowerCase() == 'admin';

  factory AppUser.fromApi(Map<String, dynamic> json) {
    String readString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    String? readAccountType() {
      dynamic raw;
      for (final key in const [
        'Account_type',
        'account_type',
        'AccountType',
        'accountType',
      ]) {
        if (json.containsKey(key)) {
          raw = json[key];
          break;
        }
      }

      if (raw == null) return null;
      final text = raw.toString().trim();
      if (text.isEmpty) return null;

      const labels = <String>[
        'User',
        'Admin',
        'Supervisor',
        'Deport',
        'Fuel',
        'Parcel',
      ];

      final idx = int.tryParse(text);
      if (idx != null && idx >= 0 && idx < labels.length) {
        return labels[idx];
      }

      return text;
    }

    return AppUser(
      agentCode: readString([
        'Agent_Code',
        'agent_Code',
        'AgentCode',
        'agentCode',
      ]),
      name:
          readString(['Name', 'name']).isEmpty
              ? null
              : readString(['Name', 'name']),
      mobileNo:
          readString(['Mobile_No', 'mobile_No', 'MobileNo', 'mobileNo']).isEmpty
              ? null
              : readString(['Mobile_No', 'mobile_No', 'MobileNo', 'mobileNo']),
      password:
          readString(['Password', 'password']).isEmpty
              ? null
              : readString(['Password', 'password']),
      location:
          readString(['Location', 'location']).isEmpty
              ? null
              : readString(['Location', 'location']),
      accountType: readAccountType(),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'Agent_Code': agentCode,
      'Name': name,
      'Mobile_No': mobileNo,
      'Password': password,
      'Location': location,
      'Account_Type': accountType,
    };
  }

  factory AppUser.fromDbMap(Map<String, dynamic> map) {
    return AppUser(
      agentCode: (map['Agent_Code'] ?? '').toString(),
      name: map['Name']?.toString(),
      mobileNo: map['Mobile_No']?.toString(),
      password: map['Password']?.toString(),
      location: map['Location']?.toString(),
      accountType: map['Account_Type']?.toString(),
    );
  }
}
