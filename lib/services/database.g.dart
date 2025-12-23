// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DriftDictionaryEntriesTable extends DriftDictionaryEntries
    with TableInfo<$DriftDictionaryEntriesTable, DriftDictionaryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftDictionaryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _termMeta = const VerificationMeta('term');
  @override
  late final GeneratedColumn<String> term = GeneratedColumn<String>(
    'term',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingMeta = const VerificationMeta(
    'reading',
  );
  @override
  late final GeneratedColumn<String> reading = GeneratedColumn<String>(
    'reading',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _definitionsMeta = const VerificationMeta(
    'definitions',
  );
  @override
  late final GeneratedColumn<String> definitions = GeneratedColumn<String>(
    'definitions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<int> frequency = GeneratedColumn<int>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _examplesMeta = const VerificationMeta(
    'examples',
  );
  @override
  late final GeneratedColumn<String> examples = GeneratedColumn<String>(
    'examples',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    term,
    reading,
    definitions,
    tags,
    frequency,
    examples,
    metadata,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_dictionary_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftDictionaryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('term')) {
      context.handle(
        _termMeta,
        term.isAcceptableOrUnknown(data['term']!, _termMeta),
      );
    } else if (isInserting) {
      context.missing(_termMeta);
    }
    if (data.containsKey('reading')) {
      context.handle(
        _readingMeta,
        reading.isAcceptableOrUnknown(data['reading']!, _readingMeta),
      );
    }
    if (data.containsKey('definitions')) {
      context.handle(
        _definitionsMeta,
        definitions.isAcceptableOrUnknown(
          data['definitions']!,
          _definitionsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_definitionsMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    }
    if (data.containsKey('examples')) {
      context.handle(
        _examplesMeta,
        examples.isAcceptableOrUnknown(data['examples']!, _examplesMeta),
      );
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftDictionaryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftDictionaryEntry(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      term:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}term'],
          )!,
      reading: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading'],
      ),
      definitions:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}definitions'],
          )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      ),
      frequency:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}frequency'],
          )!,
      examples: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}examples'],
      ),
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
    );
  }

  @override
  $DriftDictionaryEntriesTable createAlias(String alias) {
    return $DriftDictionaryEntriesTable(attachedDatabase, alias);
  }
}

