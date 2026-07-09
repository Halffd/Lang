import 'dart:convert';
import 'package:http/http.dart' as http;

class AnkiConnectException implements Exception {
  final String message;
  AnkiConnectException(this.message);
  @override
  String toString() => message;
}

class AnkiConnectService {
  String _url;

  AnkiConnectService([this._url = 'http://127.0.0.1:8765']);

  String get url => _url;
  set url(String value) => _url = value;

  Duration timeout = const Duration(seconds: 5);

  Future<dynamic> _call(String action, Map<String, dynamic> params) async {
    try {
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': action,
              'version': 6,
              'params': params,
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw AnkiConnectException('HTTP ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['error'] != null && body['error'] != '') {
        throw AnkiConnectException(body['error'] as String);
      }
      return body['result'];
    } on http.ClientException catch (e) {
      throw AnkiConnectException('Connection failed: ${e.message}');
    } on FormatException {
      throw AnkiConnectException('Invalid response from AnkiConnect');
    }
  }

  Future<bool> testConnection() async {
    try {
      await _call('version', {});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getDeckNames() async {
    final result = await _call('deckNames', {});
    return List<String>.from(result as List);
  }

  Future<Map<String, String>> getDeckNamesAndIds() async {
    final result = await _call('deckNamesAndIds', {});
    return Map<String, dynamic>.from(result as Map)
        .map((k, v) => MapEntry(k, v.toString()));
  }

  Future<List<String>> getModelNames() async {
    final result = await _call('modelNames', {});
    return List<String>.from(result as List);
  }

  Future<Map<String, String>> getModelNamesAndIds() async {
    final result = await _call('modelNamesAndIds', {});
    return Map<String, dynamic>.from(result as Map)
        .map((k, v) => MapEntry(k, v.toString()));
  }

  Future<Map<String, dynamic>> getModelFieldNames(String modelName) async {
    final result = await _call('modelFieldNames', {'modelName': modelName});
    final fields = List<String>.from(result as List);
    return {for (final f in fields) f: ''};
  }

  Future<Map<String, String>> getDeckConfig(String deckName) async {
    final result = await _call('getDeckConfig', {'deck': deckName});
    return Map<String, dynamic>.from(result as Map)
        .map((k, v) => MapEntry(k, v.toString()));
  }

  Future<int?> addNote({
    required String deckName,
    required String modelName,
    required Map<String, String> fields,
    List<String> tags = const [],
    String? audio,
    String? video,
    String? picture,
  }) async {
    final note = <String, dynamic>{
      'deckName': deckName,
      'modelName': modelName,
      'fields': fields,
      'tags': tags,
      'options': {
        'allowDuplicate': false,
        'duplicateScope': 'deck',
      },
    };

    if (audio != null) note['audio'] = audio;
    if (video != null) note['video'] = video;
    if (picture != null) note['picture'] = picture;

    final result = await _call('addNote', {'note': note});
    return result as int?;
  }

  Future<List<int?>> addNotes(List<Map<String, dynamic>> notes) async {
    final result = await _call('addNotes', {'notes': notes});
    return (result as List).map((e) => e as int?).toList();
  }

  Future<bool> canAddNote(String deckName, String modelName, Map<String, String> fields) async {
    try {
      final result = await _call('canAddNotes', {
        'notes': [
          {
            'deckName': deckName,
            'modelName': modelName,
            'fields': fields,
          }
        ]
      });
      return (result as List).isNotEmpty && result[0] == true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> guiAddCards({
    required String deckName,
    required String modelName,
    required Map<String, String> fields,
    List<String> tags = const [],
  }) async {
    return _call('guiAddCards', {
      'note': {
        'deckName': deckName,
        'modelName': modelName,
        'fields': fields,
        'options': {
          'allowDuplicate': false,
          'duplicateScope': 'deck',
        },
        'tags': tags,
      },
    });
  }

  Future<List<Map<String, dynamic>>> findCards({
    required String query,
    int limit = 100,
  }) async {
    final cardIds = await _call('findCards', {'query': query});
    if (cardIds == null || (cardIds as List).isEmpty) return [];
    final cardIdsList = List<int>.from(cardIds);
    final info = await _call('cardsInfo', {'cards': cardIdsList});
    return List<Map<String, dynamic>>.from(info as List);
  }
}