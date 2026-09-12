import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:kakao_map_plugin/kakao_map_plugin_desktop.dart';
import 'package:webview_cef/webview_cef.dart' as cef;
import 'package:webview_flutter/webview_flutter.dart' show WebViewController;

/// `webview_cef`(Chromium Embedded Framework)로 구현한 [KakaoMapBridge] 입니다.
///
/// 지도 문서는 [KakaoMapLocalServer] 가 `http://localhost:{port}` 로 서빙하고, CEF
/// 브라우저가 그 주소를 엽니다. JS → Dart 채널은 CEF 가 제공하는
/// `external.JavaScriptChannel(name, message)` 를 `name.postMessage(message)` 형태로
/// 감싼 shim 을 문서 머리에 끼워 넣어 모바일과 같은 규약을 유지합니다.
class CefBridge implements KakaoMapBridge {
  CefBridge({this.transparentBackground = false});

  /// 지도 위젯용이면 true 입니다. CEF 텍스처는 문서 배경색을 그대로 쓰므로 별도 처리는 없습니다.
  final bool transparentBackground;

  /// `--dart-define=KMP_CEF_DEBUG=true` 로 켜는 진단 로그입니다.
  static const bool debugLog = bool.fromEnvironment('KMP_CEF_DEBUG');
  static int _seq = 0;
  static void _log(String message) {
    if (debugLog) debugPrint('[CefBridge] $message');
  }

  static Future<void>? _managerReady;

  cef.WebViewController? _controller;
  final Map<String, BridgeMessageHandler> _channels = {};
  String? _url;
  String? _html;
  bool _disposed = false;

  /// 브라우저 생성이 끝났을 때 완료됩니다.
  final Completer<void> _ready = Completer<void>();

  /// 컨트롤러가 준비될 때까지 실행을 미루는 대기열입니다.
  Future<void> get ready => _ready.future;

  static Future<void> _ensureManager() =>
      _managerReady ??= cef.WebviewManager().initialize();

  /// 채널 shim 스크립트를 만듭니다. 문서의 다른 스크립트보다 먼저 실행되어야 합니다.
  String _channelShim() {
    final names = jsonEncode(_channels.keys.toList());
    return '<script>(function(){var names=$names;for(var i=0;i<names.length;i++){(function(n){'
        'window[n]={postMessage:function(m){external.JavaScriptChannel(n,String(m));}};'
        '})(names[i]);}})();</script>';
  }

  /// 채널 shim 을 문서에 끼워 넣습니다. 테스트용으로 공개합니다.
  @visibleForTesting
  String injectChannelShim(String html) => _injectShim(html);

  String _injectShim(String html) {
    final shim = _channelShim();
    final headIndex =
        html.indexOf(RegExp(r'<head[^>]*>', caseSensitive: false));
    if (headIndex >= 0) {
      final end = html.indexOf('>', headIndex) + 1;
      return html.substring(0, end) + shim + html.substring(end);
    }
    return shim + html;
  }

  /// CEF 는 채널 메시지를 항상 `JSON.stringify` 로 감싸서 보냅니다. 원래 문자열로 되돌립니다.
  /// CEF 채널 메시지를 원래 문자열로 되돌립니다. 테스트용으로 공개합니다.
  @visibleForTesting
  static String unwrapChannelMessage(String message) => _unwrap(message);

  static String _unwrap(String message) {
    if (message.startsWith('"')) {
      try {
        final decoded = jsonDecode(message);
        if (decoded is String) return decoded;
      } catch (_) {}
    }
    return message;
  }

  @override
  void addJavaScriptChannel(String name, BridgeMessageHandler onMessage) {
    _channels[name] = onMessage;
  }

  @override
  Future<void> loadHtml(String html, {String? baseUrl}) async {
    _log('loadHtml (controller=${_controller != null})');
    if (_disposed) return;
    _html = html;
    final server = KakaoMapLocalServer.instance;
    final document = _injectShim(html);
    if (_url == null) {
      _url = await server.serve(document);
    } else {
      server.update(_url!, document);
    }
    final controller = _controller;
    if (controller == null) {
      await _create(_url!);
    } else {
      await controller.loadUrl(_url!);
    }
  }

