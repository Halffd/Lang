# Changelog

## Unreleased

### Added

- **Live OCR.** A continuous screen-capture loop that reads the screen, shows
  the recognized text in a draggable floating overlay and translates it into
  the app learning language. Enable it under Settings → Live OCR.
  - Reads the region you last selected with the region capture, or the whole
    screen when "Read the whole screen" is on.
  - Uses the OCR engine and OCR language you already configured, and the
    translation provider you already configured.
  - A stability gate waits for the same text to be read N times (2 by default)
    before translating it, so a single misread frame does not flash a wrong
    translation and the translation API is not called on every frame.
  - Translation runs beside the capture loop, so a slow translation never
    stalls capturing, and a result for text that has since changed is
    discarded rather than shown.
  - Captures for the live loop are transient: they are not added to the
    screenshot album or the screenshot registry.
  - Capture and OCR failures are shown in the overlay, so a loop that
    cannot read the screen says so instead of silently doing nothing.
  - The settings section says so when the machine has no screen capture
    (a phone, or a desktop without the capture tools installed) and the
    controls stay inert instead of the switch doing nothing.
  - The whole section is translated: the settings, the overlay's error
    prefix and the loop's own failure messages follow the app language.

- **Screenshot manager.** A third tab in the OCR / Screenshot screen with the
  full action set for the stored screenshots.
  - Search by name or recognized text, filter by visible / hidden / with text /
    without text, and sort by newest, oldest or name.
  - Per-item actions: copy the path, copy the path relative to the screenshot
    folder, properties (name, kind, capture time, path, file size, recognized
    text), rename, edit the recognized text, crop, hide / unhide and delete.
  - Cropping is a drag over the image preview, not a form of pixel numbers; the
    selection is clamped to the image and the result replaces the stored image.
  - The stored image keeps its own name, so a renamed screenshot still shows the
    name after a restart.

- **Configurable screenshot folder.** Settings → Live OCR now shows where the
  screenshots are written, with a button to pick another folder and one to go
  back to the default. The folder is stored with the other settings and applies
  to the next capture.

- **Global hotkeys.** The shortcuts are listed under Settings → Global hotkeys,
  so they can be found without knowing them:
  - `Ctrl+Shift+V` opens the clipboard manager. The window is brought forward
    first, so the popup still appears when the app sits in the tray.
  - `Ctrl+Shift+O` runs OCR on the newest clipboard image (or the newest
    screenshot when the clipboard holds no image) and puts the text on the
    clipboard.
  - The screenshot shortcuts (full screen, monitor, window, region, repeat the
    last region, toggle automatic captures) are listed next to them.

- **Clipboard manager.** The manager gained the actions it was missing:
  - `Ctrl+1` … `Ctrl+0` copy the first to the tenth entry of the list.
  - "Append text" adds to the newest text entry instead of piling up entries.
  - A sort menu orders the entries by newest, oldest or text.
  - The entry list renders image entries from storage, so an image stored as a
    database blob shows its thumbnail instead of a broken-image icon.

### Fixed

- OCR and screenshots are no longer duplicated inside the search and reader
  screens. They live in their own bottom-bar screen, and the reader keeps
  documents, browser, clipboard and WhisperSubs.
- Copying an image to the clipboard no longer reports success when the tool
  hung. A clipboard tool that neither exits nor forks is killed, and the copy is
  reported as failed so the next tool (or the next attempt) can take over.
- Copying an image to the clipboard actually copies the image now:
  - The Wayland tool is told the data is `image/png`. Without the type it
    infers `text/plain` from the piped bytes, so the clipboard held the PNG as
    text and no application pasted it as an image.
  - An empty `WAYLAND_DISPLAY` or `DISPLAY` is no longer taken for a display.
    `wl-copy` exits 0 without copying anything when it cannot reach a Wayland
    server, so it must never be the only candidate.
  - The tools are started with their input closed. A tool waiting on an open
    pipe never reaches the clipboard and never exits.
  - The tools' output pipes are drained. They fork into the background to own
    the selection and keep the inherited pipes open, so waiting for them to
    close never finishes.
  - Verified against a live X server and a live Wayland session: the pasted
    bytes match the copied bytes exactly, and the Wayland clipboard offers
    `image/png`.
- The global hotkeys fired twice per keypress: the handler called the callback
  and then called the stored callback a second time.
- Copying a screenshot image to the clipboard failed for screenshots stored in
  the database, because the code handed the storage reference to the clipboard
  writer instead of a file.
