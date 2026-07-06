// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PKR'),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawTextMeta = const VerificationMeta(
    'rawText',
  );
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
    'raw_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linkedSourcesMeta = const VerificationMeta(
    'linkedSources',
  );
  @override
  late final GeneratedColumn<String> linkedSources = GeneratedColumn<String>(
    'linked_sources',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    amount,
    currency,
    type,
    merchant,
    category,
    occurredAt,
    source,
    rawText,
    confidence,
    status,
    fingerprint,
    linkedSources,
    description,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    } else if (isInserting) {
      context.missing(_merchantMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('raw_text')) {
      context.handle(
        _rawTextMeta,
        rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('linked_sources')) {
      context.handle(
        _linkedSourcesMeta,
        linkedSources.isAcceptableOrUnknown(
          data['linked_sources']!,
          _linkedSourcesMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      rawText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_text'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      linkedSources: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_sources'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final double amount;
  final String currency;
  final String type;
  final String merchant;
  final String category;
  final DateTime occurredAt;
  final String source;
  final String? rawText;
  final double confidence;
  final String status;
  final String fingerprint;
  final String linkedSources;
  final String? description;
  const Transaction({
    required this.id,
    required this.amount,
    required this.currency,
    required this.type,
    required this.merchant,
    required this.category,
    required this.occurredAt,
    required this.source,
    this.rawText,
    required this.confidence,
    required this.status,
    required this.fingerprint,
    required this.linkedSources,
    this.description,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['amount'] = Variable<double>(amount);
    map['currency'] = Variable<String>(currency);
    map['type'] = Variable<String>(type);
    map['merchant'] = Variable<String>(merchant);
    map['category'] = Variable<String>(category);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || rawText != null) {
      map['raw_text'] = Variable<String>(rawText);
    }
    map['confidence'] = Variable<double>(confidence);
    map['status'] = Variable<String>(status);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['linked_sources'] = Variable<String>(linkedSources);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      amount: Value(amount),
      currency: Value(currency),
      type: Value(type),
      merchant: Value(merchant),
      category: Value(category),
      occurredAt: Value(occurredAt),
      source: Value(source),
      rawText: rawText == null && nullToAbsent
          ? const Value.absent()
          : Value(rawText),
      confidence: Value(confidence),
      status: Value(status),
      fingerprint: Value(fingerprint),
      linkedSources: Value(linkedSources),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      amount: serializer.fromJson<double>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      type: serializer.fromJson<String>(json['type']),
      merchant: serializer.fromJson<String>(json['merchant']),
      category: serializer.fromJson<String>(json['category']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      source: serializer.fromJson<String>(json['source']),
      rawText: serializer.fromJson<String?>(json['rawText']),
      confidence: serializer.fromJson<double>(json['confidence']),
      status: serializer.fromJson<String>(json['status']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      linkedSources: serializer.fromJson<String>(json['linkedSources']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'amount': serializer.toJson<double>(amount),
      'currency': serializer.toJson<String>(currency),
      'type': serializer.toJson<String>(type),
      'merchant': serializer.toJson<String>(merchant),
      'category': serializer.toJson<String>(category),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'source': serializer.toJson<String>(source),
      'rawText': serializer.toJson<String?>(rawText),
      'confidence': serializer.toJson<double>(confidence),
      'status': serializer.toJson<String>(status),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'linkedSources': serializer.toJson<String>(linkedSources),
      'description': serializer.toJson<String?>(description),
    };
  }

  Transaction copyWith({
    String? id,
    double? amount,
    String? currency,
    String? type,
    String? merchant,
    String? category,
    DateTime? occurredAt,
    String? source,
    Value<String?> rawText = const Value.absent(),
    double? confidence,
    String? status,
    String? fingerprint,
    String? linkedSources,
    Value<String?> description = const Value.absent(),
  }) => Transaction(
    id: id ?? this.id,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    type: type ?? this.type,
    merchant: merchant ?? this.merchant,
    category: category ?? this.category,
    occurredAt: occurredAt ?? this.occurredAt,
    source: source ?? this.source,
    rawText: rawText.present ? rawText.value : this.rawText,
    confidence: confidence ?? this.confidence,
    status: status ?? this.status,
    fingerprint: fingerprint ?? this.fingerprint,
    linkedSources: linkedSources ?? this.linkedSources,
    description: description.present ? description.value : this.description,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      type: data.type.present ? data.type.value : this.type,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      category: data.category.present ? data.category.value : this.category,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      source: data.source.present ? data.source.value : this.source,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      status: data.status.present ? data.status.value : this.status,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      linkedSources: data.linkedSources.present
          ? data.linkedSources.value
          : this.linkedSources,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('type: $type, ')
          ..write('merchant: $merchant, ')
          ..write('category: $category, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('source: $source, ')
          ..write('rawText: $rawText, ')
          ..write('confidence: $confidence, ')
          ..write('status: $status, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('linkedSources: $linkedSources, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    amount,
    currency,
    type,
    merchant,
    category,
    occurredAt,
    source,
    rawText,
    confidence,
    status,
    fingerprint,
    linkedSources,
    description,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.type == this.type &&
          other.merchant == this.merchant &&
          other.category == this.category &&
          other.occurredAt == this.occurredAt &&
          other.source == this.source &&
          other.rawText == this.rawText &&
          other.confidence == this.confidence &&
          other.status == this.status &&
          other.fingerprint == this.fingerprint &&
          other.linkedSources == this.linkedSources &&
          other.description == this.description);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<double> amount;
  final Value<String> currency;
  final Value<String> type;
  final Value<String> merchant;
  final Value<String> category;
  final Value<DateTime> occurredAt;
  final Value<String> source;
  final Value<String?> rawText;
  final Value<double> confidence;
  final Value<String> status;
  final Value<String> fingerprint;
  final Value<String> linkedSources;
  final Value<String?> description;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.type = const Value.absent(),
    this.merchant = const Value.absent(),
    this.category = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.source = const Value.absent(),
    this.rawText = const Value.absent(),
    this.confidence = const Value.absent(),
    this.status = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.linkedSources = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required double amount,
    this.currency = const Value.absent(),
    required String type,
    required String merchant,
    required String category,
    required DateTime occurredAt,
    required String source,
    this.rawText = const Value.absent(),
    this.confidence = const Value.absent(),
    required String status,
    required String fingerprint,
    this.linkedSources = const Value.absent(),
    this.description = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       amount = Value(amount),
       type = Value(type),
       merchant = Value(merchant),
       category = Value(category),
       occurredAt = Value(occurredAt),
       source = Value(source),
       status = Value(status),
       fingerprint = Value(fingerprint);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<double>? amount,
    Expression<String>? currency,
    Expression<String>? type,
    Expression<String>? merchant,
    Expression<String>? category,
    Expression<DateTime>? occurredAt,
    Expression<String>? source,
    Expression<String>? rawText,
    Expression<double>? confidence,
    Expression<String>? status,
    Expression<String>? fingerprint,
    Expression<String>? linkedSources,
    Expression<String>? description,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (type != null) 'type': type,
      if (merchant != null) 'merchant': merchant,
      if (category != null) 'category': category,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (source != null) 'source': source,
      if (rawText != null) 'raw_text': rawText,
      if (confidence != null) 'confidence': confidence,
      if (status != null) 'status': status,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (linkedSources != null) 'linked_sources': linkedSources,
      if (description != null) 'description': description,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<double>? amount,
    Value<String>? currency,
    Value<String>? type,
    Value<String>? merchant,
    Value<String>? category,
    Value<DateTime>? occurredAt,
    Value<String>? source,
    Value<String?>? rawText,
    Value<double>? confidence,
    Value<String>? status,
    Value<String>? fingerprint,
    Value<String>? linkedSources,
    Value<String?>? description,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      occurredAt: occurredAt ?? this.occurredAt,
      source: source ?? this.source,
      rawText: rawText ?? this.rawText,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      fingerprint: fingerprint ?? this.fingerprint,
      linkedSources: linkedSources ?? this.linkedSources,
      description: description ?? this.description,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (linkedSources.present) {
      map['linked_sources'] = Variable<String>(linkedSources.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('type: $type, ')
          ..write('merchant: $merchant, ')
          ..write('category: $category, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('source: $source, ')
          ..write('rawText: $rawText, ')
          ..write('confidence: $confidence, ')
          ..write('status: $status, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('linkedSources: $linkedSources, ')
          ..write('description: $description, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MonthlySummariesTable extends MonthlySummaries
    with TableInfo<$MonthlySummariesTable, MonthlySummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonthlySummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _yearMonthMeta = const VerificationMeta(
    'yearMonth',
  );
  @override
  late final GeneratedColumn<String> yearMonth = GeneratedColumn<String>(
    'year_month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalDebitMeta = const VerificationMeta(
    'totalDebit',
  );
  @override
  late final GeneratedColumn<double> totalDebit = GeneratedColumn<double>(
    'total_debit',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCreditMeta = const VerificationMeta(
    'totalCredit',
  );
  @override
  late final GeneratedColumn<double> totalCredit = GeneratedColumn<double>(
    'total_credit',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byCategoryJsonMeta = const VerificationMeta(
    'byCategoryJson',
  );
  @override
  late final GeneratedColumn<String> byCategoryJson = GeneratedColumn<String>(
    'by_category_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionCountMeta = const VerificationMeta(
    'transactionCount',
  );
  @override
  late final GeneratedColumn<int> transactionCount = GeneratedColumn<int>(
    'transaction_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  List<GeneratedColumn> get $columns => [
    yearMonth,
    totalDebit,
    totalCredit,
    byCategoryJson,
    transactionCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'monthly_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MonthlySummary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('year_month')) {
      context.handle(
        _yearMonthMeta,
        yearMonth.isAcceptableOrUnknown(data['year_month']!, _yearMonthMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMonthMeta);
    }
    if (data.containsKey('total_debit')) {
      context.handle(
        _totalDebitMeta,
        totalDebit.isAcceptableOrUnknown(data['total_debit']!, _totalDebitMeta),
      );
    } else if (isInserting) {
      context.missing(_totalDebitMeta);
    }
    if (data.containsKey('total_credit')) {
      context.handle(
        _totalCreditMeta,
        totalCredit.isAcceptableOrUnknown(
          data['total_credit']!,
          _totalCreditMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalCreditMeta);
    }
    if (data.containsKey('by_category_json')) {
      context.handle(
        _byCategoryJsonMeta,
        byCategoryJson.isAcceptableOrUnknown(
          data['by_category_json']!,
          _byCategoryJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_byCategoryJsonMeta);
    }
    if (data.containsKey('transaction_count')) {
      context.handle(
        _transactionCountMeta,
        transactionCount.isAcceptableOrUnknown(
          data['transaction_count']!,
          _transactionCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionCountMeta);
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
  Set<GeneratedColumn> get $primaryKey => {yearMonth};
  @override
  MonthlySummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonthlySummary(
      yearMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}year_month'],
      )!,
      totalDebit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_debit'],
      )!,
      totalCredit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_credit'],
      )!,
      byCategoryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_category_json'],
      )!,
      transactionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaction_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MonthlySummariesTable createAlias(String alias) {
    return $MonthlySummariesTable(attachedDatabase, alias);
  }
}

class MonthlySummary extends DataClass implements Insertable<MonthlySummary> {
  final String yearMonth;
  final double totalDebit;
  final double totalCredit;
  final String byCategoryJson;
  final int transactionCount;
  final DateTime updatedAt;
  const MonthlySummary({
    required this.yearMonth,
    required this.totalDebit,
    required this.totalCredit,
    required this.byCategoryJson,
    required this.transactionCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['year_month'] = Variable<String>(yearMonth);
    map['total_debit'] = Variable<double>(totalDebit);
    map['total_credit'] = Variable<double>(totalCredit);
    map['by_category_json'] = Variable<String>(byCategoryJson);
    map['transaction_count'] = Variable<int>(transactionCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MonthlySummariesCompanion toCompanion(bool nullToAbsent) {
    return MonthlySummariesCompanion(
      yearMonth: Value(yearMonth),
      totalDebit: Value(totalDebit),
      totalCredit: Value(totalCredit),
      byCategoryJson: Value(byCategoryJson),
      transactionCount: Value(transactionCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory MonthlySummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonthlySummary(
      yearMonth: serializer.fromJson<String>(json['yearMonth']),
      totalDebit: serializer.fromJson<double>(json['totalDebit']),
      totalCredit: serializer.fromJson<double>(json['totalCredit']),
      byCategoryJson: serializer.fromJson<String>(json['byCategoryJson']),
      transactionCount: serializer.fromJson<int>(json['transactionCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'yearMonth': serializer.toJson<String>(yearMonth),
      'totalDebit': serializer.toJson<double>(totalDebit),
      'totalCredit': serializer.toJson<double>(totalCredit),
      'byCategoryJson': serializer.toJson<String>(byCategoryJson),
      'transactionCount': serializer.toJson<int>(transactionCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MonthlySummary copyWith({
    String? yearMonth,
    double? totalDebit,
    double? totalCredit,
    String? byCategoryJson,
    int? transactionCount,
    DateTime? updatedAt,
  }) => MonthlySummary(
    yearMonth: yearMonth ?? this.yearMonth,
    totalDebit: totalDebit ?? this.totalDebit,
    totalCredit: totalCredit ?? this.totalCredit,
    byCategoryJson: byCategoryJson ?? this.byCategoryJson,
    transactionCount: transactionCount ?? this.transactionCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MonthlySummary copyWithCompanion(MonthlySummariesCompanion data) {
    return MonthlySummary(
      yearMonth: data.yearMonth.present ? data.yearMonth.value : this.yearMonth,
      totalDebit: data.totalDebit.present
          ? data.totalDebit.value
          : this.totalDebit,
      totalCredit: data.totalCredit.present
          ? data.totalCredit.value
          : this.totalCredit,
      byCategoryJson: data.byCategoryJson.present
          ? data.byCategoryJson.value
          : this.byCategoryJson,
      transactionCount: data.transactionCount.present
          ? data.transactionCount.value
          : this.transactionCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonthlySummary(')
          ..write('yearMonth: $yearMonth, ')
          ..write('totalDebit: $totalDebit, ')
          ..write('totalCredit: $totalCredit, ')
          ..write('byCategoryJson: $byCategoryJson, ')
          ..write('transactionCount: $transactionCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    yearMonth,
    totalDebit,
    totalCredit,
    byCategoryJson,
    transactionCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthlySummary &&
          other.yearMonth == this.yearMonth &&
          other.totalDebit == this.totalDebit &&
          other.totalCredit == this.totalCredit &&
          other.byCategoryJson == this.byCategoryJson &&
          other.transactionCount == this.transactionCount &&
          other.updatedAt == this.updatedAt);
}

class MonthlySummariesCompanion extends UpdateCompanion<MonthlySummary> {
  final Value<String> yearMonth;
  final Value<double> totalDebit;
  final Value<double> totalCredit;
  final Value<String> byCategoryJson;
  final Value<int> transactionCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MonthlySummariesCompanion({
    this.yearMonth = const Value.absent(),
    this.totalDebit = const Value.absent(),
    this.totalCredit = const Value.absent(),
    this.byCategoryJson = const Value.absent(),
    this.transactionCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MonthlySummariesCompanion.insert({
    required String yearMonth,
    required double totalDebit,
    required double totalCredit,
    required String byCategoryJson,
    required int transactionCount,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : yearMonth = Value(yearMonth),
       totalDebit = Value(totalDebit),
       totalCredit = Value(totalCredit),
       byCategoryJson = Value(byCategoryJson),
       transactionCount = Value(transactionCount),
       updatedAt = Value(updatedAt);
  static Insertable<MonthlySummary> custom({
    Expression<String>? yearMonth,
    Expression<double>? totalDebit,
    Expression<double>? totalCredit,
    Expression<String>? byCategoryJson,
    Expression<int>? transactionCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (yearMonth != null) 'year_month': yearMonth,
      if (totalDebit != null) 'total_debit': totalDebit,
      if (totalCredit != null) 'total_credit': totalCredit,
      if (byCategoryJson != null) 'by_category_json': byCategoryJson,
      if (transactionCount != null) 'transaction_count': transactionCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MonthlySummariesCompanion copyWith({
    Value<String>? yearMonth,
    Value<double>? totalDebit,
    Value<double>? totalCredit,
    Value<String>? byCategoryJson,
    Value<int>? transactionCount,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MonthlySummariesCompanion(
      yearMonth: yearMonth ?? this.yearMonth,
      totalDebit: totalDebit ?? this.totalDebit,
      totalCredit: totalCredit ?? this.totalCredit,
      byCategoryJson: byCategoryJson ?? this.byCategoryJson,
      transactionCount: transactionCount ?? this.transactionCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (yearMonth.present) {
      map['year_month'] = Variable<String>(yearMonth.value);
    }
    if (totalDebit.present) {
      map['total_debit'] = Variable<double>(totalDebit.value);
    }
    if (totalCredit.present) {
      map['total_credit'] = Variable<double>(totalCredit.value);
    }
    if (byCategoryJson.present) {
      map['by_category_json'] = Variable<String>(byCategoryJson.value);
    }
    if (transactionCount.present) {
      map['transaction_count'] = Variable<int>(transactionCount.value);
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
    return (StringBuffer('MonthlySummariesCompanion(')
          ..write('yearMonth: $yearMonth, ')
          ..write('totalDebit: $totalDebit, ')
          ..write('totalCredit: $totalCredit, ')
          ..write('byCategoryJson: $byCategoryJson, ')
          ..write('transactionCount: $transactionCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ParserRulesTable extends ParserRules
    with TableInfo<$ParserRulesTable, ParserRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParserRulesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patternMeta = const VerificationMeta(
    'pattern',
  );
  @override
  late final GeneratedColumn<String> pattern = GeneratedColumn<String>(
    'pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceHintMeta = const VerificationMeta(
    'sourceHint',
  );
  @override
  late final GeneratedColumn<String> sourceHint = GeneratedColumn<String>(
    'source_hint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    pattern,
    sourceHint,
    enabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parser_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<ParserRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pattern')) {
      context.handle(
        _patternMeta,
        pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta),
      );
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('source_hint')) {
      context.handle(
        _sourceHintMeta,
        sourceHint.isAcceptableOrUnknown(data['source_hint']!, _sourceHintMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ParserRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParserRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      pattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern'],
      )!,
      sourceHint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_hint'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $ParserRulesTable createAlias(String alias) {
    return $ParserRulesTable(attachedDatabase, alias);
  }
}

class ParserRule extends DataClass implements Insertable<ParserRule> {
  final int id;
  final String name;
  final String pattern;
  final String? sourceHint;
  final bool enabled;
  const ParserRule({
    required this.id,
    required this.name,
    required this.pattern,
    this.sourceHint,
    required this.enabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['pattern'] = Variable<String>(pattern);
    if (!nullToAbsent || sourceHint != null) {
      map['source_hint'] = Variable<String>(sourceHint);
    }
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  ParserRulesCompanion toCompanion(bool nullToAbsent) {
    return ParserRulesCompanion(
      id: Value(id),
      name: Value(name),
      pattern: Value(pattern),
      sourceHint: sourceHint == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceHint),
      enabled: Value(enabled),
    );
  }

  factory ParserRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParserRule(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      pattern: serializer.fromJson<String>(json['pattern']),
      sourceHint: serializer.fromJson<String?>(json['sourceHint']),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'pattern': serializer.toJson<String>(pattern),
      'sourceHint': serializer.toJson<String?>(sourceHint),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  ParserRule copyWith({
    int? id,
    String? name,
    String? pattern,
    Value<String?> sourceHint = const Value.absent(),
    bool? enabled,
  }) => ParserRule(
    id: id ?? this.id,
    name: name ?? this.name,
    pattern: pattern ?? this.pattern,
    sourceHint: sourceHint.present ? sourceHint.value : this.sourceHint,
    enabled: enabled ?? this.enabled,
  );
  ParserRule copyWithCompanion(ParserRulesCompanion data) {
    return ParserRule(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      pattern: data.pattern.present ? data.pattern.value : this.pattern,
      sourceHint: data.sourceHint.present
          ? data.sourceHint.value
          : this.sourceHint,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParserRule(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pattern: $pattern, ')
          ..write('sourceHint: $sourceHint, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, pattern, sourceHint, enabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParserRule &&
          other.id == this.id &&
          other.name == this.name &&
          other.pattern == this.pattern &&
          other.sourceHint == this.sourceHint &&
          other.enabled == this.enabled);
}

class ParserRulesCompanion extends UpdateCompanion<ParserRule> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> pattern;
  final Value<String?> sourceHint;
  final Value<bool> enabled;
  const ParserRulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.pattern = const Value.absent(),
    this.sourceHint = const Value.absent(),
    this.enabled = const Value.absent(),
  });
  ParserRulesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String pattern,
    this.sourceHint = const Value.absent(),
    this.enabled = const Value.absent(),
  }) : name = Value(name),
       pattern = Value(pattern);
  static Insertable<ParserRule> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? pattern,
    Expression<String>? sourceHint,
    Expression<bool>? enabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (pattern != null) 'pattern': pattern,
      if (sourceHint != null) 'source_hint': sourceHint,
      if (enabled != null) 'enabled': enabled,
    });
  }

  ParserRulesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? pattern,
    Value<String?>? sourceHint,
    Value<bool>? enabled,
  }) {
    return ParserRulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      sourceHint: sourceHint ?? this.sourceHint,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<String>(pattern.value);
    }
    if (sourceHint.present) {
      map['source_hint'] = Variable<String>(sourceHint.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParserRulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pattern: $pattern, ')
          ..write('sourceHint: $sourceHint, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataData> instance, {
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
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
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
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String key;
  final String value;
  const SyncMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
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

  SyncMetadataData copyWith({String? key, String? value}) =>
      SyncMetadataData(key: key ?? this.key, value: value ?? this.value);
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
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
      (other is SyncMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetadataData> custom({
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

  SyncMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetadataCompanion(
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
    return (StringBuffer('SyncMetadataCompanion(')
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
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $MonthlySummariesTable monthlySummaries = $MonthlySummariesTable(
    this,
  );
  late final $ParserRulesTable parserRules = $ParserRulesTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    transactions,
    monthlySummaries,
    parserRules,
    syncMetadata,
  ];
}

typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required double amount,
      Value<String> currency,
      required String type,
      required String merchant,
      required String category,
      required DateTime occurredAt,
      required String source,
      Value<String?> rawText,
      Value<double> confidence,
      required String status,
      required String fingerprint,
      Value<String> linkedSources,
      Value<String?> description,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<double> amount,
      Value<String> currency,
      Value<String> type,
      Value<String> merchant,
      Value<String> category,
      Value<DateTime> occurredAt,
      Value<String> source,
      Value<String?> rawText,
      Value<double> confidence,
      Value<String> status,
      Value<String> fingerprint,
      Value<String> linkedSources,
      Value<String?> description,
      Value<int> rowid,
    });

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedSources => $composableBuilder(
    column: $table.linkedSources,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedSources => $composableBuilder(
    column: $table.linkedSources,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedSources => $composableBuilder(
    column: $table.linkedSources,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (
            Transaction,
            BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>,
          ),
          Transaction,
          PrefetchHooks Function()
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> merchant = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> rawText = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String> linkedSources = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                amount: amount,
                currency: currency,
                type: type,
                merchant: merchant,
                category: category,
                occurredAt: occurredAt,
                source: source,
                rawText: rawText,
                confidence: confidence,
                status: status,
                fingerprint: fingerprint,
                linkedSources: linkedSources,
                description: description,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required double amount,
                Value<String> currency = const Value.absent(),
                required String type,
                required String merchant,
                required String category,
                required DateTime occurredAt,
                required String source,
                Value<String?> rawText = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                required String status,
                required String fingerprint,
                Value<String> linkedSources = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                amount: amount,
                currency: currency,
                type: type,
                merchant: merchant,
                category: category,
                occurredAt: occurredAt,
                source: source,
                rawText: rawText,
                confidence: confidence,
                status: status,
                fingerprint: fingerprint,
                linkedSources: linkedSources,
                description: description,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (
        Transaction,
        BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>,
      ),
      Transaction,
      PrefetchHooks Function()
    >;
typedef $$MonthlySummariesTableCreateCompanionBuilder =
    MonthlySummariesCompanion Function({
      required String yearMonth,
      required double totalDebit,
      required double totalCredit,
      required String byCategoryJson,
      required int transactionCount,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MonthlySummariesTableUpdateCompanionBuilder =
    MonthlySummariesCompanion Function({
      Value<String> yearMonth,
      Value<double> totalDebit,
      Value<double> totalCredit,
      Value<String> byCategoryJson,
      Value<int> transactionCount,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MonthlySummariesTableFilterComposer
    extends Composer<_$AppDatabase, $MonthlySummariesTable> {
  $$MonthlySummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get yearMonth => $composableBuilder(
    column: $table.yearMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalDebit => $composableBuilder(
    column: $table.totalDebit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalCredit => $composableBuilder(
    column: $table.totalCredit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get byCategoryJson => $composableBuilder(
    column: $table.byCategoryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transactionCount => $composableBuilder(
    column: $table.transactionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MonthlySummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $MonthlySummariesTable> {
  $$MonthlySummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get yearMonth => $composableBuilder(
    column: $table.yearMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalDebit => $composableBuilder(
    column: $table.totalDebit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalCredit => $composableBuilder(
    column: $table.totalCredit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get byCategoryJson => $composableBuilder(
    column: $table.byCategoryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transactionCount => $composableBuilder(
    column: $table.transactionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MonthlySummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MonthlySummariesTable> {
  $$MonthlySummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get yearMonth =>
      $composableBuilder(column: $table.yearMonth, builder: (column) => column);

  GeneratedColumn<double> get totalDebit => $composableBuilder(
    column: $table.totalDebit,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalCredit => $composableBuilder(
    column: $table.totalCredit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get byCategoryJson => $composableBuilder(
    column: $table.byCategoryJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get transactionCount => $composableBuilder(
    column: $table.transactionCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MonthlySummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MonthlySummariesTable,
          MonthlySummary,
          $$MonthlySummariesTableFilterComposer,
          $$MonthlySummariesTableOrderingComposer,
          $$MonthlySummariesTableAnnotationComposer,
          $$MonthlySummariesTableCreateCompanionBuilder,
          $$MonthlySummariesTableUpdateCompanionBuilder,
          (
            MonthlySummary,
            BaseReferences<
              _$AppDatabase,
              $MonthlySummariesTable,
              MonthlySummary
            >,
          ),
          MonthlySummary,
          PrefetchHooks Function()
        > {
  $$MonthlySummariesTableTableManager(
    _$AppDatabase db,
    $MonthlySummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonthlySummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MonthlySummariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MonthlySummariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> yearMonth = const Value.absent(),
                Value<double> totalDebit = const Value.absent(),
                Value<double> totalCredit = const Value.absent(),
                Value<String> byCategoryJson = const Value.absent(),
                Value<int> transactionCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthlySummariesCompanion(
                yearMonth: yearMonth,
                totalDebit: totalDebit,
                totalCredit: totalCredit,
                byCategoryJson: byCategoryJson,
                transactionCount: transactionCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String yearMonth,
                required double totalDebit,
                required double totalCredit,
                required String byCategoryJson,
                required int transactionCount,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MonthlySummariesCompanion.insert(
                yearMonth: yearMonth,
                totalDebit: totalDebit,
                totalCredit: totalCredit,
                byCategoryJson: byCategoryJson,
                transactionCount: transactionCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MonthlySummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MonthlySummariesTable,
      MonthlySummary,
      $$MonthlySummariesTableFilterComposer,
      $$MonthlySummariesTableOrderingComposer,
      $$MonthlySummariesTableAnnotationComposer,
      $$MonthlySummariesTableCreateCompanionBuilder,
      $$MonthlySummariesTableUpdateCompanionBuilder,
      (
        MonthlySummary,
        BaseReferences<_$AppDatabase, $MonthlySummariesTable, MonthlySummary>,
      ),
      MonthlySummary,
      PrefetchHooks Function()
    >;
typedef $$ParserRulesTableCreateCompanionBuilder =
    ParserRulesCompanion Function({
      Value<int> id,
      required String name,
      required String pattern,
      Value<String?> sourceHint,
      Value<bool> enabled,
    });
typedef $$ParserRulesTableUpdateCompanionBuilder =
    ParserRulesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> pattern,
      Value<String?> sourceHint,
      Value<bool> enabled,
    });

class $$ParserRulesTableFilterComposer
    extends Composer<_$AppDatabase, $ParserRulesTable> {
  $$ParserRulesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceHint => $composableBuilder(
    column: $table.sourceHint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ParserRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $ParserRulesTable> {
  $$ParserRulesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pattern => $composableBuilder(
    column: $table.pattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceHint => $composableBuilder(
    column: $table.sourceHint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParserRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParserRulesTable> {
  $$ParserRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get pattern =>
      $composableBuilder(column: $table.pattern, builder: (column) => column);

  GeneratedColumn<String> get sourceHint => $composableBuilder(
    column: $table.sourceHint,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);
}

class $$ParserRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParserRulesTable,
          ParserRule,
          $$ParserRulesTableFilterComposer,
          $$ParserRulesTableOrderingComposer,
          $$ParserRulesTableAnnotationComposer,
          $$ParserRulesTableCreateCompanionBuilder,
          $$ParserRulesTableUpdateCompanionBuilder,
          (
            ParserRule,
            BaseReferences<_$AppDatabase, $ParserRulesTable, ParserRule>,
          ),
          ParserRule,
          PrefetchHooks Function()
        > {
  $$ParserRulesTableTableManager(_$AppDatabase db, $ParserRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParserRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParserRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParserRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> pattern = const Value.absent(),
                Value<String?> sourceHint = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
              }) => ParserRulesCompanion(
                id: id,
                name: name,
                pattern: pattern,
                sourceHint: sourceHint,
                enabled: enabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String pattern,
                Value<String?> sourceHint = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
              }) => ParserRulesCompanion.insert(
                id: id,
                name: name,
                pattern: pattern,
                sourceHint: sourceHint,
                enabled: enabled,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ParserRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParserRulesTable,
      ParserRule,
      $$ParserRulesTableFilterComposer,
      $$ParserRulesTableOrderingComposer,
      $$ParserRulesTableAnnotationComposer,
      $$ParserRulesTableCreateCompanionBuilder,
      $$ParserRulesTableUpdateCompanionBuilder,
      (
        ParserRule,
        BaseReferences<_$AppDatabase, $ParserRulesTable, ParserRule>,
      ),
      ParserRule,
      PrefetchHooks Function()
    >;
typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
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

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
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

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
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

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetadataTable,
          SyncMetadataData,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableAnnotationComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder,
          (
            SyncMetadataData,
            BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
          ),
          SyncMetadataData,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetadataTable,
      SyncMetadataData,
      $$SyncMetadataTableFilterComposer,
      $$SyncMetadataTableOrderingComposer,
      $$SyncMetadataTableAnnotationComposer,
      $$SyncMetadataTableCreateCompanionBuilder,
      $$SyncMetadataTableUpdateCompanionBuilder,
      (
        SyncMetadataData,
        BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
      ),
      SyncMetadataData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$MonthlySummariesTableTableManager get monthlySummaries =>
      $$MonthlySummariesTableTableManager(_db, _db.monthlySummaries);
  $$ParserRulesTableTableManager get parserRules =>
      $$ParserRulesTableTableManager(_db, _db.parserRules);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
}
