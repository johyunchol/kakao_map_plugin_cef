#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "webview_cef/webview_cef_plugin_c_api.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // webview_cef: Chromium 하위 프로세스를 시작합니다. wWinMain 의 첫 문장이어야 합니다.
  int cef_exit_code = initCEFProcesses(instance);
  if (cef_exit_code >= 0) {
    return cef_exit_code;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"kakao_map_plugin_cef_example", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
    // webview_cef: 키보드/IME 입력과 Flutter 엔진 스레드로의 호출을 CEF 에 전달합니다.
    handleWndProcForCEF(msg.hwnd, msg.message, msg.wParam, msg.lParam);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
