class AppVersionInfo {
  final String version;
  final int versionCode;
  final String buildDate;
  final String downloadUrl;
  final String? releaseNotes;
  final bool forceUpdate;

  const AppVersionInfo({
    required this.version,
    required this.versionCode,
    required this.buildDate,
    required this.downloadUrl,
    this.releaseNotes,
    this.forceUpdate = false,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      version: (json['version'] ?? json['Version'] ?? '1.0.0') as String,
      versionCode: ((json['versionCode'] ?? json['VersionCode']) as num?)?.toInt() ?? 1,
      buildDate: (json['buildDate'] ?? json['BuildDate'] ?? '') as String,
      downloadUrl: (json['downloadUrl'] ?? json['DownloadUrl'] ?? '') as String,
      releaseNotes: (json['releaseNotes'] ?? json['ReleaseNotes']) as String?,
      forceUpdate: (json['forceUpdate'] ?? json['ForceUpdate'] ?? false) as bool,
    );
  }
}

class ApiEnvelope<T> {
  final int code;
  final String desc;
  final T? contents;

  const ApiEnvelope({required this.code, required this.desc, this.contents});

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? parser,
  ) {
    final code = (json['code'] ?? json['Code'] ?? json['Code'] ?? -1) as int;
    final desc = (json['desc'] ?? json['Desc'] ?? '') as String;
    final contents = json['contents'] ?? json['Contents'];
    return ApiEnvelope(
      code: code,
      desc: desc,
      contents: contents != null && parser != null ? parser(contents) : null,
    );
  }

  bool get isSuccess => code == 0;
}
