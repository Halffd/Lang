import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:lang/core/services/history_service.dart';
import 'package:lang/domain/entities/popup_dictionary_config.dart';
import 'package:lang/utils/cjk_text_extractor.dart';

/// Result payload handed to the popup card.
class PopupLookup {
  final String term;
  final String sentence;
  final Offset position;
  final TextDirection textDirection;

  const PopupLookup({
    required this.term,
    required this.sentence,
    required this.position,
    this.textDirection = TextDirection.ltr,
  });
}

/// Global yomichan-style popup dictionary controller.
///
/// A [Listener] installed above the app's [Navigator] observes
/// pointer events everywhere; when the configured trigger fires it
/// hit-tests for a [RichText] under the pointer, extracts the
/// CJK-aware word/sentence (see [CjkTextExtractor]), runs the
/// shared lookup callback and shows the popup card through the root
/// [Overlay].
class PopupDictionaryController with ChangeNotifier {
  PopupDictionaryController._();
  static final PopupDictionaryController instance =
      PopupDictionaryController._();

  /// Lookup callback wired in main: term -> widget for the popup
  /// body (shared dictionary/detail logic). Returns null when no
  /// entry exists.
  Future<Widget?> Function(BuildContext context, PopupLookup lookup)?
  lookupBuilder;

  PopupDictionaryConfig config = PopupDictionaryConfig();
  final Set<int> _heldModifiers = {};

  OverlayEntry? _entry;
  Timer? _delayTimer;
  DateTime? _lastClick;
  int _clickCount = 0;
  bool _popupOpen = false;

  bool get isPopupOpen => _popupOpen;

  void updateConfig(PopupDictionaryConfig newConfig) {
    config = newConfig;
    if (_popupOpen) hide();
    notifyListeners();
  }

  // ----------------------------------------------------------
  // modifier tracking
  // ----------------------------------------------------------

  void onModifierKey(bool down, PopupExtraModifier modifier) {
    if (down) {
      _heldModifiers.add(modifier.index);
    } else {
      _heldModifiers.remove(modifier.index);
    }
  }

  bool _extraModifierHeld() {
    if (config.extraModifier == PopupExtraModifier.none) return true;
    // when the trigger itself is a modifier, the extra modifier is
    // optional and not required to be different
    return _heldModifiers.contains(config.extraModifier.index);
  }

  // ----------------------------------------------------------
  // pointer event handling
  // ----------------------------------------------------------

  void handlePointerEvent(PointerEvent event) {
    final trigger = config.effectiveTrigger(_activeProfileName);
    final isDown = event is PointerDownEvent;

    switch (trigger) {
      case PopupTrigger.shift:
      case PopupTrigger.ctrl:
      case PopupTrigger.alt:
      case PopupTrigger.meta:
        // modifier + hover: handled through onModifierKey + onHover
        break;
      case PopupTrigger.hover:
        if (event is PointerHoverEvent) {
          _scheduleHover(event.position, immediate: true);
        }
        break;
      case PopupTrigger.click:
        if (event is PointerDownEvent && event.buttons & kPrimaryButton != 0) {
          _maybeConsume(() => _fire(event.position, event.kind));
        }
        break;
      case PopupTrigger.doubleClick:
        if (event is PointerDownEvent &&
            event.buttons & kPrimaryButton != 0 &&
            event.kind == PointerDeviceKind.mouse) {
          _registerDoubleClick(event.position);
        }
        break;
      case PopupTrigger.rightClick:
        if (event is PointerDownEvent &&
            event.buttons & kSecondaryButton != 0) {
          _maybeConsume(() => _fire(event.position, event.kind));
        }
        break;
      case PopupTrigger.middleClick:
        if (event is PointerDownEvent && event.buttons & kTertiaryButton != 0) {
          _maybeConsume(() => _fire(event.position, event.kind));
        }
        break;
      case PopupTrigger.tap:
        if (isDown &&
            (event.kind == PointerDeviceKind.touch ||
                event.kind == PointerDeviceKind.trackpad)) {
          _maybeConsume(() => _fire(event.position, event.kind));
        }
        break;
      case PopupTrigger.longPress:
        if (isDown) {
          _delayTimer?.cancel();
          _delayTimer = Timer(
            Duration(milliseconds: config.delayMs.clamp(200, 5000)),
            () => _maybeConsume(() => _fire(event.position, event.kind)),
          );
        } else if (event is PointerUpEvent || event is PointerCancelEvent) {
          _delayTimer?.cancel();
        }
        break;
      case PopupTrigger.penTap:
        if (isDown && event.kind == PointerDeviceKind.stylus) {
          _maybeConsume(() => _fire(event.position, event.kind));
        }
        break;
      case PopupTrigger.shake:
        // detected by the shell via accelerometer; calls
        // [showAtCenter] directly
        break;
      case PopupTrigger.none:
        break;
    }
  }

  /// Called for hover triggers after modifiers state changes.
  void onHoverUpdate(PointerHoverEvent event) {
    final trigger = config.effectiveTrigger(_activeProfileName);
    if (trigger.needsModifier || trigger == PopupTrigger.hover) {
      _scheduleHover(event.position, immediate: trigger == PopupTrigger.hover);
    }
  }

  void _scheduleHover(Offset position, {required bool immediate}) {
    if (!_extraModifierHeld()) {
      _delayTimer?.cancel();
      return;
    }
    if (immediate) {
      _delayTimer?.cancel();
      _fire(position, PointerDeviceKind.mouse);
      return;
    }
    _delayTimer?.cancel();
    _delayTimer = Timer(
      Duration(milliseconds: config.delayMs.clamp(50, 2000)),
      () => _fire(position, PointerDeviceKind.mouse),
    );
  }

