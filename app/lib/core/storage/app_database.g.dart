// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedResponsesTable extends CachedResponses
    with TableInfo<$CachedResponsesTable, CachedResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rulesetVersionMeta = const VerificationMeta(
    'rulesetVersion',
  );
  @override
  late final GeneratedColumn<String> rulesetVersion = GeneratedColumn<String>(
    'ruleset_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evidenceAccessMeta = const VerificationMeta(
    'evidenceAccess',
  );
  @override
  late final GeneratedColumn<String> evidenceAccess = GeneratedColumn<String>(
    'evidence_access',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    kind,
    cacheKey,
    json,
    rulesetVersion,
    evidenceAccess,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedResponse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('ruleset_version')) {
      context.handle(
        _rulesetVersionMeta,
        rulesetVersion.isAcceptableOrUnknown(
          data['ruleset_version']!,
          _rulesetVersionMeta,
        ),
      );
    }
    if (data.containsKey('evidence_access')) {
      context.handle(
        _evidenceAccessMeta,
        evidenceAccess.isAcceptableOrUnknown(
          data['evidence_access']!,
          _evidenceAccessMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_evidenceAccessMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, kind, cacheKey};
  @override
  CachedResponse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedResponse(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      rulesetVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ruleset_version'],
      ),
      evidenceAccess: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_access'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedResponsesTable createAlias(String alias) {
    return $CachedResponsesTable(attachedDatabase, alias);
  }
}

class CachedResponse extends DataClass implements Insertable<CachedResponse> {
  /// 소유 계정 id.
  final String accountId;

  /// `CacheKind.name`.
  final String kind;

  /// 종류 안의 캐시 키.
  final String cacheKey;

  /// 저장한 JSON 본문.
  final String json;

  /// 응답을 만든 규칙 버전. 없는 응답은 null입니다.
  final String? rulesetVersion;

  /// `EvidenceAccess.value`.
  final String evidenceAccess;

