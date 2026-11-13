import 'package:flutter_test/flutter_test.dart';
import 'package:hesab_hazrat/domain/finance.dart';

Entry item({
  String id = 'a',
  Kind kind = Kind.income,
  double expected = 100,
  double? actual,
  bool done = false,
  int? day,
  String title = 'مورد',
}) => Entry(
  id: id,
  month: '1405-08',
  kind: kind,
  title: title,
  expected: expected,
  actual: actual,
  done: done,
  day: day,
);
void main() {
  test('blank income falls back; explicit zero does not', () {
    expect(FinancialSummary([item()]).baseIncome, 100);
    expect(FinancialSummary([item(actual: 0)]).baseIncome, 0);
  });
  test('completion releases every type of outgoing, not income', () {
    for (final kind in [Kind.fixed, Kind.special, Kind.saving]) {
      expect(item(kind: kind, actual: 60).remaining, 40);
      expect(item(kind: kind, actual: 60, done: true).remaining, 0);
      expect(item(kind: kind, actual: 120).remaining, 0);
    }
  });
  test('all summary definitions agree with the specification', () {
    final s = FinancialSummary([
      item(expected: 200, actual: 180),
      item(id: 'b', expected: 20),
      item(id: 'c', kind: Kind.fixed, expected: 100, actual: 60),
      item(id: 'd', kind: Kind.saving, expected: 50, actual: 20, done: true),
    ]);
    expect(
      [
        s.expectedIncome,
        s.actualIncome,
        s.baseIncome,
        s.expectedOut,
        s.actualOut,
        s.expectedDifference,
        s.current,
        s.noMoreSpending,
        s.remaining,
        s.end,
      ],
      [220, 180, 200, 150, 80, 70, 100, 120, 40, 80],
    );
  });
  test('Persian month titles normalize digits, spaces and year rollover', () {
    expect(Month.parse('مهر۱۴۰۳')?.key, '1403-07');
    expect(Month.parse('اسفند ۱۴۰۱ ')?.next.key, '1402-01');
    expect(Month(1403, 12).days, 30);
    expect(Month(1404, 12).days, 29);
    expect(Month(1405, 8).validDay(31), 30);
  });
  test('salary default and ambiguous installment number extraction', () {
    expect(item(title: 'حقوق داتین').effectiveDay, 10);
    expect(item(title: 'حقوق', day: 22).effectiveDay, 22);
    expect(splitTitleDay('قسط ۲').$2, null);
    expect(splitTitleDay('قسط رسالت ۲۵').$2, 25);
    expect(splitTitleDay('قسط ملی 12و ملی محمد 27').$2, null);
    expect(sheetTitle(item(title: 'حقوق', day: 12)), 'حقوق ۱۲');
  });
  test('daily expense is reconstructed and can be negative', () {
    final entries = [
      item(actual: 200),
      item(id: 'b', kind: Kind.fixed, actual: 30),
      item(id: 'daily', kind: Kind.fixed, title: dailyTitle, actual: 10),
    ];
    expect(dailySpending(entries, 150), 20);
    entries[1] = item(id: 'b', kind: Kind.fixed, actual: 40);
    expect(dailySpending(entries, 150), 10);
    expect(dailySpending(entries, 200), -40);
  });
  test(
    'recurrence is inclusive, resets actual/status and has stable identity',
    () {
      final e = item(actual: 45, done: true)
        ..repeat = true
        ..repeatEnd = '1405-09';
      final next = recurringOccurrence(e, '1405-09');
      expect(next?.actual, null);
      expect(next?.done, false);
      expect(next?.id, recurringOccurrence(e, '1405-09')?.id);
      expect(recurringOccurrence(e, '1405-10'), null);
    },
  );
  test(
    'forecast avoids paid money and includes installments before month exists',
    () {
      final entries = [
        item(id: 'salary', expected: 100, actual: 60, day: 25),
        item(id: 'out', kind: Kind.fixed, expected: 80, actual: 30, day: 26),
      ];
      final points = forecast(
        entries,
        month: '1405-08',
        startDay: 20,
        balance: 100,
      );
      expect(points.last.balance, 50);
    },
  );
  test(
    'overdue open obligations remain in the forecast and provider totals exclude first installment',
    () {
      final e = item(kind: Kind.fixed, expected: 100, actual: 20, day: 12);
      expect(
        forecast([e], month: e.month, startDay: 22, balance: 200).last.balance,
        120,
      );
      final a = e.copy()
        ..id = 'purchase_0'
        ..purchaseId = 'purchase'
        ..provider = 'فروشگاه';
      final b = e.copy()
        ..id = 'purchase_1'
        ..purchaseId = 'purchase'
        ..provider = 'فروشگاه';
      expect(installmentSummaries([a, b]).single['expected'], 100);
    },
  );
}