  void _registerDoubleClick(Offset position) {
    final now = DateTime.now();
    if (_lastClick != null &&
        now.difference(_lastClick!).inMilliseconds <= 350) {
      _clickCount++;
    } else {
      _clickCount = 1;
    }
    _lastClick = now;
    if (_clickCount >= 2) {
      _clickCount = 0;
      _maybeConsume(() => _fire(position, PointerDeviceKind.mouse));
    }
  }

  // ----------------------------------------------------------
  // external triggers
  // ----------------------------------------------------------

  /// Shake detected (accelerometer wired by the platform shell).
  void onShake() {
    if (config.effectiveTrigger(_activeProfileName) == PopupTrigger.shake) {
      showAtCenter();
    }
  }

  /// Screen-change hook so popups do not outlive their context.
  void onRouteChanged() {
    hide();
  }

  // ----------------------------------------------------------
  // lookup pipeline
  // ----------------------------------------------------------

  String? _activeProfileName;

  /// Set by the shell when the active SRS profile changes
  /// (profile alternation support).
  set activeProfileName(String? name) {
    _activeProfileName = name;
    notifyListeners();
  }

  String? get activeProfileName => _activeProfileName;

  Future<void> _fire(Offset position, PointerDeviceKind kind) async {
    if (_popupOpen) hide();

    if (!_currentRouteAllows()) return;

    final extractor = CjkTextExtractor();
    final hit = extractor.extractAt(position, config);
    if (hit == null) return;

    if (!config.languages.isEmpty &&
        !config.languages.contains(currentLearningLanguage)) {
      return;
    }
    if (!config.allowsText(hit.term)) return;

    final builder = lookupBuilder;
    final overlay = _rootOverlay;
    if (builder == null || overlay == null) return;

    final ctx = _rootContext;
    if (ctx == null) return;
    final body = await builder(
      ctx,
      PopupLookup(term: hit.term, sentence: hit.sentence, position: position),
    );
    if (body == null) return;

    _showPopup(overlay, position, body, hit.term);
  }

  /// Placeholder for the learning language, replaced via
  /// [currentLearningLanguage] by the shell.
  String currentLearningLanguage = 'ja';

  void _showPopup(
    OverlayState overlay,
    Offset position,
    Widget body,
    String term,
  ) {
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy + 18,
        child: FractionalTranslation(
          translation: const Offset(-0.4, 0),
          child: CompositedTransformFollower(
            link: LayerLink(),
            child: _PopupCard(body: body, onDismiss: hide),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
    _popupOpen = true;

    HistoryService.instance.record(
      HistoryCategory.word,
      term,
      subtitle: 'popup',
    );

    if (config.autoCopy) {
      Clipboard.setData(ClipboardData(text: term));
    }
  }

  OverlayState? get _rootOverlay {
    final ctx = _rootContext;
    if (ctx == null) return null;
    return Overlay.maybeOf(ctx, rootOverlay: true);
  }

  BuildContext? get _rootContext => _contextRef;

  /// Set by the shell with the app-level context.
  BuildContext? _contextRef;
  set rootContext(BuildContext context) => _contextRef = context;

  String? _currentRouteName;
  set currentRouteName(String name) => _currentRouteName = name;
  String get routeName => _currentRouteName ?? '';

  bool _currentRouteAllows() => config.allowsScreen(_currentRouteName ?? '');

  void showAtCenter() {
    // shake: no pointer position available; skip for now
  }

  void hide() {
    _entry?.remove();
    _entry = null;
    _popupOpen = false;
    _delayTimer?.cancel();
    notifyListeners();
  }

  void _maybeConsume(VoidCallback action) {
    // let the event continue to the app; the popup is additive and
    // non-modal by design (yomichan behaviour)
    action();
  }
}

/// The popup card chrome around the lookup body.
class _PopupCard extends StatelessWidget {
  final Widget body;
  final VoidCallback onDismiss;

  const _PopupCard({required this.body, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // full-screen tap catcher to dismiss
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
            onPanUpdate: (d) => onDismiss(),
          ),
        ),
        Container(
          width: 320,
          constraints: const BoxConstraints(maxHeight: 380),
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: body,
        ),
      ],
    );
  }
}

/// Installs the global pointer listener. Wrap the app Navigator in
/// this.
class PopupDictionaryScope extends StatefulWidget {
  final Widget child;

  const PopupDictionaryScope({super.key, required this.child});

  @override
  State<PopupDictionaryScope> createState() => _PopupDictionaryScopeState();
}

class _PopupDictionaryScopeState extends State<PopupDictionaryScope> {
  @override
  void initState() {
    super.initState();
    PopupDictionaryController.instance.rootContext = context;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: PopupDictionaryController.instance.handlePointerEvent,
      onPointerUp: PopupDictionaryController.instance.handlePointerEvent,
      onPointerHover: (e) {
        PopupDictionaryController.instance.handlePointerEvent(e);
        PopupDictionaryController.instance.onHoverUpdate(e);
      },
      onPointerCancel: PopupDictionaryController.instance.handlePointerEvent,
      child: widget.child,
    );
  }
}

/// Hook for tests: pump frames after popup actions.
@visibleForTesting
void pumpPopupFrame() {
  SchedulerBinding.instance.scheduleFrame();
}
