# kakao_map_plugin_cef

Windows / Linux implementation of [kakao_map_plugin](https://pub.dev/packages/kakao_map_plugin), backed by [webview_cef](https://pub.dev/packages/webview_cef) (Chromium Embedded Framework).

The map is rendered off-screen by Chromium and presented as a Flutter `Texture`, so Flutter widgets, bottom sheets and routes work above the map exactly like on mobile.

## Setup

1. Add both packages:

   ```yaml
   dependencies:
     kakao_map_plugin: ^1.1.0
     kakao_map_plugin_cef: ^1.1.0
   ```

   The bridge registers itself on app start. No code changes are needed.

2. Register the desktop origin in the Kakao Developers console → your app → Platform → **Web** → Site domain:

   ```
   http://localhost:8790
   ```

   Desktop WebViews cannot pass a base URL for an HTML string, so the plugin serves the map document from a loopback HTTP server on this port. Change the port with `AuthRepository.initialize(desktopPort: ...)` or `KakaoMapDesktop.localServerPort` and register the same value.

3. Follow the `webview_cef` platform notes:
   * **Windows**: edit `windows/runner/main.cpp` to call `initCEFProcesses` first and forward messages with `handleWndProcForCEF` (see the [webview_cef README](https://pub.dev/packages/webview_cef#windows)). WebView2 is not used; the app bundles Chromium.
   * **Linux**: install `clang cmake ninja-build pkg-config libgtk-3-dev`. CEF is downloaded on the first build, and `linux/runner/main.cc` / `my_application.cc` are patched automatically (commit the changes).
   * The first build downloads the CEF distribution (~330 MB). Apps grow by roughly 150 MB.

## Notes

* Do not add this package to apps that only target Android / iOS / Web / macOS. macOS is supported by `kakao_map_plugin` itself through `webview_flutter`, and adding `webview_cef` would force the CEF download on every macOS build.
* Hover callbacks (`onMarkerMouseOver` etc.) work on desktop because a mouse pointer is present.

## Example

`example/` runs the full 84-screen example app of `kakao_map_plugin` on Windows / Linux. It reuses the core example package, so set the app key in `../../example/assets/env/.env` (see the core README) and add `DESKTOP_PORT=<port you registered>` there if you do not use 8790.

```bash
cd example
flutter run -d windows   # or -d linux
```

## Debugging

Pass `--dart-define=KMP_CEF_DEBUG=true` to print bridge activity (browser creation, page events, console messages, JavaScript calls) with the `[CefBridge]` prefix.
