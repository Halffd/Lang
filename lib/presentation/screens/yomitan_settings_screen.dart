import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/yomitan_options.dart';
import 'package:lang/domain/entities/anki_note_types.dart';
import 'package:lang/domain/entities/anki_note_data.dart';
import 'package:lang/data/services/anki_connect_service.dart';
import 'dart:io';

/// Yomitan-style settings screen covering all export settings:
/// profiles, general, storage, scanning, popup, appearance, audio,
/// parsing, translation, anki (incl. note types), clipboard,
/// backup, accessibility, security.
class YomitanSettingsScreen extends StatelessWidget {
  const YomitanSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Yomitan Settings')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final opts = appState.yomitanOptions;
          final p = opts.activeProfile;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileSection(options: opts),
              const Divider(height: 32),
              _GeneralSection(profile: p),
              const Divider(height: 32),
              _StorageSection(profile: p),
              const Divider(height: 32),
              _ScanningSection(profile: p),
              const Divider(height: 32),
              _PopupBehaviorSection(profile: p),
              const Divider(height: 32),
              _AppearanceSection(profile: p),
              const Divider(height: 32),
              _PopupPositionSection(profile: p),
              const Divider(height: 32),
              _AudioSection(profile: p),
              const Divider(height: 32),
              _TextParsingSection(profile: p),
              const Divider(height: 32),
              _TranslationSection(profile: p),
              const Divider(height: 32),
              _AnkiSection(profile: p, options: opts),
              const Divider(height: 32),
              _ClipboardSection(profile: p),
              const Divider(height: 32),
              _AccessibilitySection(profile: p),
              const Divider(height: 32),
              _SecuritySection(profile: p),
              const Divider(height: 32),
              _BackupSection(options: opts),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  static void save(BuildContext context) {
    final appState = context.read<AppState>();
    appState.setYomitanOptions(appState.yomitanOptions);
  }
}

// ============================================================
// helpers
// ============================================================

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  ),
);

Widget _settingTile(String title, String? subtitle, Widget child) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        const SizedBox(height: 4),
        child,
      ],
    ),
  );
}

Widget _switchTile(
  String title,
  String? subtitle,
  bool value,
  void Function(bool) onChanged,
) {
  return SwitchListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: subtitle != null
        ? Text(subtitle, style: const TextStyle(fontSize: 12))
        : null,
    value: value,
    onChanged: onChanged,
  );
}

Widget _sliderTile(
  String title,
  double value,
  double min,
  double max,
  int divisions,
  String label,
  void Function(double) onChanged,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
      ),
    ],
  );
}

void _persist(BuildContext context) {
  final appState = context.read<AppState>();
  appState.setYomitanOptions(appState.yomitanOptions);
}

// ============================================================
// Profile section
// ============================================================