  Future<void> _create(String url) async {
    _log('create: manager init');
    await _ensureManager();
    _log('create: manager ready');
    if (_disposed) return;
    final controller = cef.WebviewManager().createWebView(
      loading: const SizedBox.shrink(),
    );
    _controller = controller;
    if (debugLog) {
      controller.setWebviewListener(cef.WebviewEventsListener(
        onLoadStart: (_, url) => _log('event loadStart $url'),
        onLoadEnd: (_, url) => _log('event loadEnd $url'),
        onUrlChanged: (url) => _log('event urlChanged $url'),
        onTitleChanged: (title) => _log('event title $title'),
        onConsoleMessage: (level, message, source, line) =>
            _log('console[$level] $message ($source:$line)'),
      ));
    }
    // 채널을 먼저 등록해야 문서 스크립트의 첫 postMessage 를 놓치지 않으므로
    // 빈 문서로 브라우저를 만든 뒤 채널을 붙이고 실제 문서로 이동합니다.
    await controller.initialize('about:blank');
    _log('create: browser initialized');
    if (_disposed) return;
    await controller.setJavaScriptChannels({
      for (final entry in _channels.entries)
        cef.JavascriptChannel(
          name: entry.key,
          onMessageReceived: (message) => entry.value(_unwrap(message.message)),
        ),
    });
    _log('create: channels set, loading $url');
    await controller.loadUrl(url);
    _log('create: loadUrl returned');
    if (!_ready.isCompleted) _ready.complete();
  }

  @override
  Future<void> reload() async {
    final controller = _controller;
    if (controller == null || _url == null) return;
    await controller.loadUrl(_url!);
  }

  @override
  Future<void> runJavaScript(String script) async {
    final controller = _controller;
    if (controller == null || _disposed) return;
    final id = ++_seq;
    _log('run#$id ${script.length > 60 ? script.substring(0, 60) : script}');
    await controller.executeJavaScript(script);
    _log('run#$id done');
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String script) async {
    final controller = _controller;
    if (controller == null || _disposed) return null;
    final id = ++_seq;
    _log('eval#$id ${script.length > 60 ? script.substring(0, 60) : script}');
    final result = await controller.evaluateJavascript(script);
    _log('eval#$id -> ${result.runtimeType}');
    // 호출 측은 JSON 문자열을 기대합니다(Android WebView 와 같은 형식).
    if (result == null) return 'null';
    if (result is String) return result;
    return jsonEncode(result);
  }

  @override
  Widget buildView({
    Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers =
        const <Factory<OneSequenceGestureRecognizer>>{},
  }) {
    return _CefView(bridge: this);
  }

  @override
  WebViewController? get webViewController => null;

  @override
  Future<void> dispose() async {
    _log('dispose');
    _disposed = true;
    final url = _url;
    if (url != null) KakaoMapLocalServer.instance.remove(url);
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('CefBridge dispose: $e');
      }
    }
  }

  /// 마지막으로 불러온 문서입니다. 테스트용입니다.
  @visibleForTesting
  String? get lastHtml => _html;
}

/// 브라우저가 준비되면 CEF 텍스처 위젯을, 그 전에는 빈 위젯을 보여 줍니다.
class _CefView extends StatefulWidget {
  const _CefView({required this.bridge});

  final CefBridge bridge;

  @override
  State<_CefView> createState() => _CefViewState();
}

class _CefViewState extends State<_CefView> {
  bool _readyFlag = false;

  @override
  void initState() {
    super.initState();
    widget.bridge.ready.then((_) {
      if (mounted) setState(() => _readyFlag = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.bridge._controller;
    if (!_readyFlag || controller == null) return const SizedBox.expand();
    return cef.WebView(controller);
  }
}
