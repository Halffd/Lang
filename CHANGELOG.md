# Changelog

## 1.5.0 - 2026-10-26

### Added

- lang_core: shared package extracted (tokenizer, language detection, de-conjugation,
  SRS math); DictionaryService tokenizer retired in favor of it.
- Speech: on-device whisper STT (whisper_ggml), furigana transcripts, sessions,
  auto word-card generation per segment; whisper-subs streaming subtitles in reader.
- Scanner: mobile text-scanner screen (Kaku-style) plus out-of-app screen capture
  on desktop.
- AI exercises: structured-output exercise bank with semantic-QA grader.
- Shared labels: bookmarks/renaming/tags/colors across sessions, history, analyze.
- Backup/sync: export-import of all dictionaries, full backup, cloud sync.
- Analyze: space-separated languages via Wiktionary cards; per-text language config.
- Word detail: full-page route with sheet escape hatch.

### Fixed

- Analyze screen: search bar no longer overflows ("BOTTOM OVERFLOWED BY 42 PIXELS" at
  zoomed fonts). The bar is a self-sizing box above the scroll area instead of a
  pinned sliver with a pre-measured height; the multiline input keeps its
  viewport-fraction cap so huge pastes still scroll inside the field.
- Analyze screen: paging settings sync no longer calls notifyListeners during build
  (threw "setState called during build" when persisted settings differed).
- Linux build: the vendored webview plugin no longer hard-requires libwpe
  (`wpe-1.0`); it is only required for the legacy WPEBackend-FDO path. WPE WebKit
  2.48+ (WPEPlatform API) ships without a separate libwpe package.

## 1.1.0 - 2026-09-14

### Added
- **Yomichan-style global popup dictionary.** Look up words on any screen via hover, modifier keys (shift/ctrl/alt/meta), click, double click, right/middle click, mobile tap, long press, pen tap, or device shake. All 14 triggers honor an optional extra modifier and an open delay.
  - Deep scanning: when the text under the pointer fails the gates, runs at forward offsets up to the configured depth are tried.
  - Regex require/exclude gates, per-language restriction, compound and conjugation detection toggles, scan length/depth limits.
  - Screen scoping: limit popups to specific screens.
  - Profile alternation: switch to a different trigger when a named SRS profile is active.
  - Style config: card/minimal/compact variants, width, max height, font scale, reading/sentence visibility.
  - Auto-copy term to clipboard, auto-add to Anki via AnkiConnect with a configurable deck.
  - Same-term dedupe on hover, race-safe async lookups (latest lookup wins), screen-edge clamped positioning.
- Reader screen: speech-to-text tab.
- SRS: Supabase sync (pull, last-write-wins merge by `updatedAt`, append-only review union, push via upsert). Import cards from JSON, CSV, and Anki `.apkg` packages (import button restored, was orphaned).
- Anki export: working `.apkg` generation (was crashing on every export).
- AI chat: clear-history now clears the persisted history (was provider-only state).
- Yomichan dictionary service: save-word and history actions now persist (were empty stubs).
- Complete Spanish, Japanese, and Chinese translations (359 previously untranslated UI strings).
- Default screen setting wired through to the navigation shell; dictionary and writer screens in navigation.

### Fixed

- Anki deck export crashed with "expected 6 parameters, got 8"; the importer also read sqlite rows by int index against a name-keyed map.
- Hover trigger fired twice per event (double dispatch); hover re-triggered the full lookup on every mouse move over an open term.
- Popup survived screen switches and could stack stale overlays when lookups raced.
- Reader/analyze layout: content-aware information hierarchy replaced broken filter state.
- Secure storage cmake options guarded behind target check (desktop build fix).
- Media picker on the add-card sheet returned null for every pick (stub); now uses the real gallery/camera pickers.
- CLI `--provider` silently ignored non-google values; now rejects them.
- `.gitignore` entry corruption caused the generated l10n report to keep reappearing.

### Changed

- App id `com.example.lang` → `io.github.halffd.lang` across Linux, macOS, Windows, and Android (template placeholder purge).
- Dead code sweep: 48 unused/dead analyzer warnings cleared; write-only state, unused services, dead UI paths removed.
- Migrated deprecated APIs: `RadioListTile` group handling → `RadioGroup`, `ReorderableListView.onReorder` → `onReorderItem`.
- `lib/` is analyzer-clean (268 issues → 0; remaining lints are intentional `print()` in CLI tools and test scripts).
- Browser screen replaced by reader screen; test suite hermetic by default (live-network wiktionary tests opt-in via `--dart-define=WIKTIONARY_LIVE=true`).

### Verification

- `flutter analyze`: 0 errors, 0 warnings in `lib/`
- `flutter test`: 841 passed, 15 skipped (live network, opt-in)
- `flutter build linux --release`: 157 MB bundle, all plugins included, smoke-tested
