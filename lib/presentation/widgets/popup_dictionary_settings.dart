import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/popup_dictionary_config.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart';

/// Popup dictionary settings: trigger, modifier, delay, scan
/// options, regex gates, auto actions and screen scope.
class PopupDictionarySettings extends StatefulWidget {
  const PopupDictionarySettings({super.key});

  @override
  State<PopupDictionarySettings> createState() =>
      _PopupDictionarySettingsState();
}

class _PopupDictionarySettingsState extends State<PopupDictionarySettings> {
  late final TextEditingController _requireRegexController;
  late final TextEditingController _excludeRegexController;
  late final TextEditingController _ankiDeckController;

  @override
  void initState() {
    super.initState();
    final config = context.read<AppState>().popupDictionaryConfig;
    _requireRegexController = TextEditingController(text: config.requireRegex);
    _excludeRegexController = TextEditingController(text: config.excludeRegex);
    _ankiDeckController = TextEditingController(text: config.ankiDeck);
  }

  @override
  void dispose() {
    _requireRegexController.dispose();
    _excludeRegexController.dispose();
    _ankiDeckController.dispose();
    super.dispose();
  }

  void _update(
    AppState appState,
    PopupDictionaryConfig Function(PopupDictionaryConfig c) change,
  ) {
    appState.setPopupDictionaryConfig(change(appState.popupDictionaryConfig));
  }

  String _triggerLabel(AppLocalizations l10n, PopupTrigger t) => switch (t) {
    PopupTrigger.none => l10n.popupNone,
    PopupTrigger.hover => 'hover',
    PopupTrigger.click => 'click',
    PopupTrigger.doubleClick => 'double click',
    PopupTrigger.rightClick => 'right click',
    PopupTrigger.middleClick => 'middle click',
    PopupTrigger.shift => 'shift + hover',
    PopupTrigger.ctrl => 'ctrl + hover',
    PopupTrigger.alt => 'alt + hover',
    PopupTrigger.meta => 'meta + hover',
    PopupTrigger.tap => 'tap',
    PopupTrigger.longPress => 'long press',
    PopupTrigger.penTap => 'pen tap',
    PopupTrigger.shake => 'shake',
  };

  String _scopeLabel(AppLocalizations l10n, PopupScreenScope s) => switch (s) {
    PopupScreenScope.all => l10n.popupScreenAll,
    PopupScreenScope.analyze => l10n.popupScreenAnalyze,
    PopupScreenScope.reader => l10n.popupScreenReader,
    PopupScreenScope.dictionary => l10n.popupScreenDictionary,
    PopupScreenScope.writer => l10n.popupScreenWriter,
    PopupScreenScope.history => l10n.popupScreenHistory,
    PopupScreenScope.ai => l10n.popupScreenAI,
    PopupScreenScope.srs => l10n.popupScreenSRS,
    PopupScreenScope.custom => l10n.popupScreenAll,
  };

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final config = appState.popupDictionaryConfig;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // trigger selector
        Text(
          l10n.popupTrigger,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        DropdownButton<PopupTrigger>(
          isExpanded: true,
          value: config.trigger,
          items: [
            for (final t in PopupTrigger.values)
              DropdownMenuItem(value: t, child: Text(_triggerLabel(l10n, t))),
          ],
          onChanged: (value) {
            if (value != null) {
              _update(appState, (c) => c..trigger = value);
            }
          },
        ),
        if (config.trigger.needsModifier)
          Text(
            l10n.popupActiveTrigger(config.trigger.label),
            style: TextStyle(
              fontSize: fs(context, 11, 'ui'),
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),

        // extra modifier
        Text(
          l10n.popupExtraModifier,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        DropdownButton<PopupExtraModifier>(
          isExpanded: true,
          value: config.extraModifier,
          items: [
            for (final m in PopupExtraModifier.values)
              DropdownMenuItem(value: m, child: Text(m.name)),
          ],
          onChanged: (value) {
            if (value != null) {
              _update(appState, (c) => c..extraModifier = value);
            }
          },
        ),

        // delay
        Text('${l10n.popupDelay}: ${config.delayMs} ms'),
        Slider(
          value: config.delayMs.clamp(50, 2000).toDouble(),
          min: 50,
          max: 2000,
          divisions: 39,
          label: '${config.delayMs}',
          onChanged: (v) => _update(appState, (c) => c..delayMs = v.round()),
        ),

        // scan length
        Text('${l10n.popupScanLength}: ${config.scanLength}'),
        Slider(
          value: config.scanLength.clamp(1, 64).toDouble(),
          min: 1,
          max: 64,
          divisions: 63,
          label: '${config.scanLength}',
          onChanged: (v) => _update(appState, (c) => c..scanLength = v.round()),
        ),

        // scan depth
        Text('${l10n.popupScanDepth}: ${config.scanDepth}'),
        Slider(
          value: config.scanDepth.clamp(0, 32).toDouble(),
          min: 0,
          max: 32,
          divisions: 32,
          label: '${config.scanDepth}',
          onChanged: (v) => _update(appState, (c) => c..scanDepth = v.round()),
        ),

        // regex gates
        TextField(
          controller: _requireRegexController,
          decoration: InputDecoration(
            labelText: l10n.popupRequireRegex,
            hintText: 'e.g. [\\u3040-\\u30ff\\u4e00-\\u9fff]',
            isDense: true,
          ),
          onChanged: (v) => _update(appState, (c) => c..requireRegex = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _excludeRegexController,
          decoration: InputDecoration(
            labelText: l10n.popupExcludeRegex,
            isDense: true,
          ),
          onChanged: (v) => _update(appState, (c) => c..excludeRegex = v),
        ),

        // toggles
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.popupDetectCompounds),
          value: config.detectCompounds,
          onChanged: (v) => _update(appState, (c) => c..detectCompounds = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.popupDetectConjugations),
          value: config.detectConjugations,
          onChanged: (v) => _update(appState, (c) => c..detectConjugations = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.popupAutoCopy),
          value: config.autoCopy,
          onChanged: (v) => _update(appState, (c) => c..autoCopy = v),
        ),

        // auto anki + deck
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.popupAutoAnki),
          value: config.autoAnki,
          onChanged: (v) => _update(appState, (c) => c..autoAnki = v),
        ),
        if (config.autoAnki)
          TextField(
            controller: _ankiDeckController,
            decoration: InputDecoration(
              labelText: l10n.popupAnkiDeck,
              isDense: true,
            ),
            onChanged: (v) => _update(appState, (c) => c..ankiDeck = v),
          ),

