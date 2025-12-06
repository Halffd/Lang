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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DriftDictionaryEntriesTable driftDictionaryEntries =
      $DriftDictionaryEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [driftDictionaryEntries];
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DriftDictionaryEntriesTableTableManager get driftDictionaryEntries =>
      $$DriftDictionaryEntriesTableTableManager(
        _db,
        _db.driftDictionaryEntries,
      );
}
