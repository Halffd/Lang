import 'dart:convert';

/// Exercise-generation JSON schema for API-level structured output.
///
/// Constrains token sampling at decode time so the model cannot emit
/// invalid JSON or missing required fields — structural correctness is
/// enforced by the API, not requested in the prompt.
///
/// Supported today by Gemini (`generationConfig.responseSchema` +
/// `responseMimeType: 'application/json'`) and OpenAI-compatible
/// endpoints (`response_format: {type: 'json_schema', json_schema:
/// {...}}`).
class ExerciseSchema {
  ExerciseSchema._();

  /// Gemini `generationConfig.responseSchema` shape (OpenAPI subset).
  static Map<String, dynamic> gemini() => {
    'type': 'object',
    'properties': {
      'exercises': {'type': 'array', 'items': _exercise},
    },
    'required': ['exercises'],
  };

  /// OpenAI `response_format.json_schema.schema` shape.
  static Map<String, dynamic> openAi() => {
    'type': 'object',
    'properties': {
      'exercises': {'type': 'array', 'items': _openAiExercise},
    },
    'required': ['exercises'],
    'additionalProperties': false,
  };

  /// Strict per-exercise schema: structural fields required, content
  /// fields nullable (models may legitimately omit hint/choices for
  /// flashcards; breakdown is optional everywhere).
  static final Map<String, dynamic> _exercise = {
    'type': 'object',
    'properties': {
      'type': {
        'type': 'string',
        'enum': [
          'flashcard',
          'mc',
          'written',
          'cloze',
          'match',
          'listening',
          'spoken',
        ],
      },
      'prompt': {'type': 'string'},
      'prompt_sub': {
        'type': ['string', 'null'],
      },
      'answer': {'type': 'string'},
      'choices': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
      },
      'pairs': {
        'type': ['array', 'null'],
        'items': {
          'type': 'object',
          'properties': {
            'left': {'type': 'string'},
            'right': {'type': 'string'},
          },
          'required': ['left', 'right'],
        },
      },
      'breakdown': {
        'type': ['array', 'null'],
        'items': {
          'type': 'object',
          'properties': {
            'char': {'type': 'string'},
            'reading': {
              'type': ['string', 'null'],
            },
            'meaning': {'type': 'string'},
          },
          'required': ['char', 'meaning'],
        },
      },
    },
    'required': ['type', 'prompt', 'answer'],
  };

  /// OpenAI strict mode wants every property in `required` and null via
  /// type unions (no optional-field omission).
  static final Map<String, dynamic> _openAiExercise = {
    'type': 'object',
    'properties': {
      'type': {
        'type': 'string',
        'enum': [
          'flashcard',
          'mc',
          'written',
          'cloze',
          'match',
          'listening',
          'spoken',
        ],
      },
      'prompt': {'type': 'string'},
      'prompt_sub': {
        'type': ['string', 'null'],
      },
      'answer': {'type': 'string'},
      'choices': {
        'type': ['array', 'null'],
        'items': {'type': 'string'},
      },
      'pairs': {
        'type': ['array', 'null'],
        'items': {
          'type': 'object',
          'properties': {
            'left': {'type': 'string'},
            'right': {'type': 'string'},
          },
          'required': ['left', 'right'],
          'additionalProperties': false,
        },
      },
      'breakdown': {
        'type': ['array', 'null'],
        'items': {
          'type': 'object',
          'properties': {
            'char': {'type': 'string'},
            'reading': {
              'type': ['string', 'null'],
            },
            'meaning': {'type': 'string'},
          },
          'required': ['char', 'meaning'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['type', 'prompt', 'answer'],
    'additionalProperties': false,
  };
}

/// Extract the exercises array from a structured-output response body.
///
/// Gemini generateContent returns candidates[0].content.parts[0].text as
/// a JSON string; OpenAI chat returns choices[0].message.content. Both
/// carry the schema-constrained JSON, so decode → unwrap → hand to the
/// paranoid per-item parser.
List<dynamic> extractStructuredExercises(String responseBody) {
  final decoded = jsonDecode(responseBody);
  if (decoded is! Map) return const [];

  // OpenAI-compatible: choices[0].message.content
  if (decoded['choices'] is List) {
    final choices = decoded['choices'] as List;
    if (choices.isNotEmpty) {
      final msg = choices[0]['message'];
      if (msg is Map && msg['content'] is String) {
        return _unwrapExercises(msg['content'].toString());
      }
    }
  }

  // Gemini: candidates[0].content.parts[0].text
  final candidates = decoded['candidates'];
  if (candidates is List && candidates.isNotEmpty) {
    final content = candidates[0]['content'];
    if (content is Map) {
      final parts = content['parts'];
      if (parts is List && parts.isNotEmpty) {
        return _unwrapExercises(parts[0]['text']?.toString() ?? '');
      }
    }
  }

  // direct body already the exercises object
  return _unwrapExercises(responseBody);
}

List<dynamic> _unwrapExercises(String text) {
  var s = text.trim();
  if (s.startsWith('```')) {
    s = s.replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '');
    s = s.replaceAll(RegExp(r'```$'), '');
  }
  final decoded = jsonDecode(s);
  if (decoded is List) return decoded;
  if (decoded is Map) {
    final ex = decoded['exercises'] ?? decoded['lesson'];
    if (ex is List) return ex;
  }
  return const [];
}
