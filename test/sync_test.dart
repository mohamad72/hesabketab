import 'package:flutter_test/flutter_test.dart';
import 'package:hesab_hazrat/data/merge.dart';
import 'package:hesab_hazrat/data/sheet_codec.dart';

void main() {
  test('independent fields merge; same field retains both versions', () {
    final r = mergeDocuments(
      {
        'a': {'expected': 10, 'done': false},
      },
      {
        'a': {'expected': 20, 'done': false},
      },
      {
        'a': {'expected': 10, 'done': true},
      },
    );
    expect(r.entities['a'], {'expected': 20, 'done': true});
    expect(r.conflicts, isEmpty);
    final c = mergeDocuments(
      {
        'a': {'v': 1},
      },
      {
        'a': {'v': 2},
      },
      {
        'a': {'v': 3},
      },
    );
    expect(c.conflicts.single['local'], 2);
    expect(c.conflicts.single['remote'], 3);
  });
  test(
    'deletion versus edit conflicts; identical retries do not duplicate',
    () {
      expect(
        mergeDocuments(
          {
            'a': {'v': 1},
          },
          {},
          {
            'a': {'v': 2},
          },
        ).conflicts.single['field'],
        r'$record',
      );
      expect(
        mergeDocuments(
          {},
          {
            'a': {'v': 2},
          },
          {
            'a': {'v': 2},
          },
        ).entities.length,
        1,
      );
    },
  );
  test(
    'headers discover old shifted blocks and preserve formula expressions',
    () {
      Map<String, dynamic> str(String s) => {
        'userEnteredValue': {'stringValue': s},
        'effectiveValue': {'stringValue': s},
      };
      final rows = [
        {
          'values': [str('دریافتی ماه'), {}, {}, {}, str('هزینه های جاری')],
        },
        {
          'values': [
            str('عنوان'),
            str('انتظار'),
            str('واقعیت'),
            {},
            str('عنوان'),
            str('انتظار'),
            str('واقعیت'),
          ],
        },
        {
          'values': [
            str('حقوق'),
            {
              'effectiveValue': {'numberValue': 12.25},
            },
            {},
            {},
            str('اجاره'),
            {
              'effectiveValue': {'numberValue': 3},
            },
            {
              'userEnteredValue': {'formulaValue': '=1+1'},
              'effectiveValue': {'numberValue': 2},
            },
          ],
        },
      ];
      final p = SheetCodec(
        factor: 1000,
      ).parse(sheetId: 1, title: 'آبان 1405', rows: rows, namedRanges: []);
      expect(p.entries.length, 2);
      expect(p.entries.first.expected, 12250);
      expect(p.entries.last.actual, 2000);
      expect(p.bindings[p.entries.last.id]!['formulas']['actual'], '=1+1');
    },
  );
  test(
    'missing savings completion columns and bank block are discoverable',
    () {
      Map<String, dynamic> text(String s) => {
        'userEnteredValue': {'stringValue': s},
      };
      final parsed = SheetCodec().parse(
        sheetId: 1,
        title: 'آبان 1405',
        namedRanges: [],
        rows: [
          {
            'values': [text('پس اندازها')],
          },
          {
            'values': [text('عنوان'), text('انتظار'), text('واقعیت')],
          },
          {
            'values': [
              text('طلا'),
              {
                'userEnteredValue': {'numberValue': 10},
              },
            ],
          },
          {
            'values': [text('مجموع')],
          },
          {
            'values': [text('نام بانک'), text('موجودی')],
          },
          {
            'values': [
              text('ملی سارا'),
              {
                'userEnteredValue': {'numberValue': 12},
              },
            ],
          },
          {'values': []},
          {
            'values': [text('مجموع موجودی ها')],
          },
        ],
      );
      expect(parsed.blocks.first['done'], 3);
      expect(parsed.blocks.first['needsCompletion'], true);
      expect(parsed.blocks.last['kind'], 'bank');
      expect(parsed.blocks.last['end'], 7);
    },
  );
  test(
    'non-numeric titled rows remain occupied and account metadata survives',
    () {
      Map<String, dynamic> txt(String s) => {
        'userEnteredValue': {'stringValue': s},
      };
      final p = SheetCodec().parse(
        sheetId: 1,
        title: 'آبان 1405',
        namedRanges: [],
        metadata: {
          's1_bank_6': {
            'owner': 'سارا',
            'previousBalance': 100,
            'updatedAt': 'today',
          },
        },
        rows: [
          {
            'values': [txt('درآمدها')],
          },
          {
            'values': [txt('عنوان'), txt('انتظار'), txt('واقعیت')],
          },
          {
            'values': [txt('ردیف برنامه‌ریزی‌شده')],
          },
          {
            'values': [txt('مجموع')],
          },
          {'values': []},
          {
            'values': [txt('نام بانک'), txt('موجودی')],
          },
          {
            'values': [
              txt('ملی'),
              {
                'userEnteredValue': {'numberValue': 10},
              },
            ],
          },
          {
            'values': [txt('مجموع موجودی ها')],
          },
        ],
      );
      expect(p.blocks.first['occupied'], contains(2));
      expect(p.accounts.single['owner'], 'سارا');
      expect(p.accounts.single['previousBalance'], 100);
    },
  );
}
