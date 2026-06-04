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
    return ApiEnvelope(
      code: json['Code'] as int? ?? -1,
      desc: json['Desc'] as String? ?? '',
      contents: json['Contents'] != null && parser != null
          ? parser(json['Contents'])
          : null,
    );
  }

  bool get isSuccess => code == 0;
}
