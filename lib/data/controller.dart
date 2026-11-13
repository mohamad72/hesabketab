import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/finance.dart';
import 'merge.dart';
import 'storage.dart';
import 'sheets_remote.dart';

class FinanceController extends ChangeNotifier {
  final Future<void> Function(Json) saveDocument;
  Map<String, Json> entities = {}, base = {}, bindings = {};
  List<Json> conflicts = [];
  String selectedMonth = Month.now().key;
  String spreadsheetId = defaultSpreadsheet;
  double sheetFactor = 1000;
  DateTime? lastSync;
  bool syncing = false;
  String syncMessage = 'هنوز به گوگل متصل نشده‌اید';
  Future<void> _writeTail = Future.value();
  Future<void> _transactionTail = Future.value();
  FinanceController({Future<void> Function(Json)? saveDocument})
    : saveDocument = saveDocument ?? LocalStore().write;
  Json document() => {
    'version': 1,
    'entities': entities,
    'base': base,
    'bindings': bindings,
    'conflicts': conflicts,
    'selectedMonth': selectedMonth,
    'spreadsheetId': spreadsheetId,
    'sheetFactor': sheetFactor,
    'lastSync': lastSync?.toIso8601String(),
  };
  Future<void> load() async {
    final j = await LocalStore().read();
    if (j != null) restore(j);
    notifyListeners();
  }

