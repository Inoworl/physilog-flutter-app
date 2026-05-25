import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SettingsWebViewScreen extends StatefulWidget {
  const SettingsWebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<SettingsWebViewScreen> createState() => _SettingsWebViewScreenState();
}

class _SettingsWebViewScreenState extends State<SettingsWebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
