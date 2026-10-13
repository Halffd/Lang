package io.github.halffd.lang

import io.flutter.embedding.android.FlutterActivity
import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity is required by just_audio_background: routes
// media-button and notification events into the listening-mode service.
class MainActivity : AudioServiceActivity()
