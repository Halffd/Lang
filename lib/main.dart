import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:lang/utils/layout_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter_inappwebview_linux/flutter_inappwebview_linux.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'presentation/widgets/structured_definition.dart';
import 'utils/font_scale.dart';
import 'utils/japanese_grammar.dart';
import 'utils/popup_scan_blocker.dart';
import 'utils/script_converter.dart';
import 'utils/compound_reading.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/services/app_storage.dart';
import 'core/services/clipboard_manager_service.dart';
import 'core/services/mobile_listening_service.dart';
import 'presentation/screens/clipboard_manager_screen.dart';
import 'core/services/clipboard_monitor_service.dart';
import 'core/services/history_service.dart';
import 'core/services/image_clipboard_service.dart';
import 'core/services/live_ocr/live_ocr_controller.dart';
import 'core/services/live_ocr/live_ocr_service.dart';
import 'core/services/popup_dictionary_controller.dart';
import 'core/services/screenshot_service.dart';
import 'core/services/supabase_service.dart';
import 'data/services/ocr_service.dart';
import 'data/services/anki_connect_service.dart';
import 'core/services/realtime_sync_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/desktop_ipc_service.dart';
import 'data/datasources/ai_local_data_source.dart';
import 'data/datasources/ai_remote_data_source.dart';
import 'data/repositories/ai_repository_impl.dart';
import 'data/repositories/srs_service.dart';
import 'domain/entities/dictionary.dart'
    show DictionaryEntry, YomichanSearchResult;
