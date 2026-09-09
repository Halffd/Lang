import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';

enum DesktopPlatform { linux, windows, macos, unsupported }

class DesktopIPCService with TrayListener, WindowListener {
  static final DesktopIPCService _instance = DesktopIPCService._internal();
  factory DesktopIPCService() => _instance;
  DesktopIPCService._internal();

  DesktopPlatform _platform = DesktopPlatform.unsupported;
  bool _initialized = false;
  bool _isWindowVisible = true;
  bool _isAlwaysOnTop = false;

  final List<VoidCallback> _trayCallbacks = [];
  final List<VoidCallback> _fileDropCallbacks = [];
  final Map<String, VoidCallback> _hotkeyCallbacks = {};

  // Callbacks for menu actions
  VoidCallback? onStudyRequested;
  VoidCallback? onBrowserRequested;
  VoidCallback? onQuitRequested;

  DesktopPlatform get platform => _platform;
  bool get isSupported => _platform != DesktopPlatform.unsupported;
  bool get isAlwaysOnTop => _isAlwaysOnTop;
  bool get isWindowVisible => _isWindowVisible;

  Future<void> initialize() async {
    if (_initialized) return;

    if (kDebugMode) {
      debugPrint('DesktopIPCService: Skipping initialization in debug mode');
      _initialized = true;
      return;
    }

    _detectPlatform();

    if (!isSupported) {
      debugPrint('DesktopIPCService: Platform not supported');
      return;
    }

    try {
      await _initWindowManager();
      await _initTrayManager();
      await _initHotkeyManager();
      await _initNotifications();

      _initialized = true;
      debugPrint('DesktopIPCService: Initialized on $_platform');
    } catch (e, st) {
      debugPrint('DesktopIPCService: Initialization failed: $e\n$st');
    }
  }

  void _detectPlatform() {
    if (Platform.isLinux) {
      _platform = DesktopPlatform.linux;
    } else if (Platform.isWindows) {
      _platform = DesktopPlatform.windows;
    } else if (Platform.isMacOS) {
      _platform = DesktopPlatform.macos;
    }
  }

  Future<void> _initWindowManager() async {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Color(0x00000000),
      titleBarStyle: TitleBarStyle.normal,
      title: 'Lang',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    windowManager.addListener(this);
  }