        // allowed screens
        Text(
          l10n.popupAllowedScreens,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Wrap(
          spacing: 8,
          runSpacing: -8,
          children: [
            for (final s in PopupScreenScope.values)
              if (s != PopupScreenScope.custom)
                FilterChip(
                  label: Text(_scopeLabel(l10n, s)),
                  selected: config.allowedScreens.contains(s),
                  onSelected: (selected) {
                    _update(appState, (c) {
                      final screens = {...c.allowedScreens};
                      if (selected) {
                        screens.add(s);
                      } else {
                        screens.remove(s);
                      }
                      // selecting "all" resets to just all
                      if (screens.contains(PopupScreenScope.all) &&
                          screens.length > 1) {
                        screens
                          ..clear()
                          ..add(PopupScreenScope.all);
                      }
                      c.allowedScreens = screens;
                      return c;
                    });
                  },
                ),
          ],
        ),

        const SizedBox(height: 16),

        // profile alternation
        Text(
          l10n.popupProfileAlternation,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          l10n.popupProfileAlternationSubtitle,
          style: TextStyle(
            fontSize: fs(context, 11, 'ui'),
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.popupProfileAlternation),
          value: config.altTrigger != null,
          onChanged: (v) => _update(appState, (c) {
            c.altTrigger = v ? PopupTrigger.click : null;
            return c;
          }),
        ),
        if (config.altTrigger != null) ...[
          Text(l10n.popupAltTrigger),
          DropdownButton<PopupTrigger>(
            isExpanded: true,
            value: config.altTrigger,
            items: [
              for (final t in PopupTrigger.values)
                DropdownMenuItem(value: t, child: Text(_triggerLabel(l10n, t))),
            ],
            onChanged: (value) {
              if (value != null) {
                _update(appState, (c) => c..altTrigger = value);
              }
            },
          ),
          TextField(
            decoration: InputDecoration(
              labelText: l10n.popupAltProfileName,
              hintText: appState.currentProfile,
              isDense: true,
            ),
            onChanged: (v) => _update(appState, (c) => c..altCondition = v),
          ),
          if (config.altTrigger == PopupTrigger.shake)
            Text(
              l10n.popupShakeArmed,
              style: TextStyle(
                fontSize: fs(context, 11, 'ui'),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],

        const SizedBox(height: 16),

        // style
        Text(
          l10n.popupStyle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        DropdownButton<PopupStyle>(
          isExpanded: true,
          value: config.style,
          items: [
            DropdownMenuItem(
              value: PopupStyle.card,
              child: Text(l10n.popupStyleCard),
            ),
            DropdownMenuItem(
              value: PopupStyle.minimal,
              child: Text(l10n.popupStyleMinimal),
            ),
            DropdownMenuItem(
              value: PopupStyle.compact,
              child: Text(l10n.popupStyleCompact),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              _update(appState, (c) => c..style = value);
            }
          },
        ),
        Text('${l10n.popupWidth}: ${config.width.round()}'),
        Slider(
          value: config.width.clamp(120, 480),
          min: 120,
          max: 480,
          divisions: 72,
          label: '${config.width.round()}',
          onChanged: (v) => _update(appState, (c) => c..width = v),
        ),
        Text('${l10n.popupMaxHeight}: ${config.maxHeight.round()}'),
        Slider(
          value: config.maxHeight.clamp(120, 600),
          min: 120,
          max: 600,
          divisions: 96,
          label: '${config.maxHeight.round()}',
          onChanged: (v) => _update(appState, (c) => c..maxHeight = v),
        ),
        Text('${l10n.popupFontScale}: ${config.fontScale.toStringAsFixed(2)}x'),
        Slider(
          value: config.fontScale.clamp(0.5, 2.0),
          min: 0.5,
          max: 2.0,
          divisions: 30,
          label: '${config.fontScale.toStringAsFixed(2)}x',
          onChanged: (v) => _update(appState, (c) => c..fontScale = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.popupShowReading),
          value: config.showReading,
          onChanged: (v) => _update(appState, (c) => c..showReading = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.popupShowSentence),
          value: config.showSentence,
          onChanged: (v) => _update(appState, (c) => c..showSentence = v),
        ),
      ],
    );
  }
}