import 'domain/entities/app_state.dart';
import 'domain/entities/popup_dictionary_config.dart';
import 'presentation/providers/analyzer_provider.dart';
import 'presentation/widgets/bottom_bar.dart';
import 'presentation/widgets/app_context_menu_scope.dart';
import 'presentation/nav_destinations.dart';
import 'presentation/providers/ai_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'data/datasources/supabase_data_source.dart';
import 'core/services/srs_service.dart' as srs_core;
import 'presentation/providers/srs_provider.dart';
import 'presentation/providers/supabase_provider.dart';
import 'presentation/providers/user_profile_provider.dart';
import 'presentation/providers/user_data_provider.dart';
import 'presentation/screens/reader/pip_windows.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/widgets/user_badge.dart';
import 'presentation/widgets/font_zoom_scope.dart';
import 'presentation/widgets/live_ocr_overlay.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Secondary windows (desktop PiP mini-player, popup captions) run a
  // dedicated app instead of the main shell. Their role arrives in the
  // window arguments (JSON with a "mode" key).
  try {
    final controller = await WindowController.fromCurrentEngine();
    final args0 = controller.arguments;
    if (args0.isNotEmpty && args0.trim().startsWith('{')) {
      final cfg = (jsonDecode(args0) as Map).map(
        (k, v) => MapEntry(k.toString(), v),
      );
      final mode = cfg['mode']?.toString() ?? '';
      if (mode == 'pip') {
        final session = PipSession.fromJson(cfg);
        runApp(PipPlayerApp(session: session));
        return;
      }
      if (mode == 'captions') {
        runApp(const CaptionsWindowApp());
        return;
      }
    }
  } catch (_) {
    // main window (no window definition registered) — fall through
  }

  // Cap the global image cache: the default (100 MiB / 1000 entries)
  // lets full-resolution screenshots and manga pages pile up. 64 MiB of
  // decoded pixels is plenty for thumbnails + a few live views, and the
  // readers decode-on-demand with their own bounded caches.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 200;

  // video_player ships no desktop implementation; fvp registers the mdk
  // engine as its backend so the player tab plays on Linux and Windows.
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    fvp.registerWith();
  }
  // mobile listening mode: background-audio stack for the video tab
  // (media notification, screen-off playback)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await MobileListeningService.instance.init();
  }
  // Linux in-app webview: register the platform implementation only when
  // WPE WebKit is actually present — the vendored plugin builds a stub on
  // hosts without it (CI), where the browser tab falls back to the
  // system browser instead of a dead embedded webview.
  if (!kIsWeb && Platform.isLinux) {
    var wpeAvailable = false;
    for (final pkg in ['wpe-webkit-2.0', 'wpe-webkit-1.1', 'wpe-webkit-1.0']) {
      final r = Process.runSync('pkg-config', ['--exists', pkg]);
      if (r.exitCode == 0) {
        wpeAvailable = true;
        break;
      }
    }
    if (wpeAvailable) {
      LinuxInAppWebViewPlatform.registerWith();
    } else {
      debugPrint('WPE WebKit not found — browser tab uses the system browser');
    }
  }

  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final desktopIPC = DesktopIPCService();
  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    await desktopIPC.initialize();
  }

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  final supabaseService = SupabaseService();
  final syncService = RealtimeSyncService();
  final storageService = StorageService();
  await storageService.init();
  SRSService? srsServiceLegacy;
  SupabaseDataSource? supabaseDataSource;
  srs_core.SrsService? srsServiceCore;

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await supabaseService.init(url: supabaseUrl, anonKey: supabaseAnonKey);
      await supabaseService.signInAnonymously();
      supabaseDataSource = SupabaseDataSource(Supabase.instance.client);
      srsServiceCore = srs_core.SrsService();
      syncService.connect();
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  }

  final aiRemoteDataSource = AiRemoteDataSource();
  final aiLocalDataSource = AiLocalDataSource();

  final aiRepository = AiRepositoryImpl(
    remoteDataSource: aiRemoteDataSource,
    localDataSource: aiLocalDataSource,
  );

  final appState = AppState(storageService);
  // document-store backend (SQLite vs local files) must be chosen before
  // any service loads its payloads
  await AppStorage.init(storageBackendFromName(appState.storageBackend));

  final analyzerProvider = AnalyzerProvider();
  await analyzerProvider.init();
  // Sync provider learning language with persisted preference
  analyzerProvider.appState = appState;
  analyzerProvider.restoreLanguage(appState.learningLanguage);

  // Feed layout settings into the shared LayoutConfig so every widget sees
  // them without needing Provider.
  _syncLayout(appState);
  appState.addListener(() => _syncLayout(appState));

  // Clipboard history: record copied text in the activity feed
  await HistoryService.instance.load();
  // clipboard manager (CopyQ-style store): the monitor pushes every
  // captured text/image into it, then the auto-search hooks run.
  await ClipboardManagerService.instance.load();
  final clipboardMonitor = ClipboardMonitorService.instance;
  clipboardMonitor.onClipboardChanged = (text) {
    ClipboardManagerService.instance.addText(text);
    analyzerProvider.searchWord(text);
  };
  // auto OCR for clipboard images: store, recognize, then search
  final ocrService = OcrService();
  await ocrService.initialize();
  clipboardMonitor.onClipboardImage = (imageBytes) async {
    await ClipboardManagerService.instance.addImage(imageBytes);
    try {
      final result = await ocrService.recognizeFromBytes(
        imageBytes,
        engine: OcrService.engineFromName(null),
      );
      if (result.isSuccess) return result.text;
      return null;
    } catch (_) {
      return null;
    }
  };
  // popup dictionary: global yomichan-style lookup on any screen
  _setupPopupDictionary(appState, analyzerProvider);

  // live OCR: continuous screen capture -> OCR -> translation overlay.
  // The loop is driven by the persisted "live OCR enabled" setting and
  // follows the OCR engine / language settings while it runs.
  final liveOcrController = LiveOcrController();
  liveOcrController.attach(
    appState: appState,
    ocrService: ocrService,
    translationService: buildLiveOcrTranslationService(
      appState: appState,
      geminiApiKey: await SharedPreferences.getInstance()
          .then((p) => p.getString('geminiApiKey')),
    ),
    // the loop reports its own failures, so it needs the messages in
    // the UI language
    errorMessages: _liveOcrErrorMessages(appState.language),
  );

  // clipboard resume catch-up (mobile background listening)
  WidgetsBinding.instance.addObserver(
    _ClipboardResumeObserver(monitor: clipboardMonitor, appState: appState),
  );

  clipboardMonitor.startMonitoring(appState);
  // restart monitor when clipboard settings change
  appState.addListener(() {
    clipboardMonitor.restartMonitoring(appState);
  });

  // screenshots: restore registry, restart auto capture on its saved
  // interval, register global hotkeys for each capture kind
  ScreenshotService.instance.directoryOverride = appState.screenshotDirectory;
  await ScreenshotService.instance.load();
  // a directory change takes effect on the next capture
  appState.addListener(() {
    ScreenshotService.instance.directoryOverride = appState.screenshotDirectory;
  });

  Future<String?> ocrRunner(String path) async {
    try {
      // honor the persisted OCR engine choice; ai falls back to the
      // platform default since the AI provider isn't wired into hotkeys
      var engine = OcrService.engineFromName(appState.ocrEngine);
      if (engine == OcrEngine.ai) engine = OcrService.engineFromName(null);
      if (appState.ocrApiEndpoint.isNotEmpty) {
        ocrService.apiEndpoint = appState.ocrApiEndpoint;
      }
      final result = await ocrService.recognizeFromFile(
        path,
        engine: engine,
        language: appState.learningLanguage,
        apiKey: appState.ocrApiKey,
      );
      return result.isSuccess ? result.text : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> runAutoOcr(ScreenshotItem item) async {
    if (!appState.screenshotAutoOcr) return;
    try {
      final text = await ocrRunner(item.path);
      if (text != null && text.trim().isNotEmpty) {
        ScreenshotService.instance.setOcrText(item.id, text.trim());
        if (appState.screenshotCopyOcrText) {
          await Clipboard.setData(ClipboardData(text: text.trim()));
        }
      }
    } catch (_) {
      // auto OCR is best-effort
    }
  }

  Future<void> copyImageRunner(String path) async {
    final bytes = await File(path).readAsBytes();
    await ImageClipboardService.copyPng(bytes);
  }

  Future<void> copyTextRunner(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  if (appState.screenshotAutoIntervalMin > 0) {
    ScreenshotService.instance.startAutoCapture(
      intervalMinutes: appState.screenshotAutoIntervalMin,
      onCaptured: runAutoOcr,
    );
  }
  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    Future<void> captureHotkey(ScreenshotKind kind) async {
      final item = await ScreenshotService.instance.captureWithPipeline(
        kind,
        autoOcr: appState.screenshotAutoOcr,
        copyOcrText: appState.screenshotCopyOcrText,
        copyImage: appState.screenshotCopyImage,
        ocrRunner: ocrRunner,
        copyImageRunner: copyImageRunner,
        copyTextRunner: copyTextRunner,
      );
      if (item != null) {
        await desktopIPC.showNotification(
          title: 'Screenshot',
          body: 'Captured ${kind.name}',
        );
      }
    }

    desktopIPC.registerScreenshotHotkeys(
      onFullscreen: () => captureHotkey(ScreenshotKind.fullscreen),
      onMonitor: () => captureHotkey(ScreenshotKind.monitor),
      onWindow: () => captureHotkey(ScreenshotKind.window),
      onRegion: () => captureHotkey(ScreenshotKind.region),
      onPreviousRegion: () => captureHotkey(ScreenshotKind.previousRegion),
      onToggleAuto: () async {
        // toggle between off and the saved interval (1 min default)
        final current = appState.screenshotAutoIntervalMin;
        final next = current > 0 ? 0 : 1;
        appState.setScreenshotAutoIntervalMin(next);
        if (next > 0) {
          ScreenshotService.instance.startAutoCapture(
            intervalMinutes: next,
            onCaptured: runAutoOcr,
          );
        } else {
          ScreenshotService.instance.stopAutoCapture();
        }
      },
    );

    // Ctrl+Shift+O = OCR the newest clipboard image (or the newest
    // screenshot when the clipboard has no image) and copy the
    // recognized text.
    desktopIPC.registerOcrHotkey(
      onOcr: () async {
        final manager = ClipboardManagerService.instance;
        await manager.load();
        ClipboardItem? imageEntry;
        for (final item in manager.items) {
          if (item.isImage) {
            imageEntry = item;
            break;
          }
        }
        // the temp dir is owned by this block and removed afterwards
        Directory? tempDir;
        String? path;
        try {
          if (imageEntry != null) {
            final bytes = await manager.readImageBytes(imageEntry);
            if (bytes != null) {
              tempDir = await Directory.systemTemp.createTemp('ocr_hotkey');
              final file = File('${tempDir.path}/clip.png');
              await file.writeAsBytes(bytes, flush: true);
              path = file.path;
            }
          } else {
            final shots = ScreenshotService.instance.items;
            if (shots.isNotEmpty) {
              path = await ScreenshotService.instance.materializePath(
                shots.first,
              );
            }
          }
          if (path == null) {
            await desktopIPC.showNotification(
              title: 'OCR',
              body: 'No image to recognize',
            );
            return;
          }
          final text = await ocrRunner(path);
          if (text != null && text.trim().isNotEmpty) {
            await Clipboard.setData(ClipboardData(text: text.trim()));
            await desktopIPC.showNotification(
              title: 'OCR',
              body: text.trim(),
            );
          } else {
            await desktopIPC.showNotification(
              title: 'OCR',
              body: 'No text recognized',
            );
          }
        } finally {
          if (tempDir != null) {
            try {
              await tempDir.delete(recursive: true);
            } catch (_) {
              // the OS cleans the temp dir eventually
            }
          }
        }
      },
    );
  }

  final aiProvider = AiProvider(aiRepository);
  await aiProvider.init();

  srsServiceLegacy = SRSService(storageService);
  await srsServiceLegacy.initialize();

  SupabaseProvider? supabaseProvider;
  SrsProvider? srsProvider;
  UserDataProvider? userDataProvider;
  final userProfileProvider = UserProfileProvider(
    ds: supabaseDataSource,
    syncService: syncService,
  );
  if (supabaseDataSource != null && srsServiceCore != null) {
    supabaseProvider = SupabaseProvider(
      supabaseService: supabaseService,
      syncService: syncService,
    );
    srsProvider = SrsProvider(
      srsService: srsServiceCore,
      supabaseDataSource: supabaseDataSource,
      syncService: syncService,
    );
    await srsProvider.init();
    userDataProvider = UserDataProvider(dataSource: supabaseDataSource);

    // Auto-sync saved words on startup and on local changes (debounced).
    void pushPulledWords(List<Map<String, dynamic>> rows) {
      for (final r in rows) {
        final w = r['word'] as String?;
        if (w != null) appState.addSavedWord(w, details: r);
      }
    }

    Future<void> runSync() async {
      final words = <Map<String, dynamic>>[
        for (final w in appState.savedWords)
          <String, dynamic>{'word': w, ...?appState.savedWordsDetails[w]},
      ];
      final missing = await userDataProvider!.syncSavedWords(words);
      pushPulledWords(missing);
    }

    // Initial sync, then debounce on saved-words changes.
    unawaited(runSync());
    Timer? debounce;
    int lastWordsLen = appState.savedWords.length;
    appState.addListener(() {
      final len = appState.savedWords.length;
      if (len != lastWordsLen) {
        lastWordsLen = len;
        debounce?.cancel();
        debounce = Timer(const Duration(seconds: 5), runSync);
      }
    });

    // Realtime: when another device writes a saved word, pull it down.
    syncService.onSavedWordsChange((table, newRow, oldRow) {
      if (newRow != null) {
        final w = newRow['word'] as String?;
        if (w != null && !appState.savedWords.contains(w)) {
          appState.addSavedWord(w, details: newRow);
        }
      }
    });

    // Realtime: history items recorded on another device add themselves to
    // the local history feed.
    syncService.onSeenWordsChange((table, newRow, oldRow) {
      final word = newRow?['word'] as String?;
      if (word != null &&
          word.isNotEmpty &&
          !HistoryService.instance.items.any(
            (i) => i.category == HistoryCategory.word && i.title == word,
          )) {
        HistoryService.instance.record(
          HistoryCategory.word,
          word,
          subtitle: 'synced',
        );
      }
    });
  }

  // profile loads from local prefs + pulls from Supabase when available
  await userProfileProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: analyzerProvider),
        ChangeNotifierProvider.value(value: aiProvider),
        ChangeNotifierProvider.value(value: srsServiceLegacy),
        ChangeNotifierProvider.value(value: userProfileProvider),
        ChangeNotifierProvider.value(value: liveOcrController),
        if (supabaseProvider != null)
          ChangeNotifierProvider.value(value: supabaseProvider),
        if (srsProvider != null)
          ChangeNotifierProvider.value(value: srsProvider),
        if (userDataProvider != null)
          ChangeNotifierProvider.value(value: userDataProvider),
      ],
      child: LangApp(
        analyzerProvider: analyzerProvider,
        liveOcrController: liveOcrController,
      ),
    ),
  );
}

