class AppVersion implements Comparable<AppVersion> {
  const AppVersion._(this._segments);

  factory AppVersion.parse(String version) {
    final normalized = version.trim().split('+').first.split('-').first;
    if (normalized.isEmpty) {
      throw const FormatException('Version is empty');
    }

    final segments = normalized.split('.').map((segment) {
      if (segment.isEmpty) {
        throw FormatException('Version segment is empty: $version');
      }
      return int.parse(segment);
    }).toList();

    while (segments.length < 3) {
      segments.add(0);
    }

    return AppVersion._(segments.take(3).toList());
  }

  final List<int> _segments;

  static bool isCurrentVersionLessThanMinRequired({
    required String currentVersion,
    required String minRequiredVersion,
  }) {
    if (currentVersion.trim().isEmpty || minRequiredVersion.trim().isEmpty) {
      return false;
    }

    try {
      return AppVersion.parse(
            currentVersion,
          ).compareTo(AppVersion.parse(minRequiredVersion)) <
          0;
    } on FormatException {
      return false;
    }
  }

  @override
  int compareTo(AppVersion other) {
    for (var index = 0; index < _segments.length; index++) {
      final result = _segments[index].compareTo(other._segments[index]);
      if (result != 0) {
        return result;
      }
    }
    return 0;
  }
}