class _ProfileSection extends StatelessWidget {
  final YomitanOptions options;
  const _ProfileSection({required this.options});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Profile'),
        _settingTile(
          'Active profile',
          'Switch the active profile that is used for scanning',
          DropdownButtonFormField<String>(
            initialValue: options.activeProfile.name,
            items: options.profiles
                .map(
                  (p) => DropdownMenuItem(value: p.name, child: Text(p.name)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) {
                options.setActiveProfile(v);
                _persist(context);
              }
            },
          ),
        ),
        Row(
          children: [
            OutlinedButton(
              onPressed: () async {
                final name = await _promptText(context, 'Profile name');
                if (name != null && name.isNotEmpty) {
                  options.addProfile(name);
                  _persist(context);
                }
              },
              child: const Text('Add profile'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: options.profiles.length > 1
                  ? () {
                      options.removeProfile(options.activeProfile.name);
                      _persist(context);
                    }
                  : null,
              child: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }
}

Future<String?> _promptText(BuildContext context, String label) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// ============================================================
// General
// ============================================================

class _GeneralSection extends StatelessWidget {
  final YomitanProfile profile;
  const _GeneralSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final g = profile.general;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('General'),
        _switchTile('Enable Yomitan', null, g.enabled, (v) {
          g.enabled = v;
          _persist(context);
        }),
        _settingTile(
          'Language',
          'Language of the text that is being looked up',
          DropdownButtonFormField<String>(
            initialValue: g.language,
            items: const [
              DropdownMenuItem(value: 'ja', child: Text('Japanese')),
              DropdownMenuItem(value: 'zh', child: Text('Chinese')),
              DropdownMenuItem(value: 'ko', child: Text('Korean')),
              DropdownMenuItem(value: 'yue', child: Text('Cantonese')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (v) {
              if (v != null) {
                g.language = v;
                _persist(context);
              }
            },
          ),
        ),
        _switchTile(
          'Show the welcome guide on browser startup',
          null,
          g.showWelcomeGuide,
          (v) {
            g.showWelcomeGuide = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Show "Lookup in Yomitan" in right-click menu',
          null,
          g.showLookupInContextMenu,
          (v) {
            g.showLookupInContextMenu = v;
            _persist(context);
          },
        ),
        _settingTile(
          'Maximum number of results',
          'Adjust the maximum number of results shown for lookups',
          DropdownButtonFormField<int>(
            initialValue: g.maximumNumberOfResults,
            items: [8, 16, 32, 64, 128]
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                g.maximumNumberOfResults = v;
                _persist(context);
              }
            },
          ),
        ),
        _switchTile(
          'Enable Yomitan API',
          'Enable support for sending local web requests to fetch data from Yomitan',
          g.enableApi,
          (v) {
            g.enableApi = v;
            _persist(context);
          },
        ),
      ],
    );
  }
}

// ============================================================
// Storage / frequency
// ============================================================

class _StorageSection extends StatelessWidget {
  final YomitanProfile profile;
  const _StorageSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final s = profile.storage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Storage'),
        _settingTile(
          'Frequency sorting dictionary',
          'Sort results using a frequency dictionary',
          TextField(
            decoration: InputDecoration(
              hintText: 'Dictionary name',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            controller: TextEditingController(
              text: s.frequencySortingDictionary,
            ),
            onChanged: (v) {
              s.frequencySortingDictionary = v;
              _persist(context);
            },
          ),
        ),
        _settingTile(
          'Frequency sorting mode',
          null,
          DropdownButtonFormField<FrequencySortingMode>(
            initialValue: s.frequencySortingMode,
            items: FrequencySortingMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                s.frequencySortingMode = v;
                _persist(context);
              }
            },
          ),
        ),
        _switchTile(
          'Persistent storage',
          'Enable to help prevent the browser from unexpectedly clearing the database',
          s.persistentStorage,
          (v) {
            s.persistentStorage = v;
            _persist(context);
          },
        ),
      ],
    );
  }
}

// ============================================================
// Scanning
// ============================================================

