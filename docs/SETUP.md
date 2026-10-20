# Setup Guide

Install, configure and run Lang per platform, including STT engines,
picture-in-picture and the mobile scanner.

## Desktop (Linux / Windows / macOS)

### Build

```sh
flutter pub get
flutter build linux --release   # or windows / macos
```

Linux needs the usual GTK + media dev packages:

```sh
sudo apt-get install -y clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev libsecret-1-dev \
  libsqlite3-dev libmpv-dev libkeybinder-3.0-dev libnotify-dev \
  libayatana-appindicator3-dev
```

### STT (speech-to-text)

The speech tab supports three engines:

| Engine | Platform | Setup |
|---|---|---|
| **Local** (whisper.cpp) | Desktop (Linux tested; Windows/macOS if `whisper-cli`/`parakeet-cli` on PATH) | Install the CLI binary; models download on first use |
| **On-device whisper (mobile)** | Android (API 24+), iOS 15.6+ | Nothing to install — whisper.cpp v1.9.1 runs in-process via FFI; the ggml model downloads on first use |
| **STT API** | All platforms | Settings → STT type → API; enter any OpenAI-compatible `/audio/transcriptions` URL + key |

Linux install of the whisper.cpp CLI (for local desktop STT):

```sh
# arch
sudo pacman -S whisper.cpp
# or build from source: https://github.com/ggml-org/whisper.cpp
```

Models download automatically on first record; the model selector
(tiny → large-v3, multilingual and English-only) picks the ggml file.

#### Mobile local STT

Local on-device STT on Android/iOS runs through the bundled
whisper.cpp FFI plugin (`whisper_ggml`). The ggml model downloads on
first use and stays cached; no API key, no server. Android needs
minSdk 24+ (already set: `minSdk = maxOf(flutter.minSdkVersion, 24)`),
iOS needs deployment target 15.6+ (set in the Podfile / Xcode).

#### Keyboard shortcuts (speech tab)

| Key | Action |
|---|---|
| Enter | Start/stop recording |
| Ctrl+A / S / D / F / G / H / J / K / L | Switch language (ja / en / id / zh / ko / pt / es / fr / it) |
| Ctrl+C | Copy transcript |
| Ctrl+X | New session (auto-saves current) |
| Ctrl+T | Toggle auto-translate |

## Picture-in-Picture

Two PiP options:

### Option 1 — Mobile native PiP (Android)

Nothing to install. The video tab's PiP button (or the system home
gesture while playing) enters Android's native picture-in-picture —
`supportsPictureInPicture` is already in the manifest, and the video
area swaps to a controls-free surface via the floating package.
Requires Android 8+.

### Option 2 — Desktop mini-player (Linux / Windows / macOS)

The desktop PiP button pops the video out into an always-on-top
mini window (desktop_multi_window + window_manager — bundled, no
extra install). The mini window owns playback; the main window
resumes from its last position when you press play there. Close the
mini window to return to normal.

**Linux note:** if the window doesn't stay on top on your window
manager, check its "always on top" rule — the app requests it via
window_manager at PiP window creation.

## In-app webview (Linux browser tab)

The Linux browser tab uses WPE WebKit through
`flutter_inappwebview_linux`. WPE is not in most distro repositories:

```sh
# arch (tested)
sudo pacman -S wpewebkit
# libwpe built from source if missing:
#   https://github.com/WebPlatformForEmbedded/libwpe (cmake, ~1 min)
sudo ln -sf /usr/local/lib/pkgconfig/wpe-1.0.pc /usr/lib/pkgconfig/

# ubuntu/debian
sudo apt-get install libwpewebkit-1.0-dev libwpe-1.0-dev
```

Without WPE the build still succeeds (the vendored plugin builds a
stub) and the browser tab falls back to the system browser.

## Scanner (text scanning)

| Source | Platform | Notes |
|---|---|---|
| Camera | Android / iOS | ML Kit on-device OCR |
| Gallery | All | Configured OCR engine |
| **Full screen / Region / Monitor** | Desktop (Linux: maim/scrot; Windows: PowerShell) | Out-of-app capture — scans text visible in any window |

Scanned text goes to the universal clipboard manager (source tag
`scanner`) and can be pushed to the popup dictionary for word lookup.

## Storage backends

Clipboard manager, history, saved words and the screenshot registry
support **SQLite** (default) or **local files** (one JSON per store).
Settings → Storage backend. Switching takes effect on next start;
data imports automatically.

## AI exercise bank

AI-generated practice exercises (Study → AI deck generator) use a
two-stage pipeline:

| Stage | What it does | Where |
|---|---|---|
| Generation | Gemini `responseSchema` structured output — invalid JSON / missing fields are impossible at decode time; the paranoid parser stays as a second gate | `lib/data/services/exercise_schema.dart` |
| Exercise bank | Local SQLite table keyed by normalized prompt hash (match exercises key on the pair set); duplicate inserts are dropped, flagged rows are never served | `lib/core/services/exercise_bank_service.dart` |
| Hybrid lessons | `getLesson` serves from the local bank, tops up from the Supabase bank, and live-generates only the gap; live results seed both banks | `lib/presentation/screens/study/ai_lesson_generator.dart` |

Buttons in the deck generator sheet:

- **Pre-generate bank (300)** — batch job, 50 exercises per request,
  stops early if the model starts repeating itself.
- **QA bank (grade pending)** — semantic-QA pass: a cheap model grades
  pending rows for answer correctness, MC distractor sanity, cloze
  uniqueness and match pairing. Bad exercises are flagged and excluded
  from lessons; grading failures leave rows pending for the next run.