  /// 받은 시각(UTC).
  final DateTime fetchedAt;
  const CachedResponse({
    required this.accountId,
    required this.kind,
    required this.cacheKey,
    required this.json,
    this.rulesetVersion,
    required this.evidenceAccess,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['kind'] = Variable<String>(kind);
    map['cache_key'] = Variable<String>(cacheKey);
    map['json'] = Variable<String>(json);
    if (!nullToAbsent || rulesetVersion != null) {
      map['ruleset_version'] = Variable<String>(rulesetVersion);
    }
    map['evidence_access'] = Variable<String>(evidenceAccess);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedResponsesCompanion toCompanion(bool nullToAbsent) {
    return CachedResponsesCompanion(
      accountId: Value(accountId),
      kind: Value(kind),
      cacheKey: Value(cacheKey),
      json: Value(json),
      rulesetVersion: rulesetVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(rulesetVersion),
      evidenceAccess: Value(evidenceAccess),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedResponse(
      accountId: serializer.fromJson<String>(json['accountId']),
      kind: serializer.fromJson<String>(json['kind']),
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      json: serializer.fromJson<String>(json['json']),
      rulesetVersion: serializer.fromJson<String?>(json['rulesetVersion']),
      evidenceAccess: serializer.fromJson<String>(json['evidenceAccess']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'kind': serializer.toJson<String>(kind),
      'cacheKey': serializer.toJson<String>(cacheKey),
      'json': serializer.toJson<String>(json),
      'rulesetVersion': serializer.toJson<String?>(rulesetVersion),
      'evidenceAccess': serializer.toJson<String>(evidenceAccess),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedResponse copyWith({
    String? accountId,
    String? kind,
    String? cacheKey,
    String? json,
    Value<String?> rulesetVersion = const Value.absent(),
    String? evidenceAccess,
    DateTime? fetchedAt,
  }) => CachedResponse(
    accountId: accountId ?? this.accountId,
    kind: kind ?? this.kind,
    cacheKey: cacheKey ?? this.cacheKey,
    json: json ?? this.json,
    rulesetVersion: rulesetVersion.present
        ? rulesetVersion.value
        : this.rulesetVersion,
    evidenceAccess: evidenceAccess ?? this.evidenceAccess,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedResponse copyWithCompanion(CachedResponsesCompanion data) {
    return CachedResponse(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      kind: data.kind.present ? data.kind.value : this.kind,
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      json: data.json.present ? data.json.value : this.json,
      rulesetVersion: data.rulesetVersion.present
          ? data.rulesetVersion.value
          : this.rulesetVersion,
      evidenceAccess: data.evidenceAccess.present
          ? data.evidenceAccess.value
          : this.evidenceAccess,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedResponse(')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('json: $json, ')
          ..write('rulesetVersion: $rulesetVersion, ')
          ..write('evidenceAccess: $evidenceAccess, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    kind,
    cacheKey,
    json,
    rulesetVersion,
    evidenceAccess,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedResponse &&
          other.accountId == this.accountId &&
          other.kind == this.kind &&
          other.cacheKey == this.cacheKey &&
          other.json == this.json &&
          other.rulesetVersion == this.rulesetVersion &&
          other.evidenceAccess == this.evidenceAccess &&
          other.fetchedAt == this.fetchedAt);
}

class CachedResponsesCompanion extends UpdateCompanion<CachedResponse> {
  final Value<String> accountId;
  final Value<String> kind;
  final Value<String> cacheKey;
  final Value<String> json;
  final Value<String?> rulesetVersion;
  final Value<String> evidenceAccess;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedResponsesCompanion({
    this.accountId = const Value.absent(),
    this.kind = const Value.absent(),
    this.cacheKey = const Value.absent(),
    this.json = const Value.absent(),
    this.rulesetVersion = const Value.absent(),
    this.evidenceAccess = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedResponsesCompanion.insert({
    required String accountId,
    required String kind,
    required String cacheKey,
    required String json,
    this.rulesetVersion = const Value.absent(),
    required String evidenceAccess,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       kind = Value(kind),
       cacheKey = Value(cacheKey),
       json = Value(json),
       evidenceAccess = Value(evidenceAccess),
       fetchedAt = Value(fetchedAt);
  static Insertable<CachedResponse> custom({
    Expression<String>? accountId,
    Expression<String>? kind,
    Expression<String>? cacheKey,
    Expression<String>? json,
    Expression<String>? rulesetVersion,
    Expression<String>? evidenceAccess,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (kind != null) 'kind': kind,
      if (cacheKey != null) 'cache_key': cacheKey,
      if (json != null) 'json': json,
      if (rulesetVersion != null) 'ruleset_version': rulesetVersion,
      if (evidenceAccess != null) 'evidence_access': evidenceAccess,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedResponsesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? kind,
    Value<String>? cacheKey,
    Value<String>? json,
    Value<String?>? rulesetVersion,
    Value<String>? evidenceAccess,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return CachedResponsesCompanion(
      accountId: accountId ?? this.accountId,
      kind: kind ?? this.kind,
      cacheKey: cacheKey ?? this.cacheKey,
      json: json ?? this.json,
      rulesetVersion: rulesetVersion ?? this.rulesetVersion,
      evidenceAccess: evidenceAccess ?? this.evidenceAccess,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rulesetVersion.present) {
      map['ruleset_version'] = Variable<String>(rulesetVersion.value);
    }
    if (evidenceAccess.present) {
      map['evidence_access'] = Variable<String>(evidenceAccess.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedResponsesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('cacheKey: $cacheKey, ')
          ..write('json: $json, ')
          ..write('rulesetVersion: $rulesetVersion, ')
          ..write('evidenceAccess: $evidenceAccess, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiaryDraftsTable extends DiaryDrafts
    with TableInfo<$DiaryDraftsTable, DiaryDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiaryDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, date, body, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryDraft> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, date};
  @override
  DiaryDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryDraft(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DiaryDraftsTable createAlias(String alias) {
    return $DiaryDraftsTable(attachedDatabase, alias);
  }
}

class DiaryDraft extends DataClass implements Insertable<DiaryDraft> {
  /// 소유 계정 id.
  final String accountId;

  /// 날짜(`YYYY-MM-DD`).
  final String date;

  /// 초안 본문.
  final String body;

  /// 마지막 저장 시각(UTC).
  final DateTime updatedAt;
  const DiaryDraft({
    required this.accountId,
    required this.date,
    required this.body,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['date'] = Variable<String>(date);
    map['body'] = Variable<String>(body);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DiaryDraftsCompanion toCompanion(bool nullToAbsent) {
    return DiaryDraftsCompanion(
      accountId: Value(accountId),
      date: Value(date),
      body: Value(body),
      updatedAt: Value(updatedAt),
    );
  }

  factory DiaryDraft.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryDraft(
      accountId: serializer.fromJson<String>(json['accountId']),
      date: serializer.fromJson<String>(json['date']),
      body: serializer.fromJson<String>(json['body']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'date': serializer.toJson<String>(date),
      'body': serializer.toJson<String>(body),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DiaryDraft copyWith({
    String? accountId,
    String? date,
    String? body,
    DateTime? updatedAt,
  }) => DiaryDraft(
    accountId: accountId ?? this.accountId,
    date: date ?? this.date,
    body: body ?? this.body,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DiaryDraft copyWithCompanion(DiaryDraftsCompanion data) {
    return DiaryDraft(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      date: data.date.present ? data.date.value : this.date,
      body: data.body.present ? data.body.value : this.body,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryDraft(')
          ..write('accountId: $accountId, ')
          ..write('date: $date, ')
          ..write('body: $body, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, date, body, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryDraft &&
          other.accountId == this.accountId &&
          other.date == this.date &&
          other.body == this.body &&
          other.updatedAt == this.updatedAt);
}

class DiaryDraftsCompanion extends UpdateCompanion<DiaryDraft> {
  final Value<String> accountId;
  final Value<String> date;
  final Value<String> body;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DiaryDraftsCompanion({
    this.accountId = const Value.absent(),
    this.date = const Value.absent(),
    this.body = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryDraftsCompanion.insert({
    required String accountId,
    required String date,
    required String body,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       date = Value(date),
       body = Value(body),
       updatedAt = Value(updatedAt);
  static Insertable<DiaryDraft> custom({
    Expression<String>? accountId,
    Expression<String>? date,
    Expression<String>? body,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (date != null) 'date': date,
      if (body != null) 'body': body,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryDraftsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? date,
    Value<String>? body,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DiaryDraftsCompanion(
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      body: body ?? this.body,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryDraftsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('date: $date, ')
          ..write('body: $body, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OnboardingInputsTable extends OnboardingInputs
    with TableInfo<$OnboardingInputsTable, OnboardingInput> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnboardingInputsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'onboarding_inputs';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnboardingInput> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OnboardingInput map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnboardingInput(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OnboardingInputsTable createAlias(String alias) {
    return $OnboardingInputsTable(attachedDatabase, alias);
  }
}

class OnboardingInput extends DataClass implements Insertable<OnboardingInput> {
  /// 항상 1입니다.
  final int id;

  /// 저장한 JSON 본문.
  final String json;

  /// 마지막 저장 시각(UTC).
  final DateTime updatedAt;
  const OnboardingInput({
    required this.id,
    required this.json,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OnboardingInputsCompanion toCompanion(bool nullToAbsent) {
    return OnboardingInputsCompanion(
      id: Value(id),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory OnboardingInput.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnboardingInput(
      id: serializer.fromJson<int>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OnboardingInput copyWith({int? id, String? json, DateTime? updatedAt}) =>
      OnboardingInput(
        id: id ?? this.id,
        json: json ?? this.json,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  OnboardingInput copyWithCompanion(OnboardingInputsCompanion data) {
    return OnboardingInput(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingInput(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnboardingInput &&
          other.id == this.id &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class OnboardingInputsCompanion extends UpdateCompanion<OnboardingInput> {
  final Value<int> id;
  final Value<String> json;
  final Value<DateTime> updatedAt;
  const OnboardingInputsCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  OnboardingInputsCompanion.insert({
    this.id = const Value.absent(),
    required String json,
    required DateTime updatedAt,
  }) : json = Value(json),
       updatedAt = Value(updatedAt);
  static Insertable<OnboardingInput> custom({
    Expression<int>? id,
    Expression<String>? json,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  OnboardingInputsCompanion copyWith({
    Value<int>? id,
    Value<String>? json,
    Value<DateTime>? updatedAt,
  }) {
    return OnboardingInputsCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingInputsCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DeviceFlagsTable extends DeviceFlags
    with TableInfo<$DeviceFlagsTable, DeviceFlag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceFlagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_flags';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceFlag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DeviceFlag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceFlag(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $DeviceFlagsTable createAlias(String alias) {
    return $DeviceFlagsTable(attachedDatabase, alias);
  }
}

class DeviceFlag extends DataClass implements Insertable<DeviceFlag> {
  /// 플래그 이름.
  final String key;

  /// 플래그 값.
  final String value;
  const DeviceFlag({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  DeviceFlagsCompanion toCompanion(bool nullToAbsent) {
    return DeviceFlagsCompanion(key: Value(key), value: Value(value));
  }

  factory DeviceFlag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceFlag(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  DeviceFlag copyWith({String? key, String? value}) =>
      DeviceFlag(key: key ?? this.key, value: value ?? this.value);
  DeviceFlag copyWithCompanion(DeviceFlagsCompanion data) {
    return DeviceFlag(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceFlag(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceFlag &&
          other.key == this.key &&
          other.value == this.value);
}

class DeviceFlagsCompanion extends UpdateCompanion<DeviceFlag> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const DeviceFlagsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceFlagsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<DeviceFlag> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceFlagsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return DeviceFlagsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceFlagsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedResponsesTable cachedResponses = $CachedResponsesTable(
    this,
  );
  late final $DiaryDraftsTable diaryDrafts = $DiaryDraftsTable(this);
  late final $OnboardingInputsTable onboardingInputs = $OnboardingInputsTable(
    this,
  );
  late final $DeviceFlagsTable deviceFlags = $DeviceFlagsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedResponses,
    diaryDrafts,
    onboardingInputs,
    deviceFlags,
  ];
}

typedef $$CachedResponsesTableCreateCompanionBuilder =
    CachedResponsesCompanion Function({
      required String accountId,
      required String kind,
      required String cacheKey,
      required String json,
      Value<String?> rulesetVersion,
      required String evidenceAccess,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$CachedResponsesTableUpdateCompanionBuilder =
    CachedResponsesCompanion Function({
      Value<String> accountId,
      Value<String> kind,
      Value<String> cacheKey,
      Value<String> json,
      Value<String?> rulesetVersion,
      Value<String> evidenceAccess,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$CachedResponsesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rulesetVersion => $composableBuilder(
    column: $table.rulesetVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceAccess => $composableBuilder(
    column: $table.evidenceAccess,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedResponsesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rulesetVersion => $composableBuilder(
    column: $table.rulesetVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceAccess => $composableBuilder(
    column: $table.evidenceAccess,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedResponsesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedResponsesTable> {
  $$CachedResponsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<String> get rulesetVersion => $composableBuilder(
    column: $table.rulesetVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceAccess => $composableBuilder(
    column: $table.evidenceAccess,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedResponsesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedResponsesTable,
          CachedResponse,
          $$CachedResponsesTableFilterComposer,
          $$CachedResponsesTableOrderingComposer,
          $$CachedResponsesTableAnnotationComposer,
          $$CachedResponsesTableCreateCompanionBuilder,
          $$CachedResponsesTableUpdateCompanionBuilder,
          (
            CachedResponse,
            BaseReferences<
              _$AppDatabase,
              $CachedResponsesTable,
              CachedResponse
            >,
          ),
          CachedResponse,
          PrefetchHooks Function()
        > {
  $$CachedResponsesTableTableManager(
    _$AppDatabase db,
    $CachedResponsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedResponsesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedResponsesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedResponsesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> cacheKey = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<String?> rulesetVersion = const Value.absent(),
                Value<String> evidenceAccess = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedResponsesCompanion(
                accountId: accountId,
                kind: kind,
                cacheKey: cacheKey,
                json: json,
                rulesetVersion: rulesetVersion,
                evidenceAccess: evidenceAccess,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String kind,
                required String cacheKey,
                required String json,
                Value<String?> rulesetVersion = const Value.absent(),
                required String evidenceAccess,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedResponsesCompanion.insert(
                accountId: accountId,
                kind: kind,
                cacheKey: cacheKey,
                json: json,
                rulesetVersion: rulesetVersion,
                evidenceAccess: evidenceAccess,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedResponsesTable, CachedResponse>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedResponsesTable,
                    CachedResponse
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedResponsesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedResponsesTable,
      CachedResponse,
      $$CachedResponsesTableFilterComposer,
      $$CachedResponsesTableOrderingComposer,
      $$CachedResponsesTableAnnotationComposer,
      $$CachedResponsesTableCreateCompanionBuilder,
      $$CachedResponsesTableUpdateCompanionBuilder,
      (
        CachedResponse,
        BaseReferences<_$AppDatabase, $CachedResponsesTable, CachedResponse>,
      ),
      CachedResponse,
      PrefetchHooks Function()
    >;
typedef $$DiaryDraftsTableCreateCompanionBuilder =
    DiaryDraftsCompanion Function({
      required String accountId,
      required String date,
      required String body,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DiaryDraftsTableUpdateCompanionBuilder =
    DiaryDraftsCompanion Function({
      Value<String> accountId,
      Value<String> date,
      Value<String> body,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DiaryDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $DiaryDraftsTable> {
  $$DiaryDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiaryDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiaryDraftsTable> {
  $$DiaryDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiaryDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiaryDraftsTable> {
  $$DiaryDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DiaryDraftsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiaryDraftsTable,
          DiaryDraft,
          $$DiaryDraftsTableFilterComposer,
          $$DiaryDraftsTableOrderingComposer,
          $$DiaryDraftsTableAnnotationComposer,
          $$DiaryDraftsTableCreateCompanionBuilder,
          $$DiaryDraftsTableUpdateCompanionBuilder,
          (
            DiaryDraft,
            BaseReferences<_$AppDatabase, $DiaryDraftsTable, DiaryDraft>,
          ),
          DiaryDraft,
          PrefetchHooks Function()
        > {
  $$DiaryDraftsTableTableManager(_$AppDatabase db, $DiaryDraftsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiaryDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiaryDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiaryDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryDraftsCompanion(
                accountId: accountId,
                date: date,
                body: body,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String date,
                required String body,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DiaryDraftsCompanion.insert(
                accountId: accountId,
                date: date,
                body: body,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DiaryDraftsTable, DiaryDraft>(table),
                  BaseReferences<_$AppDatabase, $DiaryDraftsTable, DiaryDraft>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiaryDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiaryDraftsTable,
      DiaryDraft,
      $$DiaryDraftsTableFilterComposer,
      $$DiaryDraftsTableOrderingComposer,
      $$DiaryDraftsTableAnnotationComposer,
      $$DiaryDraftsTableCreateCompanionBuilder,
      $$DiaryDraftsTableUpdateCompanionBuilder,
      (
        DiaryDraft,
        BaseReferences<_$AppDatabase, $DiaryDraftsTable, DiaryDraft>,
      ),
      DiaryDraft,
      PrefetchHooks Function()
    >;
typedef $$OnboardingInputsTableCreateCompanionBuilder =
    OnboardingInputsCompanion Function({
      Value<int> id,
      required String json,
      required DateTime updatedAt,
    });
typedef $$OnboardingInputsTableUpdateCompanionBuilder =
    OnboardingInputsCompanion Function({
      Value<int> id,
      Value<String> json,
      Value<DateTime> updatedAt,
    });

class $$OnboardingInputsTableFilterComposer
    extends Composer<_$AppDatabase, $OnboardingInputsTable> {
  $$OnboardingInputsTableFilterComposer({
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

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnboardingInputsTableOrderingComposer
    extends Composer<_$AppDatabase, $OnboardingInputsTable> {
  $$OnboardingInputsTableOrderingComposer({
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

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnboardingInputsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnboardingInputsTable> {
  $$OnboardingInputsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OnboardingInputsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OnboardingInputsTable,
          OnboardingInput,
          $$OnboardingInputsTableFilterComposer,
          $$OnboardingInputsTableOrderingComposer,
          $$OnboardingInputsTableAnnotationComposer,
          $$OnboardingInputsTableCreateCompanionBuilder,
          $$OnboardingInputsTableUpdateCompanionBuilder,
          (
            OnboardingInput,
            BaseReferences<
              _$AppDatabase,
              $OnboardingInputsTable,
              OnboardingInput
            >,
          ),
          OnboardingInput,
          PrefetchHooks Function()
        > {
  $$OnboardingInputsTableTableManager(
    _$AppDatabase db,
    $OnboardingInputsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnboardingInputsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OnboardingInputsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OnboardingInputsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => OnboardingInputsCompanion(
                id: id,
                json: json,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String json,
                required DateTime updatedAt,
              }) => OnboardingInputsCompanion.insert(
                id: id,
                json: json,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OnboardingInputsTable, OnboardingInput>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OnboardingInputsTable,
                    OnboardingInput
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnboardingInputsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OnboardingInputsTable,
      OnboardingInput,
      $$OnboardingInputsTableFilterComposer,
      $$OnboardingInputsTableOrderingComposer,
      $$OnboardingInputsTableAnnotationComposer,
      $$OnboardingInputsTableCreateCompanionBuilder,
      $$OnboardingInputsTableUpdateCompanionBuilder,
      (
        OnboardingInput,
        BaseReferences<_$AppDatabase, $OnboardingInputsTable, OnboardingInput>,
      ),
      OnboardingInput,
      PrefetchHooks Function()
    >;
typedef $$DeviceFlagsTableCreateCompanionBuilder =
    DeviceFlagsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$DeviceFlagsTableUpdateCompanionBuilder =
    DeviceFlagsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$DeviceFlagsTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceFlagsTable> {
  $$DeviceFlagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceFlagsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceFlagsTable> {
  $$DeviceFlagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceFlagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceFlagsTable> {
  $$DeviceFlagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$DeviceFlagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeviceFlagsTable,
          DeviceFlag,
          $$DeviceFlagsTableFilterComposer,
          $$DeviceFlagsTableOrderingComposer,
          $$DeviceFlagsTableAnnotationComposer,
          $$DeviceFlagsTableCreateCompanionBuilder,
          $$DeviceFlagsTableUpdateCompanionBuilder,
          (
            DeviceFlag,
            BaseReferences<_$AppDatabase, $DeviceFlagsTable, DeviceFlag>,
          ),
          DeviceFlag,
          PrefetchHooks Function()
        > {
  $$DeviceFlagsTableTableManager(_$AppDatabase db, $DeviceFlagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceFlagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceFlagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceFlagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DeviceFlagsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => DeviceFlagsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeviceFlagsTable, DeviceFlag>(table),
                  BaseReferences<_$AppDatabase, $DeviceFlagsTable, DeviceFlag>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceFlagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeviceFlagsTable,
      DeviceFlag,
      $$DeviceFlagsTableFilterComposer,
      $$DeviceFlagsTableOrderingComposer,
      $$DeviceFlagsTableAnnotationComposer,
      $$DeviceFlagsTableCreateCompanionBuilder,
      $$DeviceFlagsTableUpdateCompanionBuilder,
      (
        DeviceFlag,
        BaseReferences<_$AppDatabase, $DeviceFlagsTable, DeviceFlag>,
      ),
      DeviceFlag,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedResponsesTableTableManager get cachedResponses =>
      $$CachedResponsesTableTableManager(_db, _db.cachedResponses);
  $$DiaryDraftsTableTableManager get diaryDrafts =>
      $$DiaryDraftsTableTableManager(_db, _db.diaryDrafts);
  $$OnboardingInputsTableTableManager get onboardingInputs =>
      $$OnboardingInputsTableTableManager(_db, _db.onboardingInputs);
  $$DeviceFlagsTableTableManager get deviceFlags =>
      $$DeviceFlagsTableTableManager(_db, _db.deviceFlags);
}
