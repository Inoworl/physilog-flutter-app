class AppConstants {
  AppConstants._();

  // 動画制限
  static const maxVideoDurationSeconds = 30;
  static const compressedVideoWidth = 720;
  static const compressedVideoFps = 30;

  // FPS選択肢
  static const fpsOptions = [30.0, 60.0, 120.0, 240.0];
  static const defaultFps = 60.0;

  // バリデーション
  static const maxAthleteNameLength = 50;
  static const maxEventTypeLength = 50;
  static const maxMemoLength = 500;

  // ページネーション
  static const pageSize = 20;

  // 種目サジェスト
  static const eventSuggestions = [
    '50m走',
    '100m走',
    '200m走',
    '400m走',
    '20mシャトルラン',
    '50m走（折り返し）',
  ];
}
