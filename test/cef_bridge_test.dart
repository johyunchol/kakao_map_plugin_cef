import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_plugin_cef/kakao_map_plugin_cef.dart';

void main() {
  test('채널 shim 은 <head> 바로 뒤에 들어가고 등록한 채널 이름만 노출한다', () {
    final bridge = CefBridge()
      ..addJavaScriptChannel('onMapCreated', (_) {})
      ..addJavaScriptChannel('onMapTap', (_) {});
    final html = bridge.injectChannelShim(
        '<html lang="ko">\n<head>\n<meta charset="UTF-8"><script>first()</script></head><body></body></html>');
    final headEnd = html.indexOf('<head>') + '<head>'.length;
    expect(
        html.substring(headEnd).startsWith(
            '<script>(function(){var names=["onMapCreated","onMapTap"]'),
        isTrue,
        reason: html);
    expect(
        html,
        contains(
            'window[n]={postMessage:function(m){external.JavaScriptChannel(n,String(m));}}'));
    // shim 이 문서의 첫 스크립트보다 앞선다.
    expect(html.indexOf('external.JavaScriptChannel'),
        lessThan(html.indexOf('first()')));
  });

  test('<head> 가 없으면 문서 맨 앞에 넣는다', () {
    final bridge = CefBridge()..addJavaScriptChannel('a', (_) {});
    expect(bridge.injectChannelShim('<div></div>'), startsWith('<script>'));
  });

  test('CEF 가 JSON.stringify 로 감싼 메시지를 원래 문자열로 되돌린다', () {
    expect(CefBridge.unwrapChannelMessage('"{\\"ready\\":true}"'),
        '{"ready":true}');
    expect(CefBridge.unwrapChannelMessage('{"ready":true}'), '{"ready":true}');
    expect(CefBridge.unwrapChannelMessage('plain'), 'plain');
    expect(CefBridge.unwrapChannelMessage('"not-json'), '"not-json');
  });
}