class _ScanningSection extends StatelessWidget {
  final YomitanProfile profile;
  const _ScanningSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final sc = profile.scanning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Scanning'),
        _settingTile(
          'Scan modifier key',
          'Hold a key while moving the cursor to scan text',
          DropdownButtonFormField<ScanModifierKey>(
            initialValue: sc.scanModifierKey,
            items: ScanModifierKey.values
                .map((k) => DropdownMenuItem(value: k, child: Text(k.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                sc.scanModifierKey = v;
                _persist(context);
              }
            },
          ),
        ),
        _switchTile(
          'Scan using middle mouse button',
          'Hold the middle mouse button while moving the cursor to scan text',
          sc.scanUsingMiddleMouseButton,
          (v) {
            sc.scanUsingMiddleMouseButton = v;
            _persist(context);
          },
        ),
        _settingTile(
          'Scan delay (in milliseconds)',
          'Change the delay before scanning occurs when no modifier key is required',
          Slider(
            value: sc.scanDelay.clamp(0, 1000).toDouble(),
            min: 0,
            max: 1000,
            divisions: 20,
            label: '${sc.scanDelay}ms',
            onChanged: (v) {
              sc.scanDelay = v.round();
              _persist(context);
            },
          ),
        ),
        _switchTile(
          'Scan without mouse move',
          'Allow scanning words under the pointer without the pointer being in motion',
          sc.scanWithoutMouseMove,
          (v) {
            sc.scanWithoutMouseMove = v;
            _persist(context);
          },
        ),
        _switchTile('Select matched text', null, sc.selectMatchedText, (v) {
          sc.selectMatchedText = v;
          _persist(context);
        }),
        _switchTile(
          'Search text with non-Japanese, Chinese, or Korean characters',
          'Only applies when language is set to Japanese, Chinese, Cantonese, or Korean',
          sc.searchNonJapaneseText,
          (v) {
            sc.searchNonJapaneseText = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Layout-aware scanning',
          'Use webpage styling information to determine where line breaks are likely to be',
          sc.layoutAwareScanning,
          (v) {
            sc.layoutAwareScanning = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Deep content scanning',
          'Enable scanning text that is covered by other layers',
          sc.deepContentScanning,
          (v) {
            sc.deepContentScanning = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Normalize CSS zoom',
          'Correct the pointer location on webpages where CSS zoom is used',
          sc.normalizeCssZoom,
          (v) {
            sc.normalizeCssZoom = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Wildcard scanning',
          'Enable suffix wildcard when looking up scanned webpage text',
          sc.wildcardScanning,
          (v) {
            sc.wildcardScanning = v;
            _persist(context);
          },
        ),
        _settingTile(
          'Text scan length',
          'Change how many characters are read when scanning for terms.\nSetting this value too high (100+) may impact performance',
          Slider(
            value: sc.textScanLength.clamp(16, 1000).toDouble(),
            min: 16,
            max: 1000,
            divisions: 24,
            label: '${sc.textScanLength}',
            onChanged: (v) {
              sc.textScanLength = v.round();
              _persist(context);
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Popup behavior
// ============================================================

class _PopupBehaviorSection extends StatelessWidget {
  final YomitanProfile profile;
  const _PopupBehaviorSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final pb = profile.popupBehavior;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Popup Behavior'),
        _switchTile(
          'Allow scanning search page content',
          'Text on the search page can be scanned for definitions, which will open a popup',
          pb.allowScanningSearchPage,
          (v) {
            pb.allowScanningSearchPage = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Allow scanning popup content',
          'Text inside of popups can be scanned for definitions, which will open a new popup',
          pb.allowScanningPopupContent,
          (v) {
            pb.allowScanningPopupContent = v;
            _persist(context);
          },
        ),
        _settingTile(
          'Maximum number of child popups',
          'Change the limit on the number of popups that may be generated',
          Slider(
            value: pb.maximumNumberOfChildPopups.toDouble(),
            min: 0,
            max: 8,
            divisions: 8,
            label: '${pb.maximumNumberOfChildPopups}',
            onChanged: (v) {
              pb.maximumNumberOfChildPopups = v.round();
              _persist(context);
            },
          ),
        ),
        _switchTile(
          'Allow scanning popup source terms',
          null,
          pb.allowScanningPopupSourceTerms,
          (v) {
            pb.allowScanningPopupSourceTerms = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Auto-hide search popup',
          'When an existing popup is present, upon scanning again, hide the existing popup even if no definitions are found',
          pb.autoHideSearchPopup,
          (v) {
            pb.autoHideSearchPopup = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Hide popup on cursor exit',
          'When the cursor exits the popup, the popup will be hidden',
          pb.hidePopupOnCursorExit,
          (v) {
            pb.hidePopupOnCursorExit = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Reduced motion scrolling',
          'Scrolls by a configurable height (similar to pagination), reducing animations. Useful on e-readers and e-ink screens',
          pb.reducedMotionScrolling,
          (v) {
            pb.reducedMotionScrolling = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Search terms when clicking text from the results list',
          null,
          pb.searchOnClickFromResultsList,
          (v) {
            pb.searchOnClickFromResultsList = v;
            _persist(context);
          },
        ),
      ],
    );
  }
}

// ============================================================
// Appearance
// ============================================================

class _AppearanceSection extends StatelessWidget {
  final YomitanProfile profile;
  const _AppearanceSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final a = profile.appearance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Appearance'),
        _settingTile(
          'Theme',
          'Adjust the style of Yomitan',
          DropdownButtonFormField<ThemePreset>(
            initialValue: a.theme,
            items: ThemePreset.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                a.theme = v;
                _persist(context);
              }
            },
          ),
        ),
        _settingTile(
          'Font size',
          'Change the font size used in popups, in pixels',
          _sliderTile(
            'Font size',
            a.fontSize,
            10,
            32,
            22,
            '${a.fontSize.round()}px',
            (v) {
              a.fontSize = v;
              _persist(context);
            },
          ),
        ),
        _settingTile(
          'Line height',
          'Change the space between lines of text in popups. This will usually be a decimal number between 1 and 2',
          _sliderTile(
            'Line height',
            a.lineHeight,
            1.0,
            2.0,
            10,
            a.lineHeight.toStringAsFixed(1),
            (v) {
              a.lineHeight = v;
              _persist(context);
            },
          ),
        ),
        _switchTile(
          'Compact glossaries',
          'Display term glossaries using a more compact layout',
          a.compactGlossaries,
          (v) {
            a.compactGlossaries = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Compact tags',
          'Show fewer repeated tags for term glossaries',
          a.compactTags,
          (v) {
            a.compactTags = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Show tags for expressions and their readings',
          'These tags can be scanned if the options for popup content scanning are enabled',
          a.showTagsForExpressionsAndReadings,
          (v) {
            a.showTagsForExpressionsAndReadings = v;
            _persist(context);
          },
        ),
        _settingTile(
          'Reading mode',
          'Change what type of furigana is displayed for parsed text. Japanese only',
          DropdownButtonFormField<ReadingDisplayMode>(
            initialValue: a.readingDisplayMode,
            items: ReadingDisplayMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                a.readingDisplayMode = v;
                _persist(context);
              }
            },
          ),
        ),
        _settingTile(
          'Selection indicator style',
          'Change how the selected definition entry is visually indicated',
          DropdownButtonFormField<SelectionIndicatorStyle>(
            initialValue: a.selectionIndicatorStyle,
            items: SelectionIndicatorStyle.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                a.selectionIndicatorStyle = v;
                _persist(context);
              }
            },
          ),
        ),
        _switchTile(
          'Pitch accent downstep notation',
          null,
          a.pitchAccentDownstep,
          (v) {
            a.pitchAccentDownstep = v;
            _persist(context);
          },
        ),
        _switchTile('Pitch accent graph', null, a.pitchAccentGraph, (v) {
          a.pitchAccentGraph = v;
          _persist(context);
        }),
        _switchTile('Pitch accent position', null, a.pitchAccentPosition, (v) {
          a.pitchAccentPosition = v;
          _persist(context);
        }),
      ],
    );
  }
}

// ============================================================
// Popup position & size
// ============================================================

class _PopupPositionSection extends StatelessWidget {
  final YomitanProfile profile;
  const _PopupPositionSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final pp = profile.popupPosition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Popup Position & Size'),
        _settingTile(
          'Display mode',
          'Change the layout of the popup',
          DropdownButtonFormField<PopupDisplayMode>(
            initialValue: pp.displayMode,
            items: PopupDisplayMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                pp.displayMode = v;
                _persist(context);
              }
            },
          ),
        ),
        _settingTile(
          'Scale',
          'Control the scaling factor of the popup',
          _sliderTile(
            'Scale',
            pp.scale,
            0.5,
            2.0,
            15,
            '${pp.scale.toStringAsFixed(2)}x',
            (v) {
              pp.scale = v;
              _persist(context);
            },
          ),
        ),
        _switchTile('Auto-scale', null, pp.autoScale, (v) {
          pp.autoScale = v;
          _persist(context);
        }),
        _settingTile(
          'Size',
          'Control the size of the popup, in pixels',
          Row(
            children: [
              Expanded(
                child: _numberField('Width', pp.width, (v) => pp.width = v),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField('Height', pp.height, (v) => pp.height = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _numberField(
  String label,
  double value,
  void Function(double) onChanged,
) {
  return TextField(
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    keyboardType: TextInputType.number,
    controller: TextEditingController(text: value.toStringAsFixed(0)),
    onChanged: (v) {
      final n = double.tryParse(v);
      if (n != null) onChanged(n);
    },
  );
}

// ============================================================
// Audio
// ============================================================

class _AudioSection extends StatelessWidget {
  final YomitanProfile profile;
  const _AudioSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final au = profile.audio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Audio'),
        _switchTile(
          'Enable audio playback for terms',
          'Show a clickable speaker icon next to search results\nThis option may send term, reading, and/or language outside of Yomitan to fetch audio',
          au.enabled,
          (v) {
            au.enabled = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Auto-play search result audio',
          'The audio for the first result will be played automatically',
          au.autoPlaySearchResultAudio,
          (v) {
            au.autoPlaySearchResultAudio = v;
            _persist(context);
          },
        ),
        _settingTile(
          'Audio volume',
          'Adjust the volume audio is played at, in percent',
          _sliderTile(
            'Volume',
            au.volume * 100,
            0,
            100,
            20,
            '${(au.volume * 100).round()}%',
            (v) {
              au.volume = v / 100;
              _persist(context);
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Text parsing
// ============================================================

class _TextParsingSection extends StatelessWidget {
  final YomitanProfile profile;
  const _TextParsingSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tp = profile.textParsing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Text Parsing'),
        _switchTile(
          "Parse sentences using Yomitan's internal parser",
          "Sentence words are parsed using Yomitan's dictionaries",
          tp.parseInternalParser,
          (v) {
            tp.parseInternalParser = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Parse sentences using MeCab',
          'Sentence words are parsed using a third-party program. Japanese only',
          tp.parseMecab,
          (v) {
            tp.parseMecab = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Show space between parsed words',
          null,
          tp.showSpaceBetweenParsedWords,
          (v) {
            tp.showSpaceBetweenParsedWords = v;
            _persist(context);
          },
        ),
        _settingTile(
          'Sentence scanning extent',
          'Adjust how many characters are bidirectionally scanned to form a sentence',
          Slider(
            value: tp.sentenceScanningExtent.clamp(20, 800).toDouble(),
            min: 20,
            max: 800,
            divisions: 39,
            label: '${tp.sentenceScanningExtent}',
            onChanged: (v) {
              tp.sentenceScanningExtent = v.round();
              _persist(context);
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Translation
// ============================================================

class _TranslationSection extends StatelessWidget {
  final YomitanProfile profile;
  const _TranslationSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tr = profile.translation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Translation'),
        _sectionTitle('Dictionary search resolution'),
        _settingTile(
          'Search resolution',
          '"A dog" → "A dog", "A do", "A d", "A"  (full)\n"A dog" → "A dog", "A"  (prefix-only)',
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Full')),
              ButtonSegment(value: false, label: Text('Prefix only')),
            ],
            selected: {tr.searchResolutionFull},
            onSelectionChanged: (s) {
              tr.searchResolutionFull = s.first;
              _persist(context);
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Anki (biggest section)
// ============================================================

class _AnkiSection extends StatelessWidget {
  final YomitanProfile profile;
  final YomitanOptions options;
  const _AnkiSection({required this.profile, required this.options});

  @override
  Widget build(BuildContext context) {
    final a = profile.anki;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Anki'),
        _switchTile(
          'Enable Anki integration',
          'Connection status: ${a.enabled ? "enabled" : "disabled"}',
          a.enabled,
          (v) {
            a.enabled = v;
            _persist(context);
          },
        ),
        _settingTile(
          'AnkiConnect server address',
          'Change the URL of the AnkiConnect server',
          TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            controller: TextEditingController(text: a.serverAddress),
            onChanged: (v) {
              a.serverAddress = v;
              _persist(context);
            },
          ),
        ),
        Row(
          children: [
            OutlinedButton(
              onPressed: () async {
                try {
                  final svc = AnkiConnectService(a.serverAddress);
                  final ok = await svc.testConnection();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Connected' : 'Connection failed'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Test connection'),
            ),
          ],
        ),
        _settingTile(
          'Card tags',
          'List of space or comma separated tags to add to the card',
          TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            controller: TextEditingController(text: a.tags),
            onChanged: (v) {
              a.tags = v;
              _persist(context);
            },
          ),
        ),
        _settingTile(
          'API key',
          'Pass a secret value to AnkiConnect API calls',
          TextField(
            obscureText: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            controller: TextEditingController(text: a.apiKey),
            onChanged: (v) {
              a.apiKey = v;
              _persist(context);
            },
          ),
        ),
        _switchTile(
          'Check for card duplicates',
          'Check for duplicates across all models',
          a.checkForCardDuplicates,
          (v) {
            a.checkForCardDuplicates = v;
            _persist(context);
          },
        ),
        _settingTile(
          'Duplicate card scope',
          'When a duplicate is detected',
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DuplicateScope>(
                  initialValue: a.duplicateScope,
                  items: DuplicateScope.values
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      a.duplicateScope = v;
                      _persist(context);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<DuplicateAction>(
                  initialValue: a.duplicateAction,
                  items: DuplicateAction.values
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      a.duplicateAction = v;
                      _persist(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        _settingTile(
          'Screenshot format',
          'Adjust the format and quality of screenshots created for cards',
          DropdownButtonFormField<ScreenshotFormat>(
            initialValue: a.screenshotFormat,
            items: ScreenshotFormat.values
                .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                a.screenshotFormat = v;
                _persist(context);
              }
            },
          ),
        ),
        _switchTile(
          'Suspend new cards',
          'New cards will be suspended when a note is added',
          a.suspendNewCards,
          (v) {
            a.suspendNewCards = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Force Anki sync on adding card',
          'May cause issues when using in conjuction with Ankiconnect Android, and/or slow or metered connections',
          a.forceSyncOnAddingCard,
          (v) {
            a.forceSyncOnAddingCard = v;
            _persist(context);
          },
        ),
        const SizedBox(height: 8),
        // Note types editor
        const Text(
          'Anki Cards - Note Types',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const Text(
          'Configure deck, model and field markers per note type',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        ...AnkiNoteType.values.map((t) => _noteTypeTile(context, t)),
        const Divider(height: 32),
        // Custom marker templates
        const Text(
          'Customize handlebars templates',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const Text(
          'Override how each marker renders using Yomitan-compatible '
          'handlebars templates. Context: expression, reading, glossary, '
          'cloze.sentence, definition.definitions (dictionary, glossary), '
          'frequencies (dictionary, frequency), hasMedia/getMedia helpers.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        _MarkerTemplatesEditor(),
      ],
    );
  }

  Widget _noteTypeTile(BuildContext context, AnkiNoteType type) {
    final appState = context.read<AppState>();
    final noteTypes = appState.ankiNoteTypes;
    final config = noteTypes.byType(type);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Text(
        type.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      title: Text(
        '${config.deck} / ${config.model}',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '${config.fields.length} fields',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoteTypeEditorScreen(type: type),
        ),
      ),
    );
  }
}

// ============================================================
// Note type editor
// ============================================================

class NoteTypeEditorScreen extends StatelessWidget {
  final AnkiNoteType type;
  const NoteTypeEditorScreen({super.key, required this.type});

  static const Map<AnkiNoteType, String> typeLabels = {
    AnkiNoteType.expression: 'Expression (terms)',
    AnkiNoteType.reading: 'Reading',
    AnkiNoteType.kanji: 'Kanji',
    AnkiNoteType.name: 'Name',
  };

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final noteTypes = appState.ankiNoteTypes;

    return Scaffold(
      appBar: AppBar(
        title: Text('Note Type: ${typeLabels[type]}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to default fields',
            onPressed: () {
              final defaults = AnkiNoteTypes.defaults().byType(type);
              final idx = noteTypes.types.indexWhere((t) => t.type == type);
              if (idx >= 0) noteTypes.types[idx] = defaults.copy();
              appState.setAnkiNoteTypes(noteTypes);
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final cfg = appState.ankiNoteTypes.byType(type);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _settingTile(
                'Deck',
                'Anki deck for this note type',
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  controller: TextEditingController(text: cfg.deck),
                  onChanged: (v) {
                    cfg.deck = v;
                    appState.setAnkiNoteTypes(noteTypes);
                  },
                ),
              ),
              _settingTile(
                'Model',
                'Anki note model (Basic, jp-mining-note, ...)',
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  controller: TextEditingController(text: cfg.model),
                  onChanged: (v) {
                    cfg.model = v;
                    appState.setAnkiNoteTypes(noteTypes);
                  },
                ),
              ),
              _switchTile('Enabled', null, cfg.enabled, (v) {
                cfg.enabled = v;
                appState.setAnkiNoteTypes(noteTypes);
              }),
              const Divider(height: 32),
              const Text(
                'Fields',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Each field maps an Anki field name to a marker template.\n'
                'Example: Word -> {expression}, Glossary -> {glossary-first}',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...cfg.fields.asMap().entries.map((entry) {
                final i = entry.key;
                final f = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            labelText: 'Field',
                          ),
                          controller: TextEditingController(text: f.name),
                          onChanged: (v) {
                            f.name = v;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            labelText: 'Markers',
                          ),
                          controller: TextEditingController(text: f.value),
                          onChanged: (v) {
                            f.value = v;
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () {
                          cfg.fields.removeAt(i);
                          appState.setAnkiNoteTypes(noteTypes);
                        },
                      ),
                    ],
                  ),
                );
              }),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add field'),
                onPressed: () {
                  cfg.fields.add(AnkiFieldConfig('', ''));
                  appState.setAnkiNoteTypes(noteTypes);
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  appState.setAnkiNoteTypes(noteTypes);
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// Clipboard
// ============================================================

class _ClipboardSection extends StatelessWidget {
  final YomitanProfile profile;
  const _ClipboardSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final cb = profile.clipboard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Clipboard'),
        _switchTile(
          'Enable background clipboard text monitoring',
          'Open the search page in a new window when text is copied to the clipboard',
          cb.enableBackgroundMonitoring,
          (v) {
            cb.enableBackgroundMonitoring = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Enable search page clipboard text monitoring',
          'The query on the search page will be automatically updated with text in the clipboard',
          cb.enableSearchPageMonitoring,
          (v) {
            cb.enableSearchPageMonitoring = v;
            _persist(context);
          },
        ),
        _settingTile(
          'Maximum clipboard text search length',
          'Limit the number of characters used when searching clipboard text',
          Slider(
            value: cb.maximumSearchTextLength.clamp(16, 100000).toDouble(),
            min: 16,
            max: 10000,
            divisions: 50,
            label: '${cb.maximumSearchTextLength}',
            onChanged: (v) {
              cb.maximumSearchTextLength = v.round();
              _persist(context);
            },
          ),
        ),
        _settingTile(
          'Clipboard text search mode',
          'Change how the search page reacts to new text in the clipboard',
          DropdownButtonFormField<ClipboardSearchMode>(
            initialValue: cb.searchMode,
            items: ClipboardSearchMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                cb.searchMode = v;
                _persist(context);
              }
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Accessibility / Security
// ============================================================

class _AccessibilitySection extends StatelessWidget {
  final YomitanProfile profile;
  const _AccessibilitySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final ac = profile.accessibility;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Accessibility'),
        _switchTile(
          'Enable Google Docs compatibility mode',
          null,
          ac.googleDocsCompatibilityMode,
          (v) {
            ac.googleDocsCompatibilityMode = v;
            _persist(context);
          },
        ),
      ],
    );
  }
}

class _SecuritySection extends StatelessWidget {
  final YomitanProfile profile;
  const _SecuritySection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final sec = profile.security;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Security'),
        _switchTile(
          'Use a secure container around popups',
          null,
          sec.useSecureContainerAroundPopups,
          (v) {
            sec.useSecureContainerAroundPopups = v;
            _persist(context);
          },
        ),
        _switchTile(
          'Use secure popup frame URL',
          null,
          sec.useSecurePopupFrameUrl,
          (v) {
            sec.useSecurePopupFrameUrl = v;
            _persist(context);
          },
        ),
      ],
    );
  }
}

// ============================================================
// Backup
// ============================================================

class _BackupSection extends StatelessWidget {
  final YomitanOptions options;
  const _BackupSection({required this.options});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Backup'),
        const Text(
          'Settings files contain only settings, not dictionaries. '
          'Dictionaries must be imported separately.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.file_download),
              label: const Text('Export settings'),
              onPressed: () async {
                final dir = Directory.systemTemp;
                final file = File(
                  '${dir.path}/yomitan-settings-${DateTime.now().millisecondsSinceEpoch}.json',
                );
                await file.writeAsString(options.serialize());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Settings exported to ${file.path}'),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.file_upload),
              label: const Text('Import settings'),
              onPressed: () async {
                final text = await _promptText(
                  context,
                  'Paste settings JSON (or path)',
                );
                if (text == null || text.isEmpty) return;
                try {
                  // if it's a file path read it, else parse directly
                  String raw = text;
                  final f = File(text);
                  if (await f.exists()) {
                    raw = await f.readAsString();
                  }
                  final imported = YomitanOptions.deserialize(raw);
                  if (imported.profiles.isNotEmpty) {
                    // replace current options content
                    options.profiles
                      ..clear()
                      ..addAll(imported.profiles);
                    options.activeProfileIndex = imported.activeProfileIndex;
                    _persist(context);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings imported')),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Import failed: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Marker templates editor (handlebars overrides per marker)
// ============================================================

class _MarkerTemplatesEditor extends StatefulWidget {
  @override
  State<_MarkerTemplatesEditor> createState() =>
      _MarkerTemplatesEditorState();
}

class _MarkerTemplatesEditorState extends State<_MarkerTemplatesEditor> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final noteTypes = appState.ankiNoteTypes;
    final markers = AnkiMarkerRenderer.allMarkers;

    return Column(
      children: [
        for (final marker in markers)
          if (_isCommonMarker(marker)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ExpansionTile(
                dense: true,
                tilePadding: EdgeInsets.zero,
                title: Text('{$marker}',
                    style: const TextStyle(
                        fontSize: 13, fontFamily: 'monospace')),
                subtitle: noteTypes.markerTemplates[marker]?.isNotEmpty ==
                        true
                    ? const Text('custom template',
                        style: TextStyle(fontSize: 11))
                    : null,
                children: [
                  TextField(
                    controller: _controllers.putIfAbsent(
                        marker,
                        () => TextEditingController(
                            text: noteTypes.markerTemplates[marker] ?? '')),
                    maxLines: 6,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'Leave empty for the built-in renderer',
                    ),
                    onChanged: (v) {
                      if (v.trim().isEmpty) {
                        noteTypes.markerTemplates.remove(marker);
                      } else {
                        noteTypes.markerTemplates[marker] = v;
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          _controllers[marker]?.clear();
                          noteTypes.markerTemplates.remove(marker);
                          appState.setAnkiNoteTypes(noteTypes);
                        },
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: () =>
                            appState.setAnkiNoteTypes(noteTypes),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }

  static bool _isCommonMarker(String m) => const [
        'expression', 'reading', 'glossary', 'glossary-first',
        'glossary-brief', 'furigana', 'furigana-plain', 'sentence',
        'sentence-furigana-plain', 'cloze-body', 'frequencies',
        'frequency-harmonic-rank', 'pitch-accents', 'tags',
        'clipboard-text', 'screenshot', 'audio',
      ].contains(m);
}
