enum RevenueCatPlatform { ios, android }

class RevenueCatTestStoreKeyInReleaseException implements Exception {
  const RevenueCatTestStoreKeyInReleaseException();

  @override
  String toString() {
    return 'ReleaseビルドではRevenueCat Test Store keyを使用できません。';
  }
}

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

  String? apiKeyFor(
    RevenueCatPlatform platform, {
    bool isReleaseMode = const bool.fromEnvironment('dart.vm.product'),
  }) {
    final apiKey = switch (platform) {
      RevenueCatPlatform.ios => iosApiKey,
      RevenueCatPlatform.android => androidApiKey,
    };
    final trimmedApiKey = apiKey.trim();
    if (trimmedApiKey.isEmpty) {
      return null;
    }
    if (isReleaseMode && trimmedApiKey.startsWith('test_')) {
      throw const RevenueCatTestStoreKeyInReleaseException();
    }
    return trimmedApiKey;
  }
}