/// The messages the live-OCR loop reports its own failures with, in
/// the UI language.
LiveOcrErrorMessages _liveOcrErrorMessages(String languageCode) {
  final l10n = lookupAppLocalizations(Locale(languageCode));
  return LiveOcrErrorMessages(
    notConfigured: l10n.liveOcrNotConfigured,
    captureFailed: l10n.liveOcrCaptureFailed,
    ocrFailed: l10n.liveOcrOcrFailed,
  );
}

/// Feed AppState layout settings into the global LayoutConfig.
void _syncLayout(AppState a) {
  LayoutConfig.instance.update(
    mode: switch (a.layoutMode) {
      'mobile' => LayoutMode.mobile,
      'tablet' => LayoutMode.tablet,
      'desktop' => LayoutMode.desktop,
      // 'centered' was removed (it capped the content width); fall back to auto
      _ => LayoutMode.auto,
    },
    paddingScale: a.paddingScale,
    marginScale: a.marginScale,
    borderRadiusScale: a.borderRadiusScale,
    borderWidthScale: a.borderWidthScale,
  );
}

/// Wire the global popup dictionary: config from app state,
/// lookup through the shared analyzer pipeline (yomichan lookup +
/// dictionary settings filtering), auto-anki + auto-copy actions.
void _setupPopupDictionary(AppState appState, AnalyzerProvider analyzer) {
  final controller = PopupDictionaryController.instance;
  controller.config = appState.popupDictionaryConfig;
  controller.currentLearningLanguage = appState.learningLanguage;
  controller.activeProfileName = appState.currentProfile;

  // profile alternation: follow the active SRS profile name
  appState.addListener(() {
    controller.updateConfig(appState.popupDictionaryConfig);
    controller.currentLearningLanguage = appState.learningLanguage;
    controller.activeProfileName = appState.currentProfile;
    // the video tab's modifier-free hover follows the setting, so
    // toggling it takes effect without leaving the screen
    if (controller.routeName == 'video') {
      controller.plainHoverEnabled = appState.showHoverDefinitions;
    }
  });

  // modifier keys feed the shift/ctrl/alt/meta hover triggers
  HardwareKeyboard.instance.addHandler((event) {
    final map = <PhysicalKeyboardKey, PopupExtraModifier>{
      PhysicalKeyboardKey.shiftLeft: PopupExtraModifier.shift,
      PhysicalKeyboardKey.shiftRight: PopupExtraModifier.shift,
      PhysicalKeyboardKey.controlLeft: PopupExtraModifier.ctrl,
      PhysicalKeyboardKey.controlRight: PopupExtraModifier.ctrl,
      PhysicalKeyboardKey.altLeft: PopupExtraModifier.alt,
      PhysicalKeyboardKey.altRight: PopupExtraModifier.alt,
      PhysicalKeyboardKey.metaLeft: PopupExtraModifier.meta,
      PhysicalKeyboardKey.metaRight: PopupExtraModifier.meta,
    };
    for (final entry in map.entries) {
      if (event.physicalKey == entry.key) {
        controller.onModifierKey(event is KeyDownEvent, entry.value);
        // hover triggers need the current position re-evaluated;
        // the next hover event handles that
        break;
      }
    }
    return false;
  });

  controller.lookupBuilder = (context, lookup) async {
    final config = controller.config;
    final candidates = JapaneseGrammar.popupLookupCandidates(
      lookup.term,
      detectCompounds: config.detectCompounds,
      detectConjugations: config.detectConjugations,
    );
    for (final candidate in candidates) {
      final results = await analyzer.lookupWordDirect(candidate);
      if (results.isEmpty) continue;
      if (results.firstOrNull == null) continue;

      var result = results.first;
      // A compound without its own dictionary entry resolves to a
      // shorter prefix, whose reading describes only part of the
      // scanned text. Rebuild the reading from the parts so the popup
      // shows the reading of the whole term the user selected.
      if (candidate != lookup.term && result.entry.term != lookup.term) {
        final compound = await CompoundReading.build(lookup.term);
        if (compound != null && compound.isNotEmpty) {
          result = _withReading(result, compound);
        }
      }
      final shown = result;
      return _PopupDictionaryBody(
        result: shown,
        sentence: lookup.sentence,
        onAnki: () async {
          final config = controller.config;
          if (!config.autoAnki) return;
          try {
            final anki = AnkiConnectService();
            final deck = config.ankiDeck.isEmpty
                ? 'Lang Popup'
                : config.ankiDeck;
            await anki.addNote(
              deckName: deck,
              modelName: 'Lang Popup Note',
              fields: {
                'Word': shown.entry.term,
                'Reading': shown.entry.reading,
                'Meaning': shown.entry.definitions.take(3).join('; '),
                'Sentence': lookup.sentence,
              },
            );
          } catch (_) {
            // anki is best-effort
          }
        },
      );
    }
    return null;
  };
}