  void restore(Json j) {
    entities = decodeMap(j['entities']);
    base = decodeMap(j['base']);
    bindings = decodeMap(j['bindings']);
    conflicts = (j['conflicts'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    selectedMonth = j['selectedMonth'] ?? selectedMonth;
    spreadsheetId = j['spreadsheetId'] ?? defaultSpreadsheet;
    sheetFactor = (j['sheetFactor'] as num? ?? 1000).toDouble();
    lastSync = DateTime.tryParse(j['lastSync'] ?? '');
  }

  static Map<String, Json> decodeMap(dynamic m) => {
    for (final e in (m as Map? ?? {}).entries)
      '${e.key}': Map<String, dynamic>.from(e.value),
  };
  Future<void> persist() {
    final snapshot = jsonDecode(jsonEncode(document())) as Json;
    final pending = _writeTail
        .catchError((Object _) {})
        .then((_) => saveDocument(snapshot));
    _writeTail = pending;
    return pending;
  }

  Future<void> change(void Function() mutate) {
    final operation = _transactionTail.catchError((Object _) {}).then((
      _,
    ) async {
      final before = jsonDecode(jsonEncode(document())) as Json;
      try {
        mutate();
        _refreshCarry();
        await persist();
        notifyListeners();
      } catch (e) {
        restore(before);
        notifyListeners();
        rethrow;
      }
    });
    _transactionTail = operation;
    return operation;
  }

  void _refreshCarry() {
    final keys = months;
    for (final key in keys) {
      final id = 'carry_$key'.replaceAll('-', ''), j = entities[id];
      if (j == null ||
          j['carryProvisional'] != true ||
          j['carryManual'] == true) {
        continue;
      }
      final previous = Month.key(key).previous.key;
      j['expected'] = FinancialSummary(entriesFor(previous)).end;
    }
  }

  List<String> get months {
    final keys =
        entities.values
            .where((e) => e['type'] == 'month')
            .map((e) => e['month'] as String)
            .toSet()
          ..add(selectedMonth);
    return keys.toList()..sort();
  }

  List<Entry> entriesFor(String month) => entities.values
      .where((e) => e['type'] == 'entry' && e['month'] == month)
      .map(Entry.fromJson)
      .toList();
  List<Entry> get entries => entriesFor(selectedMonth);
  List<Json> get accounts {
    final a = entities.values
        .where((e) => e['type'] == 'account' && e['month'] == selectedMonth)
        .toList();
    int rank(Json e) => e['owner'] == 'سارا'
        ? 0
        : e['owner'] == 'محمد'
        ? 1
        : 2;
    a.sort((x, y) => rank(x).compareTo(rank(y)));
    return a;
  }

  double get bankTotal => accounts.fold(0, (s, a) => s + (a['balance'] as num));
  int get pending => {
    ...entities.keys,
    ...base.keys,
  }.where((id) => !same(entities[id], base[id])).length;
  FinancialSummary get summary => FinancialSummary(entries);
  List<String> get providers =>
      entities.values
          .where((e) => e['provider'] != null)
          .map((e) => e['provider'] as String)
          .toSet()
          .toList()
        ..sort();
  void ensureMonth(String key) {
    entities.putIfAbsent(
      'month_$key',
      () => {'id': 'month_$key', 'type': 'month', 'month': key},
    );
  }

  void _daily(String month) {
    final as = entities.values
        .where((e) => e['type'] == 'account' && e['month'] == month)
        .toList();
    if (as.isEmpty ||
        !entities.values.any(
          (e) =>
              e['type'] == 'month' &&
              e['month'] == month &&
              e['bankConfirmed'] == true,
        )) {
      return;
    }
    final es = entriesFor(month),
        daily = es.where((e) => e.isDaily).firstOrNull;
    if (daily == null) return;
    daily.actual = dailySpending(
      es,
      as.fold<double>(0, (v, a) => v + (a['balance'] as num)),
    );
    entities[daily.id] = {...daily.toJson(), 'type': 'entry'};
  }

  Future<void> saveEntry(Entry entry) => change(() {
    final e = entry.copy();
    e.day = e.effectiveDay;
    ensureMonth(e.month);
    entities[e.id] = {...e.toJson(), 'type': 'entry'};
    _daily(e.month);
  });
  Future<void> deleteEntry(Entry e) => change(() {
    entities.remove(e.id);
    _daily(e.month);
  });
  Future<void> selectMonth(String key) => change(() {
    selectedMonth = key;
  });
  Future<void> saveBalances(Map<String, double?> values) => change(() {
    for (final e in accounts) {
      if (values[e['id']] != null) {
        entities[e['id']] = {
          ...e,
          'previousBalance': e['balance'],
          'balance': values[e['id']],
          'updatedAt': DateTime.now().toIso8601String(),
        };
      }
    }
    ensureMonth(selectedMonth);
    entities['month_$selectedMonth']!['bankConfirmed'] = true;
    _daily(selectedMonth);
  });
  Future<void> addAccount(String title, String owner, double amount) =>
      change(() {
        ensureMonth(selectedMonth);
        final id = newId();
        entities[id] = {
          'id': id,
          'type': 'account',
          'month': selectedMonth,
          'title': title,
          'owner': owner,
          'balance': amount,
        };
      });
  Future<void> createMonth(String key) => change(() {
    if (entities.containsKey('month_$key')) {
      selectedMonth = key;
      return;
    }
    final previous = Month.key(key).previous.key;
    ensureMonth(key);
    final sources = <String, Entry>{};
    for (final j in entities.values.toList()) {
      if (j['type'] != 'entry') continue;
      final e = Entry.fromJson(j);
      if (!e.repeat || e.month.compareTo(key) >= 0) continue;
      final root = e.origin ?? e.id, prior = sources[root];
      if (prior == null || prior.month.compareTo(e.month) < 0) {
        sources[root] = e;
      }
    }
    for (final source in sources.values) {
      final next = recurringOccurrence(source, key);
      if (next != null) {
        entities.putIfAbsent(
          next.id,
          () => {...next.toJson(), 'type': 'entry'},
        );
      }
    }
    final carry = Entry(
      id: 'carry_$key'.replaceAll('-', ''),
      month: key,
      kind: Kind.income,
      title: 'مانده از ماه قبل',
      expected: FinancialSummary(entriesFor(previous)).end,
      carryProvisional: true,
    );
    entities.putIfAbsent(carry.id, () => {...carry.toJson(), 'type': 'entry'});
    // Bank balances remain snapshots; creating a month does not confirm a new balance.
    for (final a
        in entities.values
            .where((e) => e['type'] == 'account' && e['month'] == previous)
            .toList()) {
      final id = 'bank_${a['origin'] ?? a['id']}_$key'.replaceAll('-', '');
      entities[id] = {
        ...a,
        'id': id,
        'origin': a['origin'] ?? a['id'],
        'month': key,
      };
    }
    selectedMonth = key;
  });
  Future<void> reviewEntry(Entry e, Review status) => change(() {
    final copy = e.copy()
      ..review = status
      ..done = status != Review.planned;
    entities[e.id] = {...copy.toJson(), 'type': 'entry'};
    if (status == Review.moved) {
      final month = Month.key(e.month).next.key;
      ensureMonth(month);
      final id = 'move_${e.id}_$month'.replaceAll('-', '');
      final moved = e.copy()
        ..id = id
        ..month = month
        ..actual = null
        ..actualExpression = null
        ..done = false
        ..review = Review.planned;
      entities.putIfAbsent(id, () => {...moved.toJson(), 'type': 'entry'});
    }
    _daily(e.month);
  });
  Future<void> addPurchase({
    required String title,
    required String provider,
    required Kind kind,
    required double total,
    required List<Json> schedule,
    double? firstActual,
  }) => change(() {
    final id = newId();
    entities[id] = {
      'id': id,
      'type': 'purchase',
      'title': title,
      'provider': provider,
      'total': total,
      'schedule': schedule,
    };
    for (var i = 0; i < schedule.length; i++) {
      final p = schedule[i], month = p['month'] as String;
      final e = Entry(
        id: '${id}_$i',
        month: month,
        kind: kind,
        title: i == 0 ? title : '$provider · $title · قسط ${persian(i + 1)}',
        expected: (p['amount'] as num).toDouble(),
        actual: i == 0 ? firstActual : null,
        day: p['day'],
        purchaseId: id,
        provider: provider,
      );
      entities[e.id] = {...e.toJson(), 'type': 'entry'};
      if (i == 0) ensureMonth(month);
    }
  });
  Future<void> resolve(Json conflict, bool local) => change(() {
    final id = conflict['id'] as String, field = conflict['field'] as String;
    final value = conflict[local ? 'local' : 'remote'];
    if (field == r'$record') {
      if (value == null) {
        entities.remove(id);
      } else {
        entities[id] = Map<String, dynamic>.from(value);
      }
    } else if (conflict['money'] == true) {
      entities[id]?[field] = value['value'];
      entities[id]?['${field}Expression'] = value['expression'];
    } else {
      entities[id]?[field] = value;
    }
    // The remote side is now the comparison base, while the selected local side
    // remains a durable pending edit. Other unresolved fields retain both values.
    if (field == r'$record') {
      if (conflict['remote'] == null) {
        base.remove(id);
      } else {
        base[id] = Map<String, dynamic>.from(conflict['remote']);
      }
    } else if (conflict['money'] == true) {
      final record = base.putIfAbsent(id, () => {});
      record[field] = conflict['remote']['value'];
      record['${field}Expression'] = conflict['remote']['expression'];
    } else {
      base.putIfAbsent(id, () => {})[field] = conflict['remote'];
    }
    conflicts.removeWhere((c) => c['id'] == id && c['field'] == field);
  });
  Future<void> sync({bool interactive = false}) async {
    if (syncing) return;
    syncing = true;
    syncMessage = 'در حال اتصال…';
    notifyListeners();
    final remote = SheetsRemote(
      spreadsheetId: spreadsheetId,
      factor: sheetFactor,
    );
    try {
      await _writeTail;
      var snapshot = await remote.read(
        interactive: interactive,
        progress: (s) {
          syncMessage = s;
          notifyListeners();
        },
      );
      if (await remote.anchor(snapshot)) snapshot = await remote.read();
      await _transactionTail.catchError((Object _) {});
      final merged = mergeDocuments(base, entities, snapshot.entities);
      if (merged.conflicts.isNotEmpty) {
        await change(() {
          entities = merged.entities;
          conflicts = merged.conflicts;
          bindings = snapshot.bindings;
        });
        syncMessage = 'اختلاف‌ها برای انتخاب شما حفظ شدند';
        return;
      }
      // Persist the remote comparison base before sending anything; a killed app
      // resumes from the same three versions and retries using stable identities.
      await change(() {
        entities = merged.entities;
        bindings = snapshot.bindings;
      });
      final sent = decodeMap(jsonDecode(jsonEncode(entities)));
      syncMessage = 'ارسال تغییرات…';
      notifyListeners();
      await remote.write(sent, snapshot);
      syncMessage = 'بررسی نتیجهٔ ارسال…';
      notifyListeners();
      final verified = await remote.read();
      // Metadata is written in the same atomic batch as cells. Read back the
      // independent visible records, not just the HTTP success response.
      for (final id in sent.keys) {
        final s = sent[id], v = verified.entities[id];
        if (v == null) {
          throw Exception('تأیید رکورد $id کامل نشد؛ تغییرات محلی حفظ شدند.');
        }
        for (final field in ['expected', 'actual', 'done', 'balance']) {
          if (!s!.containsKey(field)) continue;
          final x = s[field], y = v[field];
          final equal = x is num && y is num
              ? (x - y).abs() < 0.001
              : same(x, y);
          if (!equal) {
            throw Exception(
              'نتیجهٔ «${s['title'] ?? id}» با دادهٔ ارسالی متفاوت است؛ دوباره همگام‌سازی کنید.',
            );
          }
        }
      }
      await _transactionTail.catchError((Object _) {});
      final latest = mergeDocuments(sent, entities, verified.entities);
      await change(() {
        entities = latest.entities;
        base = verified.entities;
        bindings = verified.bindings;
        conflicts = latest.conflicts;
        lastSync = DateTime.now();
      });
      syncMessage = conflicts.isEmpty
          ? 'همگام‌سازی انجام شد'
          : 'اختلاف جدید نیاز به انتخاب دارد';
    } catch (e) {
      syncMessage = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }
}
