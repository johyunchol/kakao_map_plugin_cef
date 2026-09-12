import 'package:kakao_map_plugin/kakao_map_plugin_desktop.dart';

import 'cef_bridge.dart';

/// Flutter 플러그인 등록 진입점입니다. pubspec 의 `dartPluginClass` 로 선언되어
/// 앱 시작 시 자동으로 호출됩니다.
class KakaoMapPluginCef {
  /// CEF 브릿지 팩토리를 [KakaoMapDesktop] 에 등록합니다.
  static void registerWith() {
    KakaoMapDesktop.registerBridgeFactory(
      ({bool transparentBackground = false}) =>
          CefBridge(transparentBackground: transparentBackground),
    );
  }
}
