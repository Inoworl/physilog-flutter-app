import 'package:url_launcher/url_launcher.dart';

abstract interface class SubscriptionManagementLauncher {
  Future<bool> open(Uri uri);
}

class UrlSubscriptionManagementLauncher
    implements SubscriptionManagementLauncher {
  const UrlSubscriptionManagementLauncher();

  @override
  Future<bool> open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
