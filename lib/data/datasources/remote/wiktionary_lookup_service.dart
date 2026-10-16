import 'dart:async';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One Wiktionary definition group: a part of speech under a language
/// heading, with its plain-text definitions.
class WiktionaryDefinition {
  final String language;
  final String partOfSpeech;
  final List<String> definitions;

  const WiktionaryDefinition({
    required this.language,
    required this.partOfSpeech,
    required this.definitions,
  });
}

/// Lookup service for the Wiktionary REST definitions API
/// (`https://{lang}.wiktionary.org/api/rest_v1/page/definition/{word}`).
///
/// Serves the analyze tab's card pipeline for space-separated languages
/// (European scripts and friends), which the Yomichan dictionary does
/// not cover. The Wiktionary subdomain follows the app's wiktionary
/// language setting ('auto' = the detected text language).
class WiktionaryLookupService {
  WiktionaryLookupService({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 10);

  final http.Client _client;
  final Duration _timeout;

  /// Language codes with a Wiktionary subdomain worth querying. `ja` and
  /// `zh` are deliberately absent — those go through the Yomichan
  /// pipeline.
  static const Set<String> supportedLanguages = {
    'en',
    'ru',
    'uk',
    'el',
    'bg',
    'sr',
    'hr',
    'cs',
    'pl',
    'de',
    'fr',
    'es',
    'it',
    'pt',
    'nl',
    'sv',
    'da',
    'no',
    'fi',
    'tr',
    'he',
    'ar',
    'hi',
    'th',
    'ka',
    'hy',
    'ko',
    'vi',
    'la',
    'eo',
    'id',
    'sw',
    'hu',
    'ro',
    'ca',
    'gl',
  };

  /// Whether [languageCode] has a Wiktionary we can query (after the
  /// optional override).
  static bool isSupported(String languageCode, {String override = 'auto'}) {
    if (override != 'auto' && override.isNotEmpty) {
      return supportedLanguages.contains(override);
    }
    return supportedLanguages.contains(languageCode);
  }

  /// Subdomain to query for [detectedLanguage] under [override].
  static String subdomainFor(
    String detectedLanguage, {
    String override = 'auto',
  }) {
    if (override != 'auto' && override.isNotEmpty) return override;
    return detectedLanguage;
  }

  /// Strip the light HTML Wiktionary embeds in definition strings.
  static String stripHtml(String raw) {
    var s = raw
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&', '&')
        .replaceAll('<', '<')
        .replaceAll('>', '>')
        .replaceAll('"', '"')
        .replaceAll('&#39;', "'");
    return s.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Look up [word]; returns definition groups for every language
  /// section Wiktionary offers (the requested subdomain first). Empty
  /// list on any failure — the caller degrades gracefully.
  Future<List<WiktionaryDefinition>> lookup(
    String word,
    String detectedLanguage, {
    String override = 'auto',
  }) async {
    final w = word.trim();
    if (w.isEmpty || w.length < 2) return const [];
    final subdomain = subdomainFor(detectedLanguage, override: override);
    if (!supportedLanguages.contains(subdomain)) return const [];

    final uri = Uri.https(
      '$subdomain.wiktionary.org',
      '/api/rest_v1/page/definition/${Uri.encodeComponent(w)}',
    );
    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode == 404) return const [];
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const [];

      final out = <WiktionaryDefinition>[];
      // Requested language first, then the rest (definitions lists often
      // include translations into other languages too)
      final keys = decoded.keys.map((k) => k.toString()).toList()
        ..sort((a, b) {
          if (a == subdomain) return -1;
          if (b == subdomain) return 1;
          return a.compareTo(b);
        });

      for (final langKey in keys) {
        final groups = decoded[langKey];
        if (groups is! List) continue;
        for (final group in groups) {
          if (group is! Map) continue;
          final pos = group['partOfSpeech']?.toString() ?? '';
          final defsRaw = group['definitions'];
          if (defsRaw is! List) continue;
          final defs = <String>[];
          for (final d in defsRaw) {
            if (d is! Map) continue;
            final rawDef = d['definition']?.toString() ?? '';
            final stripped = stripHtml(rawDef);
            if (stripped.isNotEmpty) defs.add(stripped);
          }
          if (defs.isEmpty) continue;
          out.add(
            WiktionaryDefinition(
              language: langKey,
              partOfSpeech: pos,
              definitions: defs,
            ),
          );
        }
      }
      return out;
    } on TimeoutException {
      return const [];
    } catch (e) {
      debugPrint('WiktionaryLookupService.lookup($word) failed: $e');
      return const [];
    }
  }
}