- The screenshot manager's per-item actions no longer break the widget tree.
  Closing the item menu marked its button dirty, and an action that removed the
  row from the list deactivated that still-dirty button, which the framework
  refuses to do. The action now runs after the button's own rebuild.
- The clipboard manager's status bar and the settings' hotkey list no longer
  overflow their row on a narrow window; the text shrinks instead.
- The screenshot manager's toolbar no longer overflows when the manager is
  hosted in a short slot, such as the Manager tab of the OCR / Screenshot
  screen. The toolbar now shrinks to the space it is given.
- The dialogs in the clipboard manager and the screenshot manager no longer use
  a text controller after disposing it. A dialog route animates out after its
  future completes, so disposing the controller at that point left the
  still-mounted field using a dead controller. The field now owns its
  controller and disposes it when it leaves the tree.

- Navigation bar labels no longer fail to resolve: the label lookup passed a
  nullable localization object to a non-null parameter.
- Bottom navigation: the bar and the screens are driven by one shared list
  (`navDestinations`), so the destination order and the screen order can no
  longer drift apart. The desktop IPC shortcuts navigate by route name instead
  of hard-coded indices that pointed at the wrong screens.
- Right-click context menu: text fields no longer show a single "Paste" button.
  The menu now always lists Cut / Copy / Paste / Select all (disabled where they
  do not apply) plus a "Look up" action for the selection, and right-clicking
  outside a text field opens a menu with the word under the cursor (look up,
  copy the word, copy the sentence). Every text field in the app uses the new
  menu, including the plain `TextField`s on the settings, reader and SRS
  screens.
- Word cards: the word type is no longer printed twice. The part-of-speech
  marker ("noun (common) …") is stripped from the definition line, which already
  shows the type as a coloured chip.
- Mobile pinch zoom: the two-finger pinch no longer loses to the swipe handler.
  Mode arbitration now lets the pinch win ties (a spread also drags the midpoint,
  so an equal-size midpoint move used to steal every pinch), and the pinch
  baseline is re-taken when a third finger joins or leaves so the font size does
  not jump mid-gesture.
- Popup dictionary no longer fires over the app's own labels. App-bar titles,
  the bottom navigation bar, and the analyze screen's title, language selector,
  search bar and filter bar are marked as UI chrome and skipped by the scan.
- Bottom bar entries show their label on hover (tooltip), so the destination is
  readable when the zoomed text hides the label.
- Japanese tokenizer keeps kana compounds whole: a kana surface that only exists
  under its kanji form (かいどく → 解読) is now matched by reading, so it is no
  longer split into かい + どく. The dictionary match carries the covered source
  length so the surface is sliced correctly.
- Word cards: multiple senses no longer merge into one run-on line. Gloss lists
  are separated with `; ` when flattened to plain text, and the card shows the
  first two senses joined the same way.
- The video tab's subtitles honour the reading style. The subtitle over the
  picture and the draggable caption bubble now draw the furigana / pinyin the
  same way the transcript and the other readers do, instead of staying plain
  when the reading style is on.
- The popup dictionary can open on the video screen. The video route is a
  screen scope of its own, so the dictionary's scope filter no longer has to
  be widened to all screens to let it work there.
- The popup dictionary finds the word under the pointer in a reading
  annotation. A reading annotation draws the kana above the kanji with an
  inline widget, so the kanji ends up inside that widget rather than in the
  paragraph's text, and the paragraph's plain text held only a placeholder.
  The lookup ran on the placeholder and found nothing; the annotated text is
  now read from the inline widget under the pointer. Pointing at the reading
  itself finds the word too, and a line that mixes annotated and plain words
  is looked up on the plain part as well.

### Changed

- Analyze screen: the search bar can be collapsed with the arrow button and
  hides itself while scrolling down through the results (it returns on scroll
  up, at the top, or through the slim handle that stays visible).
- Analyze screen: the column count is set with a slider and a dropdown and now
  goes up to 12 columns; a card-height control (auto or a fixed minimum) keeps
  the cards in a row aligned.
- Analyze screen: zoom shortcuts — `+`/`-` resize the definition text,
  `Shift`+`+`/`-` change the column count, `Ctrl`+`+`/`-` resize every text.
- Word cards: the tag chips (part of speech, frequency, secondary reading) moved
  from the middle of the card to its end and are now color-coded by word type.

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