class DriftDictionaryEntry extends DataClass
    implements Insertable<DriftDictionaryEntry> {
  final int id;
  final String term;
  final String? reading;
  final String definitions;
  final String? tags;
  final int frequency;
  final String? examples;
  final String? metadata;
  const DriftDictionaryEntry({
    required this.id,
    required this.term,
    this.reading,
    required this.definitions,
    this.tags,
    required this.frequency,
    this.examples,
    this.metadata,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['term'] = Variable<String>(term);
    if (!nullToAbsent || reading != null) {
      map['reading'] = Variable<String>(reading);
    }
    map['definitions'] = Variable<String>(definitions);
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['frequency'] = Variable<int>(frequency);
    if (!nullToAbsent || examples != null) {
      map['examples'] = Variable<String>(examples);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    return map;
  }

  DriftDictionaryEntriesCompanion toCompanion(bool nullToAbsent) {
    return DriftDictionaryEntriesCompanion(
      id: Value(id),
      term: Value(term),
      reading:
          reading == null && nullToAbsent
              ? const Value.absent()
              : Value(reading),
      definitions: Value(definitions),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      frequency: Value(frequency),
      examples:
          examples == null && nullToAbsent
              ? const Value.absent()
              : Value(examples),
      metadata:
          metadata == null && nullToAbsent
              ? const Value.absent()
              : Value(metadata),
    );
  }

  factory DriftDictionaryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftDictionaryEntry(
      id: serializer.fromJson<int>(json['id']),
      term: serializer.fromJson<String>(json['term']),
      reading: serializer.fromJson<String?>(json['reading']),
      definitions: serializer.fromJson<String>(json['definitions']),
      tags: serializer.fromJson<String?>(json['tags']),
      frequency: serializer.fromJson<int>(json['frequency']),
      examples: serializer.fromJson<String?>(json['examples']),
      metadata: serializer.fromJson<String?>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'term': serializer.toJson<String>(term),
      'reading': serializer.toJson<String?>(reading),
      'definitions': serializer.toJson<String>(definitions),
      'tags': serializer.toJson<String?>(tags),
      'frequency': serializer.toJson<int>(frequency),
      'examples': serializer.toJson<String?>(examples),
      'metadata': serializer.toJson<String?>(metadata),
    };
  }

  DriftDictionaryEntry copyWith({
    int? id,
    String? term,
    Value<String?> reading = const Value.absent(),
    String? definitions,
    Value<String?> tags = const Value.absent(),
    int? frequency,
    Value<String?> examples = const Value.absent(),
    Value<String?> metadata = const Value.absent(),
  }) => DriftDictionaryEntry(
    id: id ?? this.id,
    term: term ?? this.term,
    reading: reading.present ? reading.value : this.reading,
    definitions: definitions ?? this.definitions,
    tags: tags.present ? tags.value : this.tags,
    frequency: frequency ?? this.frequency,
    examples: examples.present ? examples.value : this.examples,
    metadata: metadata.present ? metadata.value : this.metadata,
  );
  DriftDictionaryEntry copyWithCompanion(DriftDictionaryEntriesCompanion data) {
    return DriftDictionaryEntry(
      id: data.id.present ? data.id.value : this.id,
      term: data.term.present ? data.term.value : this.term,
      reading: data.reading.present ? data.reading.value : this.reading,
      definitions:
          data.definitions.present ? data.definitions.value : this.definitions,
      tags: data.tags.present ? data.tags.value : this.tags,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      examples: data.examples.present ? data.examples.value : this.examples,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftDictionaryEntry(')
          ..write('id: $id, ')
          ..write('term: $term, ')
          ..write('reading: $reading, ')
          ..write('definitions: $definitions, ')
          ..write('tags: $tags, ')
          ..write('frequency: $frequency, ')
          ..write('examples: $examples, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    term,
    reading,
    definitions,
    tags,
    frequency,
    examples,
    metadata,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftDictionaryEntry &&
          other.id == this.id &&
          other.term == this.term &&
          other.reading == this.reading &&
          other.definitions == this.definitions &&
          other.tags == this.tags &&
          other.frequency == this.frequency &&
          other.examples == this.examples &&
          other.metadata == this.metadata);
}

class DriftDictionaryEntriesCompanion
    extends UpdateCompanion<DriftDictionaryEntry> {
  final Value<int> id;
  final Value<String> term;
  final Value<String?> reading;
  final Value<String> definitions;
  final Value<String?> tags;
  final Value<int> frequency;
  final Value<String?> examples;
  final Value<String?> metadata;
  const DriftDictionaryEntriesCompanion({
    this.id = const Value.absent(),
    this.term = const Value.absent(),
    this.reading = const Value.absent(),
    this.definitions = const Value.absent(),
    this.tags = const Value.absent(),
    this.frequency = const Value.absent(),
    this.examples = const Value.absent(),
    this.metadata = const Value.absent(),
  });
  DriftDictionaryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String term,
    this.reading = const Value.absent(),
    required String definitions,
    this.tags = const Value.absent(),
    this.frequency = const Value.absent(),
    this.examples = const Value.absent(),
    this.metadata = const Value.absent(),
  }) : term = Value(term),
       definitions = Value(definitions);
  static Insertable<DriftDictionaryEntry> custom({
    Expression<int>? id,
    Expression<String>? term,
    Expression<String>? reading,
    Expression<String>? definitions,
    Expression<String>? tags,
    Expression<int>? frequency,
    Expression<String>? examples,
    Expression<String>? metadata,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (term != null) 'term': term,
      if (reading != null) 'reading': reading,
      if (definitions != null) 'definitions': definitions,
      if (tags != null) 'tags': tags,
      if (frequency != null) 'frequency': frequency,
      if (examples != null) 'examples': examples,
      if (metadata != null) 'metadata': metadata,
    });
  }

  DriftDictionaryEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? term,
    Value<String?>? reading,
    Value<String>? definitions,
    Value<String?>? tags,
    Value<int>? frequency,
    Value<String?>? examples,
    Value<String?>? metadata,
  }) {
    return DriftDictionaryEntriesCompanion(
      id: id ?? this.id,
      term: term ?? this.term,
      reading: reading ?? this.reading,
      definitions: definitions ?? this.definitions,
      tags: tags ?? this.tags,
      frequency: frequency ?? this.frequency,
      examples: examples ?? this.examples,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (term.present) {
      map['term'] = Variable<String>(term.value);
    }
    if (reading.present) {
      map['reading'] = Variable<String>(reading.value);
    }
    if (definitions.present) {
      map['definitions'] = Variable<String>(definitions.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<int>(frequency.value);
    }
    if (examples.present) {
      map['examples'] = Variable<String>(examples.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftDictionaryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('term: $term, ')
          ..write('reading: $reading, ')
          ..write('definitions: $definitions, ')
          ..write('tags: $tags, ')
          ..write('frequency: $frequency, ')
          ..write('examples: $examples, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }
}

class $DriftTonesTable extends DriftTones
    with TableInfo<$DriftTonesTable, DriftTone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DriftTonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dictionaryIdMeta = const VerificationMeta(
    'dictionaryId',
  );
  @override
  late final GeneratedColumn<int> dictionaryId = GeneratedColumn<int>(
    'dictionary_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _termMeta = const VerificationMeta('term');
  @override
  late final GeneratedColumn<String> term = GeneratedColumn<String>(
    'term',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingMeta = const VerificationMeta(
    'reading',
  );
  @override
  late final GeneratedColumn<String> reading = GeneratedColumn<String>(
    'reading',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tonesMeta = const VerificationMeta('tones');
  @override
  late final GeneratedColumn<String> tones = GeneratedColumn<String>(
    'tones',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dictionaryId,
    term,
    reading,
    language,
    tones,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drift_tones';
  @override
  VerificationContext validateIntegrity(
    Insertable<DriftTone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dictionary_id')) {
      context.handle(
        _dictionaryIdMeta,
        dictionaryId.isAcceptableOrUnknown(
          data['dictionary_id']!,
          _dictionaryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dictionaryIdMeta);
    }
    if (data.containsKey('term')) {
      context.handle(
        _termMeta,
        term.isAcceptableOrUnknown(data['term']!, _termMeta),
      );
    } else if (isInserting) {
      context.missing(_termMeta);
    }
    if (data.containsKey('reading')) {
      context.handle(
        _readingMeta,
        reading.isAcceptableOrUnknown(data['reading']!, _readingMeta),
      );
    } else if (isInserting) {
      context.missing(_readingMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    } else if (isInserting) {
      context.missing(_languageMeta);
    }
    if (data.containsKey('tones')) {
      context.handle(
        _tonesMeta,
        tones.isAcceptableOrUnknown(data['tones']!, _tonesMeta),
      );
    } else if (isInserting) {
      context.missing(_tonesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DriftTone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DriftTone(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      dictionaryId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}dictionary_id'],
          )!,
      term:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}term'],
          )!,
      reading:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}reading'],
          )!,
      language:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}language'],
          )!,
      tones:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}tones'],
          )!,
    );
  }

  @override
  $DriftTonesTable createAlias(String alias) {
    return $DriftTonesTable(attachedDatabase, alias);
  }
}

class DriftTone extends DataClass implements Insertable<DriftTone> {
  final int id;
  final int dictionaryId;
  final String term;
  final String reading;
  final String language;
  final String tones;
  const DriftTone({
    required this.id,
    required this.dictionaryId,
    required this.term,
    required this.reading,
    required this.language,
    required this.tones,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['dictionary_id'] = Variable<int>(dictionaryId);
    map['term'] = Variable<String>(term);
    map['reading'] = Variable<String>(reading);
    map['language'] = Variable<String>(language);
    map['tones'] = Variable<String>(tones);
    return map;
  }

  DriftTonesCompanion toCompanion(bool nullToAbsent) {
    return DriftTonesCompanion(
      id: Value(id),
      dictionaryId: Value(dictionaryId),
      term: Value(term),
      reading: Value(reading),
      language: Value(language),
      tones: Value(tones),
    );
  }

  factory DriftTone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DriftTone(
      id: serializer.fromJson<int>(json['id']),
      dictionaryId: serializer.fromJson<int>(json['dictionaryId']),
      term: serializer.fromJson<String>(json['term']),
      reading: serializer.fromJson<String>(json['reading']),
      language: serializer.fromJson<String>(json['language']),
      tones: serializer.fromJson<String>(json['tones']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dictionaryId': serializer.toJson<int>(dictionaryId),
      'term': serializer.toJson<String>(term),
      'reading': serializer.toJson<String>(reading),
      'language': serializer.toJson<String>(language),
      'tones': serializer.toJson<String>(tones),
    };
  }

  DriftTone copyWith({
    int? id,
    int? dictionaryId,
    String? term,
    String? reading,
    String? language,
    String? tones,
  }) => DriftTone(
    id: id ?? this.id,
    dictionaryId: dictionaryId ?? this.dictionaryId,
    term: term ?? this.term,
    reading: reading ?? this.reading,
    language: language ?? this.language,
    tones: tones ?? this.tones,
  );
  DriftTone copyWithCompanion(DriftTonesCompanion data) {
    return DriftTone(
      id: data.id.present ? data.id.value : this.id,
      dictionaryId:
          data.dictionaryId.present
              ? data.dictionaryId.value
              : this.dictionaryId,
      term: data.term.present ? data.term.value : this.term,
      reading: data.reading.present ? data.reading.value : this.reading,
      language: data.language.present ? data.language.value : this.language,
      tones: data.tones.present ? data.tones.value : this.tones,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DriftTone(')
          ..write('id: $id, ')
          ..write('dictionaryId: $dictionaryId, ')
          ..write('term: $term, ')
          ..write('reading: $reading, ')
          ..write('language: $language, ')
          ..write('tones: $tones')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, dictionaryId, term, reading, language, tones);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriftTone &&
          other.id == this.id &&
          other.dictionaryId == this.dictionaryId &&
          other.term == this.term &&
          other.reading == this.reading &&
          other.language == this.language &&
          other.tones == this.tones);
}

class DriftTonesCompanion extends UpdateCompanion<DriftTone> {
  final Value<int> id;
  final Value<int> dictionaryId;
  final Value<String> term;
  final Value<String> reading;
  final Value<String> language;
  final Value<String> tones;
  const DriftTonesCompanion({
    this.id = const Value.absent(),
    this.dictionaryId = const Value.absent(),
    this.term = const Value.absent(),
    this.reading = const Value.absent(),
    this.language = const Value.absent(),
    this.tones = const Value.absent(),
  });
  DriftTonesCompanion.insert({
    this.id = const Value.absent(),
    required int dictionaryId,
    required String term,
    required String reading,
    required String language,
    required String tones,
  }) : dictionaryId = Value(dictionaryId),
       term = Value(term),
       reading = Value(reading),
       language = Value(language),
       tones = Value(tones);
  static Insertable<DriftTone> custom({
    Expression<int>? id,
    Expression<int>? dictionaryId,
    Expression<String>? term,
    Expression<String>? reading,
    Expression<String>? language,
    Expression<String>? tones,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dictionaryId != null) 'dictionary_id': dictionaryId,
      if (term != null) 'term': term,
      if (reading != null) 'reading': reading,
      if (language != null) 'language': language,
      if (tones != null) 'tones': tones,
    });
  }

  DriftTonesCompanion copyWith({
    Value<int>? id,
    Value<int>? dictionaryId,
    Value<String>? term,
    Value<String>? reading,
    Value<String>? language,
    Value<String>? tones,
  }) {
    return DriftTonesCompanion(
      id: id ?? this.id,
      dictionaryId: dictionaryId ?? this.dictionaryId,
      term: term ?? this.term,
      reading: reading ?? this.reading,
      language: language ?? this.language,
      tones: tones ?? this.tones,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dictionaryId.present) {
      map['dictionary_id'] = Variable<int>(dictionaryId.value);
    }
    if (term.present) {
      map['term'] = Variable<String>(term.value);
    }
    if (reading.present) {
      map['reading'] = Variable<String>(reading.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (tones.present) {
      map['tones'] = Variable<String>(tones.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DriftTonesCompanion(')
          ..write('id: $id, ')
          ..write('dictionaryId: $dictionaryId, ')
          ..write('term: $term, ')
          ..write('reading: $reading, ')
          ..write('language: $language, ')
          ..write('tones: $tones')
          ..write(')'))
        .toString();
  }
}

class $WordOccurrencesTable extends WordOccurrences
    with TableInfo<$WordOccurrencesTable, WordOccurrence> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordOccurrencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingMeta = const VerificationMeta(
    'reading',
  );
  @override
  late final GeneratedColumn<String> reading = GeneratedColumn<String>(
    'reading',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseFormMeta = const VerificationMeta(
    'baseForm',
  );
  @override
  late final GeneratedColumn<String> baseForm = GeneratedColumn<String>(
    'base_form',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentenceIdMeta = const VerificationMeta(
    'sentenceId',
  );
  @override
  late final GeneratedColumn<int> sentenceId = GeneratedColumn<int>(
    'sentence_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    word,
    reading,
    baseForm,
    position,
    sentenceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_occurrences';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordOccurrence> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('reading')) {
      context.handle(
        _readingMeta,
        reading.isAcceptableOrUnknown(data['reading']!, _readingMeta),
      );
    }
    if (data.containsKey('base_form')) {
      context.handle(
        _baseFormMeta,
        baseForm.isAcceptableOrUnknown(data['base_form']!, _baseFormMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('sentence_id')) {
      context.handle(
        _sentenceIdMeta,
        sentenceId.isAcceptableOrUnknown(data['sentence_id']!, _sentenceIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WordOccurrence map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordOccurrence(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      word:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}word'],
          )!,
      reading: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading'],
      ),
      baseForm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_form'],
      ),
      position:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}position'],
          )!,
      sentenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sentence_id'],
      ),
    );
  }

  @override
  $WordOccurrencesTable createAlias(String alias) {
    return $WordOccurrencesTable(attachedDatabase, alias);
  }
}

class WordOccurrence extends DataClass implements Insertable<WordOccurrence> {
  final int id;
  final String word;
  final String? reading;
  final String? baseForm;
  final int position;
  final int? sentenceId;
  const WordOccurrence({
    required this.id,
    required this.word,
    this.reading,
    this.baseForm,
    required this.position,
    this.sentenceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word'] = Variable<String>(word);
    if (!nullToAbsent || reading != null) {
      map['reading'] = Variable<String>(reading);
    }
    if (!nullToAbsent || baseForm != null) {
      map['base_form'] = Variable<String>(baseForm);
    }
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || sentenceId != null) {
      map['sentence_id'] = Variable<int>(sentenceId);
    }
    return map;
  }

  WordOccurrencesCompanion toCompanion(bool nullToAbsent) {
    return WordOccurrencesCompanion(
      id: Value(id),
      word: Value(word),
      reading:
          reading == null && nullToAbsent
              ? const Value.absent()
              : Value(reading),
      baseForm:
          baseForm == null && nullToAbsent
              ? const Value.absent()
              : Value(baseForm),
      position: Value(position),
      sentenceId:
          sentenceId == null && nullToAbsent
              ? const Value.absent()
              : Value(sentenceId),
    );
  }

  factory WordOccurrence.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordOccurrence(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      reading: serializer.fromJson<String?>(json['reading']),
      baseForm: serializer.fromJson<String?>(json['baseForm']),
      position: serializer.fromJson<int>(json['position']),
      sentenceId: serializer.fromJson<int?>(json['sentenceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'word': serializer.toJson<String>(word),
      'reading': serializer.toJson<String?>(reading),
      'baseForm': serializer.toJson<String?>(baseForm),
      'position': serializer.toJson<int>(position),
      'sentenceId': serializer.toJson<int?>(sentenceId),
    };
  }

  WordOccurrence copyWith({
    int? id,
    String? word,
    Value<String?> reading = const Value.absent(),
    Value<String?> baseForm = const Value.absent(),
    int? position,
    Value<int?> sentenceId = const Value.absent(),
  }) => WordOccurrence(
    id: id ?? this.id,
    word: word ?? this.word,
    reading: reading.present ? reading.value : this.reading,
    baseForm: baseForm.present ? baseForm.value : this.baseForm,
    position: position ?? this.position,
    sentenceId: sentenceId.present ? sentenceId.value : this.sentenceId,
  );
  WordOccurrence copyWithCompanion(WordOccurrencesCompanion data) {
    return WordOccurrence(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      reading: data.reading.present ? data.reading.value : this.reading,
      baseForm: data.baseForm.present ? data.baseForm.value : this.baseForm,
      position: data.position.present ? data.position.value : this.position,
      sentenceId:
          data.sentenceId.present ? data.sentenceId.value : this.sentenceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordOccurrence(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('reading: $reading, ')
          ..write('baseForm: $baseForm, ')
          ..write('position: $position, ')
          ..write('sentenceId: $sentenceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, word, reading, baseForm, position, sentenceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordOccurrence &&
          other.id == this.id &&
          other.word == this.word &&
          other.reading == this.reading &&
          other.baseForm == this.baseForm &&
          other.position == this.position &&
          other.sentenceId == this.sentenceId);
}

class WordOccurrencesCompanion extends UpdateCompanion<WordOccurrence> {
  final Value<int> id;
  final Value<String> word;
  final Value<String?> reading;
  final Value<String?> baseForm;
  final Value<int> position;
  final Value<int?> sentenceId;
  const WordOccurrencesCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.reading = const Value.absent(),
    this.baseForm = const Value.absent(),
    this.position = const Value.absent(),
    this.sentenceId = const Value.absent(),
  });
  WordOccurrencesCompanion.insert({
    this.id = const Value.absent(),
    required String word,
    this.reading = const Value.absent(),
    this.baseForm = const Value.absent(),
    required int position,
    this.sentenceId = const Value.absent(),
  }) : word = Value(word),
       position = Value(position);
  static Insertable<WordOccurrence> custom({
    Expression<int>? id,
    Expression<String>? word,
    Expression<String>? reading,
    Expression<String>? baseForm,
    Expression<int>? position,
    Expression<int>? sentenceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (reading != null) 'reading': reading,
      if (baseForm != null) 'base_form': baseForm,
      if (position != null) 'position': position,
      if (sentenceId != null) 'sentence_id': sentenceId,
    });
  }

  WordOccurrencesCompanion copyWith({
    Value<int>? id,
    Value<String>? word,
    Value<String?>? reading,
    Value<String?>? baseForm,
    Value<int>? position,
    Value<int?>? sentenceId,
  }) {
    return WordOccurrencesCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      reading: reading ?? this.reading,
      baseForm: baseForm ?? this.baseForm,
      position: position ?? this.position,
      sentenceId: sentenceId ?? this.sentenceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (reading.present) {
      map['reading'] = Variable<String>(reading.value);
    }
    if (baseForm.present) {
      map['base_form'] = Variable<String>(baseForm.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (sentenceId.present) {
      map['sentence_id'] = Variable<int>(sentenceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordOccurrencesCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('reading: $reading, ')
          ..write('baseForm: $baseForm, ')
          ..write('position: $position, ')
          ..write('sentenceId: $sentenceId')
          ..write(')'))
        .toString();
  }
}

class $JapaneseTextFtsTable extends JapaneseTextFts
    with TableInfo<$JapaneseTextFtsTable, JapaneseTextFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JapaneseTextFtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [content];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'japanese_text_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<JapaneseTextFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  JapaneseTextFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JapaneseTextFt(
      content:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content'],
          )!,
    );
  }

  @override
  $JapaneseTextFtsTable createAlias(String alias) {
    return $JapaneseTextFtsTable(attachedDatabase, alias);
  }
}

class JapaneseTextFt extends DataClass implements Insertable<JapaneseTextFt> {
  final String content;
  const JapaneseTextFt({required this.content});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content'] = Variable<String>(content);
    return map;
  }

  JapaneseTextFtsCompanion toCompanion(bool nullToAbsent) {
    return JapaneseTextFtsCompanion(content: Value(content));
  }

  factory JapaneseTextFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JapaneseTextFt(
      content: serializer.fromJson<String>(json['content']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'content': serializer.toJson<String>(content)};
  }

  JapaneseTextFt copyWith({String? content}) =>
      JapaneseTextFt(content: content ?? this.content);
  JapaneseTextFt copyWithCompanion(JapaneseTextFtsCompanion data) {
    return JapaneseTextFt(
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JapaneseTextFt(')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => content.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JapaneseTextFt && other.content == this.content);
}

class JapaneseTextFtsCompanion extends UpdateCompanion<JapaneseTextFt> {
  final Value<String> content;
  final Value<int> rowid;
  const JapaneseTextFtsCompanion({
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JapaneseTextFtsCompanion.insert({
    required String content,
    this.rowid = const Value.absent(),
  }) : content = Value(content);
  static Insertable<JapaneseTextFt> custom({
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JapaneseTextFtsCompanion copyWith({
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return JapaneseTextFtsCompanion(
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JapaneseTextFtsCompanion(')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChineseTextFtsTable extends ChineseTextFts
    with TableInfo<$ChineseTextFtsTable, ChineseTextFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChineseTextFtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [content];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chinese_text_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChineseTextFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  ChineseTextFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChineseTextFt(
      content:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content'],
          )!,
    );
  }

  @override
  $ChineseTextFtsTable createAlias(String alias) {
    return $ChineseTextFtsTable(attachedDatabase, alias);
  }
}

class ChineseTextFt extends DataClass implements Insertable<ChineseTextFt> {
  final String content;
  const ChineseTextFt({required this.content});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content'] = Variable<String>(content);
    return map;
  }

  ChineseTextFtsCompanion toCompanion(bool nullToAbsent) {
    return ChineseTextFtsCompanion(content: Value(content));
  }

  factory ChineseTextFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChineseTextFt(content: serializer.fromJson<String>(json['content']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'content': serializer.toJson<String>(content)};
  }

  ChineseTextFt copyWith({String? content}) =>
      ChineseTextFt(content: content ?? this.content);
  ChineseTextFt copyWithCompanion(ChineseTextFtsCompanion data) {
    return ChineseTextFt(
      content: data.content.present ? data.content.value : this.content,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChineseTextFt(')
          ..write('content: $content')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => content.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChineseTextFt && other.content == this.content);
}

class ChineseTextFtsCompanion extends UpdateCompanion<ChineseTextFt> {
  final Value<String> content;
  final Value<int> rowid;
  const ChineseTextFtsCompanion({
    this.content = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChineseTextFtsCompanion.insert({
    required String content,
    this.rowid = const Value.absent(),
  }) : content = Value(content);
  static Insertable<ChineseTextFt> custom({
    Expression<String>? content,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (content != null) 'content': content,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChineseTextFtsCompanion copyWith({
    Value<String>? content,
    Value<int>? rowid,
  }) {
    return ChineseTextFtsCompanion(
      content: content ?? this.content,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChineseTextFtsCompanion(')
          ..write('content: $content, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DriftDictionaryEntriesTable driftDictionaryEntries =
      $DriftDictionaryEntriesTable(this);
  late final $DriftTonesTable driftTones = $DriftTonesTable(this);
  late final $WordOccurrencesTable wordOccurrences = $WordOccurrencesTable(
    this,
  );
  late final $JapaneseTextFtsTable japaneseTextFts = $JapaneseTextFtsTable(
    this,
  );
  late final $ChineseTextFtsTable chineseTextFts = $ChineseTextFtsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    driftDictionaryEntries,
    driftTones,
    wordOccurrences,
    japaneseTextFts,
    chineseTextFts,
  ];
}

typedef $$DriftDictionaryEntriesTableCreateCompanionBuilder =
    DriftDictionaryEntriesCompanion Function({
      Value<int> id,
      required String term,
      Value<String?> reading,
      required String definitions,
      Value<String?> tags,
      Value<int> frequency,
      Value<String?> examples,
      Value<String?> metadata,
    });
typedef $$DriftDictionaryEntriesTableUpdateCompanionBuilder =
    DriftDictionaryEntriesCompanion Function({
      Value<int> id,
      Value<String> term,
      Value<String?> reading,
      Value<String> definitions,
      Value<String?> tags,
      Value<int> frequency,
      Value<String?> examples,
      Value<String?> metadata,
    });

class $$DriftDictionaryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DriftDictionaryEntriesTable> {
  $$DriftDictionaryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reading => $composableBuilder(
    column: $table.reading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitions => $composableBuilder(
    column: $table.definitions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examples => $composableBuilder(
    column: $table.examples,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriftDictionaryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DriftDictionaryEntriesTable> {
  $$DriftDictionaryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reading => $composableBuilder(
    column: $table.reading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitions => $composableBuilder(
    column: $table.definitions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examples => $composableBuilder(
    column: $table.examples,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriftDictionaryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DriftDictionaryEntriesTable> {
  $$DriftDictionaryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get term =>
      $composableBuilder(column: $table.term, builder: (column) => column);

  GeneratedColumn<String> get reading =>
      $composableBuilder(column: $table.reading, builder: (column) => column);

  GeneratedColumn<String> get definitions => $composableBuilder(
    column: $table.definitions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<int> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<String> get examples =>
      $composableBuilder(column: $table.examples, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);
}

class $$DriftDictionaryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DriftDictionaryEntriesTable,
          DriftDictionaryEntry,
          $$DriftDictionaryEntriesTableFilterComposer,
          $$DriftDictionaryEntriesTableOrderingComposer,
          $$DriftDictionaryEntriesTableAnnotationComposer,
          $$DriftDictionaryEntriesTableCreateCompanionBuilder,
          $$DriftDictionaryEntriesTableUpdateCompanionBuilder,
          (
            DriftDictionaryEntry,
            BaseReferences<
              _$AppDatabase,
              $DriftDictionaryEntriesTable,
              DriftDictionaryEntry
            >,
          ),
          DriftDictionaryEntry,
          PrefetchHooks Function()
        > {
  $$DriftDictionaryEntriesTableTableManager(
    _$AppDatabase db,
    $DriftDictionaryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DriftDictionaryEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$DriftDictionaryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$DriftDictionaryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> term = const Value.absent(),
                Value<String?> reading = const Value.absent(),
                Value<String> definitions = const Value.absent(),
                Value<String?> tags = const Value.absent(),
                Value<int> frequency = const Value.absent(),
                Value<String?> examples = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
              }) => DriftDictionaryEntriesCompanion(
                id: id,
                term: term,
                reading: reading,
                definitions: definitions,
                tags: tags,
                frequency: frequency,
                examples: examples,
                metadata: metadata,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String term,
                Value<String?> reading = const Value.absent(),
                required String definitions,
                Value<String?> tags = const Value.absent(),
                Value<int> frequency = const Value.absent(),
                Value<String?> examples = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
              }) => DriftDictionaryEntriesCompanion.insert(
                id: id,
                term: term,
                reading: reading,
                definitions: definitions,
                tags: tags,
                frequency: frequency,
                examples: examples,
                metadata: metadata,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriftDictionaryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DriftDictionaryEntriesTable,
      DriftDictionaryEntry,
      $$DriftDictionaryEntriesTableFilterComposer,
      $$DriftDictionaryEntriesTableOrderingComposer,
      $$DriftDictionaryEntriesTableAnnotationComposer,
      $$DriftDictionaryEntriesTableCreateCompanionBuilder,
      $$DriftDictionaryEntriesTableUpdateCompanionBuilder,
      (
        DriftDictionaryEntry,
        BaseReferences<
          _$AppDatabase,
          $DriftDictionaryEntriesTable,
          DriftDictionaryEntry
        >,
      ),
      DriftDictionaryEntry,
      PrefetchHooks Function()
    >;
typedef $$DriftTonesTableCreateCompanionBuilder =
    DriftTonesCompanion Function({
      Value<int> id,
      required int dictionaryId,
      required String term,
      required String reading,
      required String language,
      required String tones,
    });
typedef $$DriftTonesTableUpdateCompanionBuilder =
    DriftTonesCompanion Function({
      Value<int> id,
      Value<int> dictionaryId,
      Value<String> term,
      Value<String> reading,
      Value<String> language,
      Value<String> tones,
    });

class $$DriftTonesTableFilterComposer
    extends Composer<_$AppDatabase, $DriftTonesTable> {
  $$DriftTonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dictionaryId => $composableBuilder(
    column: $table.dictionaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reading => $composableBuilder(
    column: $table.reading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tones => $composableBuilder(
    column: $table.tones,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DriftTonesTableOrderingComposer
    extends Composer<_$AppDatabase, $DriftTonesTable> {
  $$DriftTonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dictionaryId => $composableBuilder(
    column: $table.dictionaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get term => $composableBuilder(
    column: $table.term,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reading => $composableBuilder(
    column: $table.reading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tones => $composableBuilder(
    column: $table.tones,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DriftTonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DriftTonesTable> {
  $$DriftTonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dictionaryId => $composableBuilder(
    column: $table.dictionaryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get term =>
      $composableBuilder(column: $table.term, builder: (column) => column);

  GeneratedColumn<String> get reading =>
      $composableBuilder(column: $table.reading, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get tones =>
      $composableBuilder(column: $table.tones, builder: (column) => column);
}

class $$DriftTonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DriftTonesTable,
          DriftTone,
          $$DriftTonesTableFilterComposer,
          $$DriftTonesTableOrderingComposer,
          $$DriftTonesTableAnnotationComposer,
          $$DriftTonesTableCreateCompanionBuilder,
          $$DriftTonesTableUpdateCompanionBuilder,
          (
            DriftTone,
            BaseReferences<_$AppDatabase, $DriftTonesTable, DriftTone>,
          ),
          DriftTone,
          PrefetchHooks Function()
        > {
  $$DriftTonesTableTableManager(_$AppDatabase db, $DriftTonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$DriftTonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$DriftTonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$DriftTonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dictionaryId = const Value.absent(),
                Value<String> term = const Value.absent(),
                Value<String> reading = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> tones = const Value.absent(),
              }) => DriftTonesCompanion(
                id: id,
                dictionaryId: dictionaryId,
                term: term,
                reading: reading,
                language: language,
                tones: tones,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int dictionaryId,
                required String term,
                required String reading,
                required String language,
                required String tones,
              }) => DriftTonesCompanion.insert(
                id: id,
                dictionaryId: dictionaryId,
                term: term,
                reading: reading,
                language: language,
                tones: tones,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DriftTonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DriftTonesTable,
      DriftTone,
      $$DriftTonesTableFilterComposer,
      $$DriftTonesTableOrderingComposer,
      $$DriftTonesTableAnnotationComposer,
      $$DriftTonesTableCreateCompanionBuilder,
      $$DriftTonesTableUpdateCompanionBuilder,
      (DriftTone, BaseReferences<_$AppDatabase, $DriftTonesTable, DriftTone>),
      DriftTone,
      PrefetchHooks Function()
    >;
typedef $$WordOccurrencesTableCreateCompanionBuilder =
    WordOccurrencesCompanion Function({
      Value<int> id,
      required String word,
      Value<String?> reading,
      Value<String?> baseForm,
      required int position,
      Value<int?> sentenceId,
    });
typedef $$WordOccurrencesTableUpdateCompanionBuilder =
    WordOccurrencesCompanion Function({
      Value<int> id,
      Value<String> word,
      Value<String?> reading,
      Value<String?> baseForm,
      Value<int> position,
      Value<int?> sentenceId,
    });

class $$WordOccurrencesTableFilterComposer
    extends Composer<_$AppDatabase, $WordOccurrencesTable> {
  $$WordOccurrencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reading => $composableBuilder(
    column: $table.reading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseForm => $composableBuilder(
    column: $table.baseForm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordOccurrencesTableOrderingComposer
    extends Composer<_$AppDatabase, $WordOccurrencesTable> {
  $$WordOccurrencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reading => $composableBuilder(
    column: $table.reading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseForm => $composableBuilder(
    column: $table.baseForm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordOccurrencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordOccurrencesTable> {
  $$WordOccurrencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get reading =>
      $composableBuilder(column: $table.reading, builder: (column) => column);

  GeneratedColumn<String> get baseForm =>
      $composableBuilder(column: $table.baseForm, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get sentenceId => $composableBuilder(
    column: $table.sentenceId,
    builder: (column) => column,
  );
}

class $$WordOccurrencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordOccurrencesTable,
          WordOccurrence,
          $$WordOccurrencesTableFilterComposer,
          $$WordOccurrencesTableOrderingComposer,
          $$WordOccurrencesTableAnnotationComposer,
          $$WordOccurrencesTableCreateCompanionBuilder,
          $$WordOccurrencesTableUpdateCompanionBuilder,
          (
            WordOccurrence,
            BaseReferences<
              _$AppDatabase,
              $WordOccurrencesTable,
              WordOccurrence
            >,
          ),
          WordOccurrence,
          PrefetchHooks Function()
        > {
  $$WordOccurrencesTableTableManager(
    _$AppDatabase db,
    $WordOccurrencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$WordOccurrencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$WordOccurrencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$WordOccurrencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String?> reading = const Value.absent(),
                Value<String?> baseForm = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> sentenceId = const Value.absent(),
              }) => WordOccurrencesCompanion(
                id: id,
                word: word,
                reading: reading,
                baseForm: baseForm,
                position: position,
                sentenceId: sentenceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String word,
                Value<String?> reading = const Value.absent(),
                Value<String?> baseForm = const Value.absent(),
                required int position,
                Value<int?> sentenceId = const Value.absent(),
              }) => WordOccurrencesCompanion.insert(
                id: id,
                word: word,
                reading: reading,
                baseForm: baseForm,
                position: position,
                sentenceId: sentenceId,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordOccurrencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordOccurrencesTable,
      WordOccurrence,
      $$WordOccurrencesTableFilterComposer,
      $$WordOccurrencesTableOrderingComposer,
      $$WordOccurrencesTableAnnotationComposer,
      $$WordOccurrencesTableCreateCompanionBuilder,
      $$WordOccurrencesTableUpdateCompanionBuilder,
      (
        WordOccurrence,
        BaseReferences<_$AppDatabase, $WordOccurrencesTable, WordOccurrence>,
      ),
      WordOccurrence,
      PrefetchHooks Function()
    >;
typedef $$JapaneseTextFtsTableCreateCompanionBuilder =
    JapaneseTextFtsCompanion Function({
      required String content,
      Value<int> rowid,
    });
typedef $$JapaneseTextFtsTableUpdateCompanionBuilder =
    JapaneseTextFtsCompanion Function({
      Value<String> content,
      Value<int> rowid,
    });

class $$JapaneseTextFtsTableFilterComposer
    extends Composer<_$AppDatabase, $JapaneseTextFtsTable> {
  $$JapaneseTextFtsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );
}

class $$JapaneseTextFtsTableOrderingComposer
    extends Composer<_$AppDatabase, $JapaneseTextFtsTable> {
  $$JapaneseTextFtsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JapaneseTextFtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $JapaneseTextFtsTable> {
  $$JapaneseTextFtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);
}

class $$JapaneseTextFtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JapaneseTextFtsTable,
          JapaneseTextFt,
          $$JapaneseTextFtsTableFilterComposer,
          $$JapaneseTextFtsTableOrderingComposer,
          $$JapaneseTextFtsTableAnnotationComposer,
          $$JapaneseTextFtsTableCreateCompanionBuilder,
          $$JapaneseTextFtsTableUpdateCompanionBuilder,
          (
            JapaneseTextFt,
            BaseReferences<
              _$AppDatabase,
              $JapaneseTextFtsTable,
              JapaneseTextFt
            >,
          ),
          JapaneseTextFt,
          PrefetchHooks Function()
        > {
  $$JapaneseTextFtsTableTableManager(
    _$AppDatabase db,
    $JapaneseTextFtsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$JapaneseTextFtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$JapaneseTextFtsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$JapaneseTextFtsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JapaneseTextFtsCompanion(content: content, rowid: rowid),
          createCompanionCallback:
              ({
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => JapaneseTextFtsCompanion.insert(
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JapaneseTextFtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JapaneseTextFtsTable,
      JapaneseTextFt,
      $$JapaneseTextFtsTableFilterComposer,
      $$JapaneseTextFtsTableOrderingComposer,
      $$JapaneseTextFtsTableAnnotationComposer,
      $$JapaneseTextFtsTableCreateCompanionBuilder,
      $$JapaneseTextFtsTableUpdateCompanionBuilder,
      (
        JapaneseTextFt,
        BaseReferences<_$AppDatabase, $JapaneseTextFtsTable, JapaneseTextFt>,
      ),
      JapaneseTextFt,
      PrefetchHooks Function()
    >;
typedef $$ChineseTextFtsTableCreateCompanionBuilder =
    ChineseTextFtsCompanion Function({
      required String content,
      Value<int> rowid,
    });
typedef $$ChineseTextFtsTableUpdateCompanionBuilder =
    ChineseTextFtsCompanion Function({Value<String> content, Value<int> rowid});

class $$ChineseTextFtsTableFilterComposer
    extends Composer<_$AppDatabase, $ChineseTextFtsTable> {
  $$ChineseTextFtsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChineseTextFtsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChineseTextFtsTable> {
  $$ChineseTextFtsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChineseTextFtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChineseTextFtsTable> {
  $$ChineseTextFtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);
}

class $$ChineseTextFtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChineseTextFtsTable,
          ChineseTextFt,
          $$ChineseTextFtsTableFilterComposer,
          $$ChineseTextFtsTableOrderingComposer,
          $$ChineseTextFtsTableAnnotationComposer,
          $$ChineseTextFtsTableCreateCompanionBuilder,
          $$ChineseTextFtsTableUpdateCompanionBuilder,
          (
            ChineseTextFt,
            BaseReferences<_$AppDatabase, $ChineseTextFtsTable, ChineseTextFt>,
          ),
          ChineseTextFt,
          PrefetchHooks Function()
        > {
  $$ChineseTextFtsTableTableManager(
    _$AppDatabase db,
    $ChineseTextFtsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ChineseTextFtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ChineseTextFtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ChineseTextFtsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> content = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChineseTextFtsCompanion(content: content, rowid: rowid),
          createCompanionCallback:
              ({
                required String content,
                Value<int> rowid = const Value.absent(),
              }) => ChineseTextFtsCompanion.insert(
                content: content,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChineseTextFtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChineseTextFtsTable,
      ChineseTextFt,
      $$ChineseTextFtsTableFilterComposer,
      $$ChineseTextFtsTableOrderingComposer,
      $$ChineseTextFtsTableAnnotationComposer,
      $$ChineseTextFtsTableCreateCompanionBuilder,
      $$ChineseTextFtsTableUpdateCompanionBuilder,
      (
        ChineseTextFt,
        BaseReferences<_$AppDatabase, $ChineseTextFtsTable, ChineseTextFt>,
      ),
      ChineseTextFt,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DriftDictionaryEntriesTableTableManager get driftDictionaryEntries =>
      $$DriftDictionaryEntriesTableTableManager(
        _db,
        _db.driftDictionaryEntries,
      );
  $$DriftTonesTableTableManager get driftTones =>
      $$DriftTonesTableTableManager(_db, _db.driftTones);
  $$WordOccurrencesTableTableManager get wordOccurrences =>
      $$WordOccurrencesTableTableManager(_db, _db.wordOccurrences);
  $$JapaneseTextFtsTableTableManager get japaneseTextFts =>
      $$JapaneseTextFtsTableTableManager(_db, _db.japaneseTextFts);
  $$ChineseTextFtsTableTableManager get chineseTextFts =>
      $$ChineseTextFtsTableTableManager(_db, _db.chineseTextFts);
}