  Future<void> _initTrayManager() async {
    try {
      final iconPath = Platform.isWindows
          ? 'assets/app_icon.ico'
          : 'assets/app_icon.png';
      await trayManager.setIcon(iconPath);
    } catch (e) {
      debugPrint('TrayManager: Could not set icon: $e');
    }

    final menu = Menu(
      items: [
        MenuItem(key: 'show', label: 'Show Window'),
        MenuItem(key: 'always_on_top', label: 'Toggle Always on Top'),
        MenuItem.separator(),
        MenuItem(key: 'study', label: 'Start Study Session'),
        MenuItem(key: 'browser', label: 'Open Browser'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit'),
      ],
    );

    try {
      await trayManager.setContextMenu(menu);
      trayManager.addListener(this);
    } catch (e) {
      debugPrint('TrayManager: Could not set context menu: $e');
    }
  }

  Future<void> _initHotkeyManager() async {
    try {
      await hotKeyManager.unregisterAll();
    } catch (e) {
      debugPrint('HotKeyManager: Could not unregister: $e');
    }
  }

  Future<void> _initNotifications() async {
    try {
      await localNotifier.setup(
        appName: 'Lang',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
    } catch (e) {
      debugPrint('LocalNotifier: Setup failed: $e');
    }
  }

  // Window management
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    _isWindowVisible = true;
  }

  Future<void> hideWindow() async {
    await windowManager.hide();
    _isWindowVisible = false;
  }

  Future<void> toggleWindow() async {
    if (_isWindowVisible) {
      await hideWindow();
    } else {
      await showWindow();
    }
  }

  Future<void> setAlwaysOnTop(bool value) async {
    await windowManager.setAlwaysOnTop(value);
    _isAlwaysOnTop = value;
  }

  Future<void> toggleAlwaysOnTop() async {
    await setAlwaysOnTop(!_isAlwaysOnTop);
  }

  Future<void> minimizeWindow() async {
    await windowManager.minimize();
  }

  Future<void> maximizeWindow() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> closeWindow() async {
    await windowManager.close();
  }

  Future<void> setWindowSize(Size size) async {
    await windowManager.setSize(size);
  }

  Future<void> setWindowTitle(String title) async {
    await windowManager.setTitle(title);
  }

  // System tray
  void onTrayIconClicked(VoidCallback callback) {
    _trayCallbacks.add(callback);
  }

  Future<void> updateTrayMenu(Map<String, String> items) async {
    final menuItems = <MenuItem>[];
    for (final entry in items.entries) {
      menuItems.add(MenuItem(key: entry.key, label: entry.value));
    }
    try {
      await trayManager.setContextMenu(Menu(items: menuItems));
    } catch (e) {
      debugPrint('TrayManager: Could not update menu: $e');
    }
  }

  // Global hotkeys
  Future<void> registerHotkey(
    String keyId,
    HotKey hotkey,
    VoidCallback callback,
  ) async {
    try {
      await hotKeyManager.register(
        hotkey,
        keyDownHandler: (hotKey) {
          callback();
          _hotkeyCallbacks[keyId]?.call();
        },
      );
      _hotkeyCallbacks[keyId] = callback;
    } catch (e) {
      debugPrint('HotKeyManager: Could not register $keyId: $e');
    }
  }

  Future<void> unregisterHotkey(String keyId, HotKey hotkey) async {
    try {
      await hotKeyManager.unregister(hotkey);
      _hotkeyCallbacks.remove(keyId);
    } catch (e) {
      debugPrint('HotKeyManager: Could not unregister $keyId: $e');
    }
  }

  Future<void> unregisterAllHotkeys() async {
    try {
      await hotKeyManager.unregisterAll();
      _hotkeyCallbacks.clear();
    } catch (e) {
      debugPrint('HotKeyManager: Could not unregister all: $e');
    }
  }

  // Register common hotkeys
  Future<void> registerCommonHotkeys({
    required VoidCallback onShowStudy,
    required VoidCallback onShowBrowser,
    required VoidCallback onToggleWindow,
  }) async {
    if (!isSupported) return;

    // Ctrl+Shift+S = Show Study
    await registerHotkey(
      'study',
      HotKey(
        key: PhysicalKeyboardKey.keyS,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      ),
      onShowStudy,
    );

    // Ctrl+Shift+B = Show Browser
    await registerHotkey(
      'browser',
      HotKey(
        key: PhysicalKeyboardKey.keyB,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      ),
      onShowBrowser,
    );

    // Ctrl+Shift+L = Toggle window
    await registerHotkey(
      'toggle',
      HotKey(
        key: PhysicalKeyboardKey.keyL,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      ),
      onToggleWindow,
    );
  }

  // Register screenshot hotkeys. Each capture kind gets one combo
  // (PrintScreen as base key, modified with Ctrl / Shift / Alt):
  // - Ctrl+Shift+PrintScreen: fullscreen
  // - Ctrl+PrintScreen: monitor
  // - Shift+PrintScreen: window
  // - Alt+PrintScreen: region (interactive)
  // - Alt+Shift+PrintScreen: previous region
  // - Ctrl+Alt+PrintScreen: toggle auto screenshot (interval from
  //   AppState; 0 = off)
  Future<void> registerScreenshotHotkeys({
    required Future<void> Function() onFullscreen,
    required Future<void> Function() onMonitor,
    required Future<void> Function() onWindow,
    required Future<void> Function() onRegion,
    required Future<void> Function() onPreviousRegion,
    required Future<void> Function() onToggleAuto,
  }) async {
    if (!isSupported) return;

    await registerHotkey(
      'screenshot_fullscreen',
      HotKey(
        key: PhysicalKeyboardKey.printScreen,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
      ),
      () => onFullscreen(),
    );
    await registerHotkey(
      'screenshot_monitor',
      HotKey(
        key: PhysicalKeyboardKey.printScreen,
        modifiers: [HotKeyModifier.control],
      ),
      () => onMonitor(),
    );
    await registerHotkey(
      'screenshot_window',
      HotKey(
        key: PhysicalKeyboardKey.printScreen,
        modifiers: [HotKeyModifier.shift],
      ),
      () => onWindow(),
    );
    await registerHotkey(
      'screenshot_region',
      HotKey(
        key: PhysicalKeyboardKey.printScreen,
        modifiers: [HotKeyModifier.alt],
      ),
      () => onRegion(),
    );
    await registerHotkey(
      'screenshot_previous_region',
      HotKey(
        key: PhysicalKeyboardKey.printScreen,
        modifiers: [HotKeyModifier.alt, HotKeyModifier.shift],
      ),
      () => onPreviousRegion(),
    );
    await registerHotkey(
      'screenshot_auto_toggle',
      HotKey(
        key: PhysicalKeyboardKey.printScreen,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
      ),
      () => onToggleAuto(),
    );
  }

  // Desktop notifications
  Future<void> showNotification({
    required String title,
    required String body,
    bool isUrgent = false,
  }) async {
    if (!isSupported) return;

    try {
      final notification = LocalNotification(title: title, body: body);
      await notification.show();
    } catch (e) {
      debugPrint('LocalNotifier: Show failed: $e');
    }
  }

  Future<void> showStudyReminder(int dueCount) async {
    if (dueCount > 0) {
      await showNotification(
        title: '📚 Study Reminder',
        body: 'You have $dueCount cards due for review!',
      );
    }
  }

  Future<void> showAchievementNotification(String title, String body) async {
    await showNotification(title: '🏆 $title', body: body, isUrgent: false);
  }

  // File drop handling
  void onFilesDropped(VoidCallback callback) {
    _fileDropCallbacks.add(callback);
  }

  Future<List<String>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
    );

    return result?.files.map((f) => f.path).whereType<String>().toList() ?? [];
  }

  Future<List<String>> pickMediaFiles() async {
    return pickFiles(
      allowedExtensions: [
        'mp3',
        'mp4',
        'wav',
        'ogg',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
      ],
    );
  }

  Future<List<String>> pickAnkiFiles() async {
    return pickFiles(allowedExtensions: ['apkg'], allowMultiple: true);
  }

  // TrayListener implementation
  @override
  void onTrayIconMouseDown() {
    for (final callback in _trayCallbacks) {
      callback();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showWindow();
        break;
      case 'always_on_top':
        toggleAlwaysOnTop();
        break;
      case 'study':
        showWindow();
        onStudyRequested?.call();
        break;
      case 'browser':
        showWindow();
        onBrowserRequested?.call();
        break;
      case 'quit':
        onQuitRequested?.call();
        closeWindow();
        break;
    }
  }

  // WindowListener implementation
  @override
  void onWindowClose() async {
    await hideWindow();
  }

  @override
  void onWindowFocus() {}

  @override
  void onWindowBlur() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowMoved() {}

  @override
  void onWindowResized() {}

  Future<void> dispose() async {
    try {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
      await unregisterAllHotkeys();
      await trayManager.destroy();
    } catch (e) {
      debugPrint('DesktopIPCService: Dispose error: $e');
    }
  }
}
