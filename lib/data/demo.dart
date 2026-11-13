import '../domain/finance.dart';
import 'controller.dart';

// Explicit, isolated preview only. Never loaded into the user's local document.
FinanceController demoController() {
  final c = FinanceController(saveDocument: (_) async {})
    ..selectedMonth = '1405-08';
  c.ensureMonth('1405-08');
  final records = [
    Entry(
      id: 'demo1',
      month: c.selectedMonth,
      kind: Kind.income,
      title: 'حقوق ماهانه',
      expected: 78000000,
      actual: 78000000,
      day: 10,
      repeat: true,
    ),
    Entry(
      id: 'demo2',
      month: c.selectedMonth,
      kind: Kind.income,
      title: 'پروژهٔ طراحی',
      expected: 14000000,
      day: 24,
    ),
    Entry(
      id: 'demo3',
      month: c.selectedMonth,
      kind: Kind.fixed,
      title: 'اجارهٔ خانه',
      expected: 21000000,
      actual: 21000000,
      day: 1,
      done: true,
    ),
    Entry(
      id: 'demo4',
      month: c.selectedMonth,
      kind: Kind.fixed,
      title: dailyTitle,
      expected: 12000000,
      actual: 7200000,
    ),
    Entry(
      id: 'demo5',
      month: c.selectedMonth,
      kind: Kind.fixed,
      title: 'اینترنت و تلفن',
      expected: 850000,
      actual: 650000,
      day: 12,
    ),
    Entry(
      id: 'demo6',
      month: c.selectedMonth,
      kind: Kind.fixed,
      title: 'قسط ماهانه',
      expected: 4500000,
      day: 25,
    ),
    Entry(
      id: 'demo7',
      month: c.selectedMonth,
      kind: Kind.special,
      title: 'خرید صندلی کار',
      expected: 6800000,
      actual: 2300000,
      day: 22,
    ),
    Entry(
      id: 'demo8',
      month: c.selectedMonth,
      kind: Kind.special,
      title: 'چکاپ سالانه',
      expected: 2400000,
      day: 28,
    ),
    Entry(
      id: 'demo9',
      month: c.selectedMonth,
      kind: Kind.saving,
      title: 'صندوق سرمایه‌گذاری',
      expected: 15000000,
      actual: 9000000,
      day: 15,
    ),
    Entry(
      id: 'demo10',
      month: c.selectedMonth,
      kind: Kind.saving,
      title: 'پس‌انداز سفر',
      expected: 5000000,
      actual: 2000000,
      day: 26,
    ),
  ];
  for (final e in records) {
    c.entities[e.id] = {...e.toJson(), 'type': 'entry'};
  }
  for (final a in [
    ('ملی', 'سارا', 18500000.0),
    ('ویپاد', 'سارا', 9200000.0),
    ('سامان', 'محمد', 13750000.0),
    ('پول نقد', 'سایر', 2400000.0),
  ]) {
    final id = 'demo_bank_${a.$1}';
    c.entities[id] = {
      'id': id,
      'type': 'account',
      'month': c.selectedMonth,
      'title': a.$1,
      'owner': a.$2,
      'balance': a.$3,
    };
  }
  for (var i = 3; i < 8; i++) {
    final m = Month(1405, i);
    c.ensureMonth(m.key);
    final e = Entry(
      id: 'demo_save_$i',
      month: m.key,
      kind: Kind.saving,
      title: 'پس‌انداز',
      expected: 8000000.0 + i * 1000000,
      actual: 5500000.0 + i * 850000,
    );
    c.entities[e.id] = {...e.toJson(), 'type': 'entry'};
  }
  return c;
}
