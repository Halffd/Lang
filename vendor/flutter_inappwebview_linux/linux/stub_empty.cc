// Stub plugin registration for builds without WPE WebKit (see CMakeLists).
// The generated plugin registrant references this exact symbol; keeping it
// as a no-op lets the runner link while providing no webview functionality.
// The app detects the unregistered Dart platform at runtime and falls back
// to the system browser.
#include <flutter_linux/flutter_linux.h>

extern "C" void flutter_inappwebview_linux_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  // no-op: no native implementation without WPE
}
