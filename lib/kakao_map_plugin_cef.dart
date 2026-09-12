/// `kakao_map_plugin` 의 Windows / Linux 구현입니다.
///
/// pubspec 에 추가하기만 하면 앱 시작 시 [KakaoMapPluginCef.registerWith] 가 호출되어
/// Chromium(CEF) 기반 브릿지가 등록됩니다. 별도 코드는 필요 없습니다.
///
/// 카카오 개발자 콘솔의 Web 플랫폼 사이트 도메인에 `http://localhost:8790`
/// (`KakaoMapDesktop.localServerPort` 기본값)을 등록해야 합니다.
library;

export 'src/cef_bridge.dart';
export 'src/kakao_map_plugin_cef.dart';
