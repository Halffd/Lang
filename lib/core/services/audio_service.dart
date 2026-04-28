import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class AudioService {
  FlutterTts? _flutterTts;
  bool _useSystemTts = false;
  Process? _currentProcess;

Future<void> init() async {
    if (Platform.isLinux) {
      _useSystemTts = true;
      return;
    }
    _flutterTts = FlutterTts();
    await _flutterTts!.setLanguage("ja-JP");
    await _flutterTts!.setSpeechRate(0.5);
    await _flutterTts!.setVolume(1.0);
    await _flutterTts!.setPitch(1.0);
  }

  Future<void> play(String text, String lang) async {
    if (_useSystemTts) {
      await _speakLinux(text, lang);
      return;
    }
    if (_flutterTts == null) return;
    String locale = _getLocale(lang);
    await _flutterTts!.setLanguage(locale);
    await _flutterTts!.speak(text);
  }

  Future<void> stop() async {
    if (_useSystemTts) {
      _currentProcess?.kill();
      _currentProcess = null;
      await Process.run('pkill', ['espeak']);
      return;
    }
    if (_flutterTts == null) return;
    await _flutterTts!.stop();
  }

  Future<void> _speakLinux(String text, String lang) async {
    String voice = _getLinuxVoice(lang);
    _currentProcess?.kill();
    _currentProcess = await Process.start('espeak', ['-v', voice, text]);
  }

  String _getLinuxVoice(String lang) {
    switch (lang) {
      case 'ja': return 'ja';
      case 'zh': return 'zh';
      case 'en': return 'en';
      case 'es': return 'es';
      case 'fr': return 'fr';
      case 'de': return 'de';
      case 'ko': return 'ko';
      case 'ru': return 'ru';
      case 'it': return 'it';
      case 'pt': return 'pt';
      default: return 'en';
    }
  }

  String _getLocale(String lang) {
    switch (lang) {
      case 'ja': return 'ja-JP';
      case 'zh': return 'zh-CN';
      case 'en': return 'en-US';
      case 'es': return 'es-ES';
      case 'fr': return 'fr-FR';
      case 'de': return 'de-DE';
      case 'ko': return 'ko-KR';
      case 'ru': return 'ru-RU';
      case 'it': return 'it-IT';
      case 'pt': return 'pt-BR';
      case 'id': return 'id-ID';
      default: return 'en-US';
    }
  }
}
