/// Model for the AppUpdateController response.
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
      version: json['Version'] as String? ?? '1.0.0',
      versionCode: json['VersionCode'] as int? ?? 1,
      buildDate: json['BuildDate'] as String? ?? '',
      downloadUrl: json['DownloadUrl'] as String? ?? '',
      releaseNotes: json['ReleaseNotes'] as String?,
      forceUpdate: json['ForceUpdate'] as bool? ?? false,
    );
  }
}

/// Wraps the envelope: { Code, Desc, Contents }
class ApiEnvelope<T> {
  final int code;
  final String desc;
  final T? contents;

  const ApiEnvelope({required this.code, required this.desc, this.contents});

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? parser,
  ) {
    // The API uses lowercase json keys: code, desc, contents
    final int code = (json['Code'] ?? json['code']) as int? ?? -1;
    final String desc = (json['Desc'] ?? json['desc'] ?? '') as String;
    final dynamic contents = json['Contents'] ?? json['contents'];
    return ApiEnvelope(
      code: code,
      desc: desc,
      contents: contents != null && parser != null ? parser(contents) : null,
    );
  }

  bool get isSuccess => code == 0;
}
