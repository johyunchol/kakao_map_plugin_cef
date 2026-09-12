# kakao_map_plugin_cef

[English](README.md) | 한국어

[kakao_map_plugin](https://pub.dev/packages/kakao_map_plugin) 의 Windows / Linux 구현입니다. [webview_cef](https://pub.dev/packages/webview_cef)(Chromium Embedded Framework) 로 동작합니다.

Chromium 이 지도를 오프스크린으로 그려 Flutter `Texture` 로 보여 주므로, 지도 위 Flutter 위젯·바텀시트·화면 전환이 모바일과 똑같이 동작합니다.

## 설정

1. 두 패키지를 함께 추가합니다.

   ```yaml
   dependencies:
     kakao_map_plugin: ^1.1.0
     kakao_map_plugin_cef: ^1.1.0
   ```

   앱 시작 시 브릿지가 자동 등록되므로 코드 변경은 없습니다.

2. [Kakao Developers](https://developers.kakao.com) 콘솔 → 내 애플리케이션 → 플랫폼 → **Web** → 사이트 도메인에 아래 주소를 등록합니다.

   ```
   http://localhost:8790
   ```

   데스크톱 WebView 는 HTML 문자열에 기준 URL 을 줄 수 없어, 플러그인이 지도 문서를 이 포트의 로컬(loopback) HTTP 서버로 서빙합니다. 포트를 바꾸려면 `AuthRepository.initialize(desktopPort: ...)` 또는 `KakaoMapDesktop.localServerPort` 로 지정하고 같은 값을 등록하세요.

3. `webview_cef` 의 플랫폼별 설정을 따릅니다.
   * **Windows**: `windows/runner/main.cpp` 의 `wWinMain` 첫 줄에서 `initCEFProcesses(instance)` 를 호출하고, 메시지 루프에 `handleWndProcForCEF(...)` 를 넣습니다([webview_cef README](https://pub.dev/packages/webview_cef#windows) 참고). 그대로 복사할 수 있는 예가 [example/windows/runner/main.cpp](example/windows/runner/main.cpp) 에 있습니다. WebView2 는 쓰지 않고 앱에 Chromium 이 함께 들어갑니다.
   * **Linux**: `clang cmake ninja-build pkg-config libgtk-3-dev` 가 필요합니다. 첫 빌드 때 CEF 를 내려받고 `linux/runner/main.cc` 와 `my_application.cc` 가 자동으로 수정됩니다(수정된 파일은 그대로 커밋하세요).
   * 첫 빌드 때 CEF 배포본(약 330 MB)을 내려받고, 앱 크기가 150 MB 정도 커집니다. Windows 10 이상, Flutter 3.27 이상이 필요합니다.

## 참고

* Android / iOS / Web / macOS 만 대상인 앱에는 이 패키지를 추가하지 마세요. macOS 는 `kakao_map_plugin` 이 `webview_flutter` 로 직접 지원하며, `webview_cef` 를 넣으면 macOS 빌드 때마다 CEF 를 내려받게 됩니다.
* 데스크톱에는 마우스가 있으므로 hover 콜백(`onMarkerMouseOver` 등)이 동작합니다.

## Docker / CI 의 Linux

Chromium 은 공유 메모리가 필요합니다. Docker 기본 `/dev/shm`(64 MB)에서는 렌더러가 `fallocate: No space left on device` 를 기록하고 지도 생성 몇 초 뒤부터 JavaScript 호출이 돌아오지 않습니다. 컨테이너를 `--shm-size=1g` 이상으로 띄우고, GPU 가 없으면 소프트웨어 GL(`LIBGL_ALWAYS_SOFTWARE=1`)을 쓰세요.

## 예제

`example/` 은 `kakao_map_plugin` 의 84개 예제 화면을 Windows / Linux 에서 그대로 실행합니다. 코어 예제 패키지를 재사용하므로 앱 키는 `../../example/assets/env/.env` 에 두고(코어 README 참고), 8790 이 아닌 포트를 쓰면 같은 파일에 `DESKTOP_PORT=<등록한 포트>` 를 추가하세요.

```bash
cd example
flutter run -d windows   # 또는 -d linux
```

## 디버깅

`--dart-define=KMP_CEF_DEBUG=true` 를 주면 브라우저 생성, 페이지 이벤트, 콘솔 메시지, JavaScript 호출이 `[CefBridge]` 접두사로 출력됩니다.
