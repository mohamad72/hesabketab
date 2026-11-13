import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesab_hazrat/data/controller.dart';
import 'package:hesab_hazrat/domain/finance.dart';

void main() {
  test('six months offline survives reload with pending changes', () async {
    Json? disk;
    final c = FinanceController(
      saveDocument: (j) async {
        disk = jsonDecode(jsonEncode(j));
      },
    );
    await c.saveEntry(
      Entry(
        id: 'salary',
        month: '1405-08',
        kind: Kind.income,
        title: 'حقوق',
        expected: 50000000,
        actual: 0,
        repeat: true,
        repeatEnd: '1406-01',
      ),
    );
    for (var i = 9; i <= 12; i++) {
      await c.createMonth(Month(1405, i).key);
    }
    await c.createMonth('1406-01');
    await c.createMonth('1406-02');
    final reopened = FinanceController(saveDocument: (_) async {})
      ..restore(disk!);
    expect(
      reopened.entriesFor('1406-01').where((e) => e.title == 'حقوق').length,
      1,
    );
    expect(
      reopened.entriesFor('1406-02').where((e) => e.title == 'حقوق'),
      isEmpty,
    );
    expect(reopened.pending, greaterThan(0));
    final count = reopened.entities.length;
    await reopened.createMonth('1406-01');
    expect(reopened.entities.length, count);
    expect(
      reopened
          .entriesFor('1405-09')
          .firstWhere((e) => e.title == 'حقوق')
          .actual,
      null,
    );
  });
  test(
    'four installments materialize exactly once, first remains under product',
    () async {
      final c = FinanceController(saveDocument: (_) async {});
      await c.addPurchase(
        title: 'میز',
        provider: 'نام تازه',
        kind: Kind.special,
        total: 120,
        schedule: [
          for (var i = 0; i < 4; i++)
            {'month': Month(1405, 8 + i).key, 'day': 31, 'amount': 30},
        ],
        firstActual: 30,
      );
      expect(c.entriesFor('1405-08').single.kind, Kind.special);
      expect(c.entriesFor('1405-09').single.kind, Kind.fixed);
      expect(c.providers, ['نام تازه']);
      await c.createMonth('1405-09');
      await c.createMonth('1405-09');
      expect(
        c.entriesFor('1405-09').where((e) => e.purchaseId != null).length,
        1,
      );
    },
  );
  test(
    'empty account input is preserved and daily expense does not accumulate',
    () async {
      final c = FinanceController(saveDocument: (_) async {})
        ..selectedMonth = '1405-08';
      await c.saveEntry(
        Entry(
          id: 'i',
          month: c.selectedMonth,
          kind: Kind.income,
          title: 'درآمد',
          actual: 200,
        ),
      );
      await c.saveEntry(
        Entry(
          id: 'd',
          month: c.selectedMonth,
          kind: Kind.fixed,
          title: dailyTitle,
        ),
      );
      await c.addAccount('ملی', 'سارا', 150);
      final id = c.accounts.single['id'];
      await c.saveBalances({id: null});
      expect(c.accounts.single['balance'], 150);
      expect(c.entries.firstWhere((e) => e.isDaily).actual, 50);
      await c.saveBalances({id: 150});
      expect(c.entries.firstWhere((e) => e.isDaily).actual, 50);
      await c.saveEntry(
        Entry(
          id: 'expense',
          month: c.selectedMonth,
          kind: Kind.special,
          title: 'فراموش شده',
          actual: 20,
        ),
      );
      expect(c.entries.firstWhere((e) => e.isDaily).actual, 30);
    },
  );
  test(
    'failed persistence reports error and restores previous state',
    () async {
      final c = FinanceController(
        saveDocument: (_) async {
          throw Exception('disk full');
        },
      );
      await expectLater(
        c.saveEntry(
          Entry(id: 'x', month: '1405-08', kind: Kind.saving, title: 'طلا'),
        ),
        throwsException,
      );
      expect(c.entities, isEmpty);
    },
  );
  test('money formatter retains integer zeroes and fractional values', () {
    expect(money(12000000), '۱۲٬۰۰۰٬۰۰۰');
    expect(parseMoney('۱۲٬۳۴۵٫۲۵'), 12345.25);
    expect(money(0), '۰');
    expect(money(12.5), '۱۲.۵');
  });
  test(
    'later prior-month corrections update provisional carry but preserve manual carry',
    () async {
      final c = FinanceController(saveDocument: (_) async {})
        ..selectedMonth = '1405-08';
      await c.saveEntry(
        Entry(
          id: 'i',
          month: '1405-08',
          kind: Kind.income,
          title: 'درآمد',
          expected: 100,
        ),
      );
      await c.createMonth('1405-09');
      await c.saveEntry(
        Entry(
          id: 'i',
          month: '1405-08',
          kind: Kind.income,
          title: 'درآمد',
          expected: 200,
        ),
      );
      expect(
        c.entriesFor('1405-09').firstWhere((e) => e.carryProvisional).expected,
        200,
      );
      final carry =
          c.entriesFor('1405-09').firstWhere((e) => e.carryProvisional)
            ..expected = 70
            ..carryManual = true;
      await c.saveEntry(carry);
      await c.saveEntry(
        Entry(
          id: 'i',
          month: '1405-08',
          kind: Kind.income,
          title: 'درآمد',
          expected: 300,
        ),
      );
      expect(
        c.entriesFor('1405-09').firstWhere((e) => e.carryProvisional).expected,
        70,
      );
    },
  );
  test(
    'overlapping failed save cannot erase a later successful transaction',
    () async {
      final gate = Completer<void>();
      var writes = 0;
      Json? disk;
      final c = FinanceController(
        saveDocument: (j) async {
          writes++;
          if (writes == 1) await gate.future;
          disk = j;
        },
      );
      final a = c.saveEntry(
        Entry(id: 'a', month: '1405-08', kind: Kind.income, title: 'اول'),
      );
      final failed = expectLater(a, throwsException);
      final b = c.saveEntry(
        Entry(id: 'b', month: '1405-08', kind: Kind.saving, title: 'دوم'),
      );
      await Future<void>.delayed(Duration.zero);
      gate.completeError(Exception('disk full'));
      await failed;
      await b;
      expect(c.entities.containsKey('a'), false);
      expect(c.entities.containsKey('b'), true);
      expect((disk!['entities'] as Map).containsKey('b'), true);
    },
  );
}
