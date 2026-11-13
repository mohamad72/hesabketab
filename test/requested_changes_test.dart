import 'package:flutter_test/flutter_test.dart';
import 'package:hesab_hazrat/data/merge.dart';
import 'package:hesab_hazrat/data/controller.dart';
import 'package:hesab_hazrat/domain/finance.dart';

void main() {
  test('simple Persian plus/minus formulas preserve zero versus empty', () {
    expect(parseMoney('۱٬۲۰۰٬۰۰۰ + ۳۰۰٬۰۰۰ - ۵۰٬۰۰۰'), 1450000);
    expect(parseMoney('=100-120'), -20);
    expect(parseMoney('۱۰۰-۱۰۰'), 0);
    expect(parseMoney(''), null);
    for (final invalid in ['10+', 'SUM(A1)', '2*3', '10/0', 'NaN', '1.2.3']) {
      expect(parseMoney(invalid), null);
    }
  });
  test(
    'each of four installments stays in chosen section, including future months',
    () async {
      for (final kind in [Kind.fixed, Kind.special, Kind.saving]) {
        final c = FinanceController(saveDocument: (_) async {});
        await c.addPurchase(
          title: 'کالا',
          provider: 'سرویس',
          kind: kind,
          total: 100,
          schedule: [
            for (var i = 0; i < 4; i++)
              {'month': Month(1405, 8 + i).key, 'day': 25, 'amount': 25},
          ],
        );
        expect(
          c.entities.values
              .where((e) => e['type'] == 'entry')
              .map((e) => e['kind'])
              .toSet(),
          {kind.name},
        );
        await c.createMonth('1405-09');
        expect(
          c
              .entriesFor('1405-09')
              .where((e) => e.purchaseId != null)
              .single
              .kind,
          kind,
        );
      }
    },
  );
  test('arithmetic formulas roundtrip and convert sheet units per operand', () {
    expect(scaleExpression('=8000+2600-25.5', 1000), '8000000+2600000-25500');
    expect(scaleExpression('۸۰۰۰۰۰۰+۲۶۰۰۰۰۰-۲۵۵۰۰', .001), '8000+2600-25.5');
    expect(scaleExpression('=SUM(B1:B4)', 1000), null);
  });
  test('amount and arithmetic expression merge as one monetary value', () {
    final merged = mergeDocuments(
      {
        'a': {'expected': 100, 'expectedExpression': '50+50'},
      },
      {
        'a': {'expected': 100, 'expectedExpression': '25+75'},
      },
      {
        'a': {'expected': 200, 'expectedExpression': '100+100'},
      },
    );
    expect(merged.entities['a']!['expected'], 100);
    expect(merged.conflicts.single['money'], true);
    expect(merged.conflicts.single['local'], {
      'value': 100,
      'expression': '25+75',
    });
  });
  test(
    'completed cards move after open cards while preserving relative order',
    () {
      Entry row(String id, bool done) => Entry(
        id: id,
        month: '1405-08',
        kind: Kind.fixed,
        title: id,
        done: done,
      );
      final entries = [
        row('a', true),
        row('b', false),
        row('c', true),
        row('d', false),
      ];
      expect(openFirst(entries).map((e) => e.id), ['b', 'd', 'a', 'c']);
      entries[0].done = false;
      expect(openFirst(entries).map((e) => e.id), ['a', 'b', 'd', 'c']);
    },
  );
}
