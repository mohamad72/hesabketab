import 'dart:math';
import 'package:shamsi_date/shamsi_date.dart';

typedef Json = Map<String, dynamic>;
const dailyTitle = 'غذا و حمل و نقل و امور جاری';
const monthNames = [
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];
String latin(String value) {
  const fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    value = value.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return value.replaceAll('ي', 'ی').replaceAll('ك', 'ک');
}

String persian(Object value) => '$value'.replaceAllMapped(
  RegExp(r'[0-9]'),
  (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)],
);
String normal(String s) => latin(s).replaceAll(RegExp(r'[\s‌ـ]'), '');
double? parseMoney(String text) {
  final s = latin(text).replaceAll(RegExp(r'[,٬\s]'), '').replaceAll('٫', '.');
  if (s.isEmpty) return null;
  final n = double.tryParse(s);
  return n != null && n.isFinite ? n : null;
}

String money(num? value, {bool compact = false}) {
  if (value == null) return '—';
  if (compact && value.abs() >= 1000000) {
    return '${persian((value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1))} میلیون';
  }
  final parts = value
      .toStringAsFixed(value % 1 == 0 ? 0 : 3)
      .replaceFirst(RegExp(r'\.?0+$'), value % 1 == 0 ? '0' : '')
      .split('.');
  // Keep integer zeroes; only trim decimals.
  final raw = value % 1 == 0 ? value.toInt().toString() : parts[0];
  final grouped = raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}٬',
  );
  return persian('$grouped${parts.length > 1 ? '.${parts[1]}' : ''}');
}

String newId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class Month implements Comparable<Month> {
  final int year, number;
  const Month(this.year, this.number);
  factory Month.now() {
    final j = Jalali.now();
    return Month(j.year, j.month);
  }
  factory Month.key(String key) {
    final p = key.split('-');
    return Month(int.parse(p[0]), int.parse(p[1]));
  }
  static Month? parse(String title) {
    final t = normal(title), year = RegExp(r'1[34]\d{2}').firstMatch(t);
    if (year == null) return null;
    for (var i = 0; i < 12; i++) {
      if (t.contains(monthNames[i])) return Month(int.parse(year[0]!), i + 1);
    }
    return null;
  }

  String get key => '$year-${number.toString().padLeft(2, '0')}';
  String get label => '${monthNames[number - 1]} ${persian(year)}';
  Month get next => number == 12 ? Month(year + 1, 1) : Month(year, number + 1);
  Month get previous =>
      number == 1 ? Month(year - 1, 12) : Month(year, number - 1);
  int get days => Jalali(year, number, 1).monthLength;
  int validDay(int day) => day.clamp(1, days);
  @override
  int compareTo(Month other) => key.compareTo(other.key);
}

enum Kind { income, fixed, special, saving }

extension KindLabel on Kind {
  String get label =>
      ['درآمدها', 'هزینه‌های ثابت', 'هزینه‌های خاص', 'پس‌انداز'][index];
  String get singular =>
      ['درآمد', 'هزینهٔ ثابت', 'هزینهٔ خاص', 'پس‌انداز'][index];
}

enum Review { planned, failed, cancelled, moved }

class Entry {
  String id, month, title;
  Kind kind;
  double expected;
  double? actual;
  int? day;
  bool done, repeat;
  String? repeatEnd, origin, purchaseId, provider;
  Review review;
  bool carryProvisional, carryManual;
  Entry({
    required this.id,
    required this.month,
    required this.kind,
    required this.title,
    this.expected = 0,
    this.actual,
    this.day,
    this.done = false,
    this.repeat = false,
    this.repeatEnd,
    this.origin,
    this.purchaseId,
    this.provider,
    this.review = Review.planned,
    this.carryProvisional = false,
    this.carryManual = false,
  });
  int? get effectiveDay => day ?? (title.contains('حقوق') ? 10 : null);
  double get remaining =>
      kind == Kind.income || done || review != Review.planned
      ? 0
      : max(expected - (actual ?? 0), 0);
  bool get isDaily => normal(title) == normal(dailyTitle);
  Json toJson() => {
    'id': id,
    'month': month,
    'kind': kind.name,
    'title': title,
    'expected': expected,
    'actual': actual,
    'day': day,
    'done': done,
    'repeat': repeat,
    'repeatEnd': repeatEnd,
    'origin': origin,
    'purchaseId': purchaseId,
    'provider': provider,
    'review': review.name,
    'carryProvisional': carryProvisional,
    'carryManual': carryManual,
  };
  factory Entry.fromJson(Json j) => Entry(
    id: j['id'],
    month: j['month'],
    kind: Kind.values.byName(j['kind']),
    title: j['title'],
    expected: (j['expected'] as num).toDouble(),
    actual: (j['actual'] as num?)?.toDouble(),
    day: j['day'],
    done: j['done'] ?? false,
    repeat: j['repeat'] ?? false,
    repeatEnd: j['repeatEnd'],
    origin: j['origin'],
    purchaseId: j['purchaseId'],
    provider: j['provider'],
    review: Review.values.byName(j['review'] ?? 'planned'),
    carryProvisional: j['carryProvisional'] ?? false,
    carryManual: j['carryManual'] ?? false,
  );
  Entry copy() => Entry.fromJson(toJson());
}

