//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <mecab_for_flutter/mecab_for_flutter_plugin.h>
#include <sqlite3_flutter_libs/sqlite3_flutter_libs_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) mecab_for_flutter_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MecabForFlutterPlugin");
  mecab_for_flutter_plugin_register_with_registrar(mecab_for_flutter_registrar);
  g_autoptr(FlPluginRegistrar) sqlite3_flutter_libs_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "Sqlite3FlutterLibsPlugin");
  sqlite3_flutter_libs_plugin_register_with_registrar(sqlite3_flutter_libs_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
}
