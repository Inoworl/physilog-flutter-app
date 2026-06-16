enum RevenueCatPlatform { ios, android }

class RevenueCatEnvironment {
  const RevenueCatEnvironment({
    required this.iosApiKey,
    required this.androidApiKey,
  });

  static const fromEnvironment = RevenueCatEnvironment(
    iosApiKey: String.fromEnvironment('REVENUECAT_IOS_API_KEY'),
    androidApiKey: String.fromEnvironment('REVENUECAT_ANDROID_API_KEY'),
  );

  final String iosApiKey;
  final String androidApiKey;

  String? apiKeyFor(RevenueCatPlatform platform) {
    final apiKey = switch (platform) {
      RevenueCatPlatform.ios => iosApiKey,
      RevenueCatPlatform.android => androidApiKey,
    };
    final trimmedApiKey = apiKey.trim();
    return trimmedApiKey.isEmpty ? null : trimmedApiKey;
  }
}
