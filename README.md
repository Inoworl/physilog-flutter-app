# physi_log

A new Flutter project.

## 公開Webサイト

LP、利用規約、プライバシーポリシー、使い方、アカウント削除などの公開ページは
`web/` に集約し、Firebase Hostingで配信します。Flutter Webアプリではありません。
`docs/` は開発者向けの設計・運用ドキュメントです。

変更時は `node --test scripts/test_web_hosting.mjs` を実行してください。
配置、既存URL、ローカル確認、公開手順は [公開Webの運用](docs/web-hosting.md) を参照してください。

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