/// A copy of [result] whose entry carries [reading].
///
/// The entry is immutable, so the copy is built from its fields.
YomichanSearchResult _withReading(YomichanSearchResult result, String reading) {
  final entry = result.entry;
  return YomichanSearchResult(
    entry: DictionaryEntry(
      id: entry.id,
      dictionaryId: entry.dictionaryId,
      term: entry.term,
      reading: reading,
      definitionTags: entry.definitionTags,
      rules: entry.rules,
      popularity: entry.popularity,
      definitions: entry.definitions,
      sequence: entry.sequence,
      termTags: entry.termTags,
      audioUrl: entry.audioUrl,
      imageUrl: entry.imageUrl,
      imageCaption: entry.imageCaption,
    ),
    dictionary: result.dictionary,
    pitches: result.pitches,
    tones: result.tones,
    frequencies: result.frequencies,
  );
}

/// Compact popup body for a dictionary result.
class _PopupDictionaryBody extends StatefulWidget {
  final YomichanSearchResult result;
  final String sentence;
  final VoidCallback onAnki;

  const _PopupDictionaryBody({
    required this.result,
    required this.sentence,
    required this.onAnki,
  });

  @override
  State<_PopupDictionaryBody> createState() => _PopupDictionaryBodyState();
}

class _PopupDictionaryBodyState extends State<_PopupDictionaryBody> {
  @override
  void initState() {
    super.initState();
    // fire-and-forget: auto-anki runs once when the popup is shown
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onAnki());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final entry = result.entry;
    final appState = Provider.of<AppState>(context, listen: false);
    final popupConfig = PopupDictionaryController.instance.config;
    final fontScale = popupConfig.fontScale.clamp(0.5, 2.0);
    final reading = _displayReading(entry.term, entry.reading, popupConfig);
    // The headword must never wrap one character per line. A long
    // term in a narrow popup has no room to break, and Flutter's CJK
    // line breaking falls back to a character break. The headword
    // therefore gets its own line and never shares a row with the
    // reading, so it can use the popup's full width.
    final headword = Text(
      entry.term,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fs(context, 20, 'kanji') * fontScale,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headword,
        if (reading != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              reading,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fs(context, 12, 'words') * fontScale,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        if (entry.definitions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Flexible(
            child: SingleChildScrollView(
              child: StructuredDefinition(
                definition: entry.definitions.first,
                fontSize: (12 * fontScale).roundToDouble(),
                // popup: theme colors — dictionary accent colors don't
                // paint every letter red
                optionsOverride: appState.dictionaryDisplayOptions.copy()
                  ..respectContentColors = false,
              ),
            ),
          ),
        ],
        if (popupConfig.showSentence && widget.sentence.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.sentence,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fs(context, 10, 'ui') * fontScale,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }

  /// The reading to show in the popup header, or null when none should
  /// be shown.
  ///
  /// A kana-only term (no kanji) has the same text as its reading, so
  /// showing it repeats the word. That is only useful when the reading
  /// is rendered in romaji, where the kana and its romaji differ — so
  /// the kana-only reading follows the [readingDisplay] setting unless
  /// the user explicitly turned it on.
  static String? _displayReading(
    String term,
    String reading,
    PopupDictionaryConfig config,
  ) {
    if (!config.showReading || reading.isEmpty) return null;
    final kanaOnly = _isKanaOnly(term);
    if (kanaOnly && !config.showKanaOnlyReading) return null;
    if (config.readingDisplay == 'romaji') {
      return ScriptConverter.kanaToRomaji(reading);
    }
    return reading;
  }

  /// Whether [text] consists only of hiragana/katakana (no kanji, no
  /// latin, no other scripts).
  static bool _isKanaOnly(String text) {
    if (text.isEmpty) return false;
    for (final rune in text.runes) {
      final isKana = (rune >= 0x3040 && rune <= 0x309F) || // hiragana
          (rune >= 0x30A0 && rune <= 0x30FF) || // katakana
          (rune >= 0xFF66 && rune <= 0xFF9D); // halfwidth kana
      if (!isKana) return false;
    }
    return true;
  }
}

class LangApp extends StatelessWidget {
  const LangApp({
    super.key,
    required this.analyzerProvider,
    required this.liveOcrController,
  });

  final AnalyzerProvider analyzerProvider;
  final LiveOcrController liveOcrController;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF7C3AED);

    return Consumer<AppState>(
      builder: (context, appState, child) {
        // Map the user's language preference to a locale we have UI
        // translations for (en, es, ja, zh). Falls back to English.
        final uiLocale = switch (appState.language) {
          'ja' => const Locale('ja'),
          'zh' => const Locale('zh'),
          'es' => const Locale('es'),
          _ => const Locale('en'),
        };

        // UI chrome scale: box paddings, bar heights, icon and label
        // sizes grow with the same font multiplier the text uses, so
        // touch targets and boxes keep pace with large font settings
        // (high-DPI phones, accessibility zoom).
        final uiScale = (appState.fontSizeMultiplier * appState.fontSettings.ui)
            .clamp(1.0, 2.5);
        double ui(double v) => v * uiScale;

        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: uiLocale,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme:
                ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.dark,
                  surface: const Color(0xFF1C1B1F),
                ).copyWith(
                  primary: const Color(0xFF8B5CF6),
                  secondary: const Color(0xFFA78BFA),
                  tertiary: const Color(0xFF06B6D4),
                  surfaceContainerHighest: const Color(0xFF2D2B33),
                ),
            scaffoldBackgroundColor: const Color(0xFF1C1B1F),
            textTheme: const TextTheme(
              headlineLarge: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              headlineMedium: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
              titleLarge: TextStyle(fontWeight: FontWeight.w600),
              titleMedium: TextStyle(fontWeight: FontWeight.w500),
              bodyLarge: TextStyle(height: 1.5),
              bodyMedium: TextStyle(height: 1.4),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
              color: const Color(0xFF2D2B33),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              backgroundColor: Color(0xFF1C1B1F),
              titleTextStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF2D2B33),
              // text boxes grow with the font scale so text never
              // overflows and tap targets keep pace
              contentPadding: EdgeInsets.symmetric(
                horizontal: ui(16),
                vertical: ui(14),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5CF6),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1,
                ),
              ),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: const Color(0xFF2D2B33),
              selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              labelStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              elevation: 2,
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              elevation: 0,
              // taller bar with scaled labels/icons: readable at large
              // font scales and high-DPI screens
              height: ui(70),
              backgroundColor: const Color(0xFF1C1B1F),
              indicatorColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  size: ui(24),
                  color: states.contains(WidgetState.selected)
                      ? const Color(0xFF8B5CF6)
                      : Colors.white.withValues(alpha: 0.6),
                ),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return TextStyle(
                    fontSize: ui(12),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8B5CF6),
                  );
                }
                return TextStyle(
                  fontSize: ui(12),
                  color: Colors.white.withValues(alpha: 0.6),
                );
              }),
            ),
            dividerTheme: DividerThemeData(
              color: Colors.white.withValues(alpha: 0.08),
              thickness: 1,
              space: 1,
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: const Color(0xFF2D2B33),
              contentTextStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              behavior: SnackBarBehavior.floating,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF2D2B33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titleTextStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF2D2B33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            listTileTheme: ListTileThemeData(
              contentPadding: EdgeInsets.symmetric(
                horizontal: ui(16),
                vertical: ui(4),
              ),
              minLeadingWidth: 24,
            ),
            iconTheme: IconThemeData(size: ui(22), color: Colors.white70),
          ),
          home: PopupDictionaryScope(
            child: AppContextMenuScope(
              // Right-click outside a text field opens the app's own
              // menu (look up / copy the word under the cursor).
              child: MainNavigationShell(
                liveOcrController: liveOcrController,
              ),
            ),
          ),
          // Global text zoom (ctrl+scroll, pinch) wraps every route.
          // Layout is deliberately not width-capped: content fills the window.
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return FontZoomScope(
              // three-finger tap saves the analyzer's selected word —
              // the provider is a ChangeNotifier already in scope here
              onThreeFingerTap: () {
                final word = analyzerProvider.selectedWord;
                if (word != null) {
                  analyzerProvider.saveWord(word.word);
                }
              },
              child: child,
            );
          },
        );
      },
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key, required this.liveOcrController});

  /// Drives the continuous live-OCR overlay.
  final LiveOcrController liveOcrController;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  /// The navigation destinations: one entry per screen, in order.
  /// The bottom bar renders this list, so the bar and the screen
  /// order can never drift apart (they used to be two parallel lists
  /// with different lengths, which scrambled every index after 2).
  List<NavDestination> get _destinations => navDestinations;

  /// Route names for the popup dictionary screen scope filter.
  List<String> get _routeNames =>
      _destinations.map((d) => d.route).toList(growable: false);

  @override
  void initState() {
    super.initState();
    // open on the configured default screen (a stale index from an
    // older build falls back to the first screen)
    final saved = context.read<AppState>().defaultScreenIndex;
    if (saved >= 0 && saved < _destinations.length) _currentIndex = saved;
    _syncPopupRoute(_currentIndex);
    unawaited(_setupDesktopIPC());
    // switch to Video when WhisperSubs hands off a video
    context.read<AppState>().videoNavRequest.addListener(() {
      final req = context.read<AppState>().videoNavRequest.value;
      if (req == true) {
        context.read<AppState>().videoNavRequest.value = null;
        _goToRoute('video');
      }
    });
  }

  /// Index of the destination with [route], or -1.
  int _indexOfRoute(String route) => navIndexOfRoute(route);

  /// Navigate to the destination with [route] (no-op when unknown).
  void _goToRoute(String route) {
    final index = _indexOfRoute(route);
    if (index < 0) return;
    if (mounted) setState(() => _currentIndex = index);
    _syncPopupRoute(index);
  }

  void _syncPopupRoute(int index) {
    final controller = PopupDictionaryController.instance;
    // hide popups that belong to the previous screen
    controller.onRouteChanged();
    controller.currentRouteName = (index >= 0 && index < _routeNames.length)
        ? _routeNames[index]
        : '';
    _syncPlainHover();
  }

  /// The video tab offers a modifier-free hover definition: resting
  /// the pointer on a transcript word opens its reading. Every other
  /// screen keeps the configured trigger, so the plain hover stays off
  /// there.
  void _syncPlainHover() {
    final controller = PopupDictionaryController.instance;
    final appState = context.read<AppState>();
    final onVideo = controller.routeName == 'video';
    controller.plainHoverEnabled = onVideo && appState.showHoverDefinitions;
  }

  Future<void> _setupDesktopIPC() async {
    final desktopIPC = DesktopIPCService();
    if (!desktopIPC.isSupported) return;

    desktopIPC.onStudyRequested = () => _goToRoute('study');
    desktopIPC.onReaderRequested = () => _goToRoute('reader');
    desktopIPC.onQuitRequested = () {
      desktopIPC.dispose();
      exit(0);
    };

    desktopIPC.registerCommonHotkeys(
      onShowStudy: () => _goToRoute('study'),
      onShowReader: () => _goToRoute('reader'),
      onToggleWindow: () {
        desktopIPC.toggleWindow();
      },
    );

    // Ctrl+Shift+V = clipboard manager popup (CopyQ-style). The window
    // is brought forward first, so the popup still reaches the user
    // when the app sits in the tray.
    if (desktopIPC.isSupported) {
      await desktopIPC.registerHotkey(
        'clipboard_manager',
        HotKey(
          key: PhysicalKeyboardKey.keyV,
          modifiers: const [HotKeyModifier.control, HotKeyModifier.shift],
        ),
        () async {
          final ctx = context;
          if (!ctx.mounted) return;
          await desktopIPC.showWindow();
          if (!ctx.mounted) return;
          await showClipboardManagerPopup(ctx);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        // chrome: the popup dictionary must not scan the app's own labels
        title: const PopupScanBlocker(child: UserBadge()),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              // open settings screen via route if exposed, else push
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        // the screen must still fill the body: a Stack defaults to
        // loose fit, which would let it size itself to its content
        fit: StackFit.expand,
        children: [
          _destinations[_currentIndex].screen,
          // the overlay is a Positioned widget, so it must be a direct
          // child of the Stack: the builder sits inside it
          _buildLiveOcrOverlay(context),
        ],
      ),
      // chrome: nav labels are localized app strings, not study text
      bottomNavigationBar: PopupScanBlocker(
        child: BottomBar(
          currentIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
            _syncPopupRoute(index);
          },
          destinations: [
            for (final d in _destinations)
              DestinationEntry(icon: d.icon, label: _labelFor(d, context)),
          ],
        ),
      ),
    );
  }

  /// The live-OCR overlay, drawn above the current screen.
  ///
  /// The overlay floats over the whole app, so it lives in the shell's
  /// stack rather than inside any one screen.
  Widget _buildLiveOcrOverlay(BuildContext context) {
    final controller = widget.liveOcrController;
    final appState = context.watch<AppState>();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final error = controller.lastError;
        final text = controller.stableText;
        if (text == null && error == null) return const SizedBox.shrink();
        return LiveOcrOverlay(
          sourceText: text ?? '',
          translation: controller.stableTranslation,
          error: error,
          showTranslation: appState.liveOcrShowTranslation,
          fontSize: fs(context, 16, 'words'),
        );
      },
    );
  }

  /// Localized label for a destination.
  String _labelFor(NavDestination d, BuildContext context) =>
      d.resolveLabel(AppLocalizations.of(context)!);
}

/// Reads the clipboard as soon as the app returns to the foreground:
/// the closest a clipboard manager can get to background listening on
/// Android 10+ (only the focused app may read the clipboard).
class _ClipboardResumeObserver with WidgetsBindingObserver {
  _ClipboardResumeObserver({
    required ClipboardMonitorService monitor,
    required AppState appState,
  }) : _monitor = monitor,
       _appState = appState;

  final ClipboardMonitorService _monitor;
  final AppState _appState;
  DateTime _lastCatchUp = DateTime.now().subtract(const Duration(hours: 1));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // debounce: resumed can fire repeatedly on window focus changes
    final now = DateTime.now();
    if (now.difference(_lastCatchUp) < const Duration(seconds: 2)) return;
    _lastCatchUp = now;
    unawaited(_monitor.pollNow(_appState));
  }
}
