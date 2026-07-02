class AppUpdateSettings {
  const AppUpdateSettings({
    required this.title,
    required this.content,
    required this.forceUpdate,
    required this.iOSLatestVersion,
    required this.androidLatestVersion,
    required this.iOSMinRequiredVersion,
    required this.androidMinRequiredVersion,
    required this.appStoreUrl,
    required this.googlePlayUrl,
  });

  factory AppUpdateSettings.fromJson(Map<String, dynamic> json) {
    return AppUpdateSettings(
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      iOSLatestVersion: json['iOSLatestVersion'] as String? ?? '',
      androidLatestVersion: json['androidLatestVersion'] as String? ?? '',
      iOSMinRequiredVersion: json['iOSMinRequiredVersion'] as String? ?? '',
      androidMinRequiredVersion:
          json['androidMinRequiredVersion'] as String? ?? '',
      appStoreUrl: json['appStoreUrl'] as String? ?? '',
      googlePlayUrl: json['googlePlayUrl'] as String? ?? '',
    );
  }

  final String title;
  final String content;
  final bool forceUpdate;
  final String iOSLatestVersion;
  final String androidLatestVersion;
  final String iOSMinRequiredVersion;
  final String androidMinRequiredVersion;
  final String appStoreUrl;
  final String googlePlayUrl;
}