(String, int?) splitTitleDay(String text) {
  final t = latin(text).trim();
  final matches = RegExp(r'\d+').allMatches(t).toList();
  if (matches.length != 1) return (text.trim(), null);
  final m = RegExp(r'^(.+\S)\s+(\d{1,2})$').firstMatch(t);
  if (m == null || RegExp(r'^قسط\s*$').hasMatch(m[1]!)) {
    return (text.trim(), null);
  }
  final d = int.parse(m[2]!);
  return d >= 1 && d <= 31 ? (m[1]!, d) : (text.trim(), null);
}

String sheetTitle(Entry e) =>
    e.effectiveDay == null ? e.title : '${e.title} ${persian(e.effectiveDay!)}';

class FinancialSummary {
  final List<Entry> entries;
  FinancialSummary(Iterable<Entry> entries) : entries = entries.toList();
  double sum(bool income, double Function(Entry) f) => entries
      .where((e) => (e.kind == Kind.income) == income)
      .fold(0, (v, e) => v + f(e));
  double get expectedIncome => sum(true, (e) => e.expected);
  double get actualIncome => sum(true, (e) => e.actual ?? 0);
  double get baseIncome => sum(true, (e) => e.actual ?? e.expected);
  double get expectedOut => sum(false, (e) => e.expected);
  double get actualOut => sum(false, (e) => e.actual ?? 0);
  double get expectedDifference => expectedIncome - expectedOut;
  double get current => actualIncome - actualOut;
  double get noMoreSpending => baseIncome - actualOut;
  double get remaining => sum(false, (e) => e.remaining);
  double get end => noMoreSpending - remaining;
  Map<String, double> get metrics => {
    'مجموع درآمد مورد انتظار': expectedIncome,
    'مجموع درآمد ثبت‌شده': actualIncome,
    'مجموع درآمد مبنا': baseIncome,
    'مجموع خروجی مورد انتظار': expectedOut,
    'مجموع خروجی واقعی': actualOut,
    'اختلاف انتظار درآمد و هزینه': expectedDifference,
    'موجودی محاسباتی فعلی': current,
    'اگر دیگر خرج نکنیم': noMoreSpending,
    'پرداخت‌های باقی‌مانده': remaining,
    'ماندهٔ پایان ماه': end,
  };
}

double dailySpending(Iterable<Entry> entries, double bankTotal) {
  final s = FinancialSummary(entries.where((e) => !e.isDaily));
  return s.current - bankTotal;
}

Entry? recurringOccurrence(Entry source, String target) {
  if (!source.repeat ||
      target.compareTo(source.month) <= 0 ||
      (source.repeatEnd != null && target.compareTo(source.repeatEnd!) > 0)) {
    return null;
  }
  return source.copy()
    ..id = 'r_${source.origin ?? source.id}_$target'.replaceAll('-', '')
    ..origin = source.origin ?? source.id
    ..month = target
    ..actual = null
    ..done = false
    ..review = Review.planned;
}

class ForecastPoint {
  final int day;
  final double balance;
  final List<String> events;
  ForecastPoint(this.day, this.balance, this.events);
}

List<ForecastPoint> forecast(
  Iterable<Entry> all, {
  required String month,
  required int startDay,
  required double balance,
  double dailyEstimate = 0,
}) {
  final m = Month.key(month),
      entries = all.where((e) => e.month == month).toList();
  final points = <ForecastPoint>[
    ForecastPoint(startDay, balance, ['موجودی مبنا']),
  ];
  for (var day = startDay; day <= m.days; day++) {
    final events = <String>[];
    for (final e in entries) {
      if (e.effectiveDay == null ||
          max(startDay, m.validDay(e.effectiveDay!)) != day ||
          e.review != Review.planned) {
        continue;
      }
      final amount = e.kind == Kind.income
          ? (e.actual == null ? e.expected : 0)
          : e.remaining;
      if (amount != 0) {
        balance += e.kind == Kind.income ? amount : -amount;
        events.add(e.title);
      }
    }
    if (day > startDay) balance -= dailyEstimate;
    points.add(ForecastPoint(day, balance, events));
  }
  return points;
}

List<Json> installmentSummaries(Iterable<Entry> entries) {
  final groups = <String, Json>{};
  for (final e in entries) {
    if (e.purchaseId == null || e.id == '${e.purchaseId}_0') continue;
    final key = '${e.month}_${e.provider}';
    final group = groups.putIfAbsent(
      key,
      () => {
        'month': e.month,
        'provider': e.provider,
        'expected': 0.0,
        'actual': 0.0,
        'remaining': 0.0,
        'items': <String>[],
      },
    );
    group['expected'] = (group['expected'] as double) + e.expected;
    group['actual'] = (group['actual'] as double) + (e.actual ?? 0);
    group['remaining'] = (group['remaining'] as double) + e.remaining;
    (group['items'] as List<String>).add(e.title);
  }
  return groups.values.toList()
    ..sort((a, b) => (a['month'] as String).compareTo(b['month']));
}
