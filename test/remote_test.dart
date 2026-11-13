import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hesab_hazrat/data/sheets_remote.dart';
import 'package:hesab_hazrat/domain/finance.dart';

void main() {
  test(
    'initial import anchors write identity only and retry is idempotent',
    () async {
      final batches = <List<dynamic>>[];
      final remote = SheetsRemote(
        client: MockClient((req) async {
          batches.add(jsonDecode(req.body)['requests']);
          return http.Response('{}', 200);
        }),
      );
      final snapshot = RemoteSnapshot()
        ..bindings = {
          'record': {'sheetId': 1, 'row': 2, 'col': 5},
        };
      expect(await remote.anchor(snapshot), true);
      expect(batches.single.single.keys, ['addNamedRange']);
      snapshot.names = [
        {'name': 'hh_record'},
      ];
      expect(await remote.anchor(snapshot), false);
      expect(batches.length, 1);
    },
  );
  test(
    'writer reserves raw occupied rows and preserves daily formula while updating account input',
    () async {
      List<dynamic> requests = [];
      final remote = SheetsRemote(
        client: MockClient((req) async {
          requests = jsonDecode(req.body)['requests'];
          return http.Response('{}', 200);
        }),
      );
      final daily = Entry(
        id: 'daily',
        month: '1405-08',
        kind: Kind.fixed,
        title: dailyTitle,
        expected: 100,
        actual: 20,
      );
      final fresh = Entry(
        id: 'newrecord',
        month: '1405-08',
        kind: Kind.fixed,
        title: 'جدید',
        expected: 50,
      );
      final old = {...daily.toJson(), 'actual': 10.0, 'type': 'entry'};
      final snapshot = RemoteSnapshot()
        ..sheets = [
          {
            'properties': {'sheetId': 1, 'title': 'آبان 1405'},
          },
        ]
        ..entities = {
          'daily': old,
          'bank': {
            'id': 'bank',
            'type': 'account',
            'month': '1405-08',
            'title': 'ملی',
            'owner': 'سارا',
            'balance': 100.0,
          },
        }
        ..bindings = {
          'daily': {
            'sheetId': 1,
            'row': 3,
            'col': 5,
            'expected': 6,
            'actual': 7,
            'done': 8,
            'remaining': 9,
            'formulas': {'actual': '=B50-B49'},
          },
          'bank': {
            'sheetId': 1,
            'row': 20,
            'col': 0,
            'balance': 1,
            'formulas': {},
          },
        }
        ..blocks = [
          {
            'sheetId': 1,
            'kind': 'fixed',
            'header': 1,
            'end': 9,
            'col': 5,
            'expected': 6,
            'actual': 7,
            'done': 8,
            'remaining': 9,
            'occupied': [2, 3],
          },
        ];
      await remote.write({
        'daily': {...daily.toJson(), 'type': 'entry'},
        'newrecord': {...fresh.toJson(), 'type': 'entry'},
        'bank': {...snapshot.entities['bank']!, 'balance': 90.0},
      }, snapshot);
      final updates = requests
          .where((r) => r['updateCells'] != null)
          .map((r) => r['updateCells'])
          .toList();
      expect(
        updates.any(
          (u) =>
              u['range']['startRowIndex'] == 3 &&
              u['range']['startColumnIndex'] == 7,
        ),
        false,
      );
      expect(
        updates.any(
          (u) =>
              u['range']['startRowIndex'] == 4 &&
              u['range']['startColumnIndex'] == 5,
        ),
        true,
      );
      expect(
        updates.any(
          (u) =>
              u['range']['startRowIndex'] == 20 &&
              u['range']['startColumnIndex'] == 1,
        ),
        true,
      );
    },
  );
}
