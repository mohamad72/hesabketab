import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/finance.dart';
import 'google_auth.dart';
import 'merge.dart';
import 'sheet_codec.dart';

const defaultSpreadsheet =
    ''; // Private workbook IDs belong only in local settings.
const metadataTitle = '_hesab_hazrat_v1';

class RemoteSnapshot {
  Map<String, Json> entities = {}, bindings = {};
  List<Json> blocks = [];
  List<dynamic> names = [], sheets = [];
  int? metadataId;
}

class SheetsRemote {
  final GoogleAuth auth;
  final String spreadsheetId;
  final double factor;
  final http.Client client;
  SheetsRemote({
    GoogleAuth? auth,
    this.spreadsheetId = defaultSpreadsheet,
    this.factor = 1000,
    http.Client? client,
  }) : auth = auth ?? GoogleAuth(),
       client = client ?? http.Client();
  Map<String, String> _headers = {};
  Future<Json> request(
    String suffix, {
    Json? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.https(
      'sheets.googleapis.com',
      '/v4/spreadsheets/$spreadsheetId$suffix',
      query,
    );
    final response = body == null
        ? await client
              .get(uri, headers: _headers)
              .timeout(const Duration(seconds: 60))
        : await client
              .post(uri, headers: _headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'خطای گوگل‌شیت (${response.statusCode}). اطلاعات محلی و تغییرات ارسال‌نشده حفظ شدند.',
      );
    }
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  Future<void> batch(List<Json> requests) async {
    if (requests.isNotEmpty) {
      await request(':batchUpdate', body: {'requests': requests});
    }
  }

  Future<RemoteSnapshot> read({
    bool interactive = false,
    void Function(String)? progress,
  }) async {
    if (spreadsheetId.trim().isEmpty) {
      throw Exception('ابتدا شناسه یا لینک شیت شخصی را در تنظیمات وارد کنید.');
    }
    _headers = await auth.headers(interactive: interactive);
    final meta = await request(
      '',
      query: {'fields': 'sheets.properties,namedRanges'},
    );
    final result = RemoteSnapshot()
      ..sheets = meta['sheets'] ?? []
      ..names = meta['namedRanges'] ?? [];
    final extra = <String, Json>{};
    for (final sheet in result.sheets) {
      if (sheet['properties']['title'] == metadataTitle) {
        result.metadataId = sheet['properties']['sheetId'];
        final d = await request(
          '/values/${Uri.encodeComponent("'$metadataTitle'!A1:B${sheet['properties']['gridProperties']['rowCount']}")}',
        );
        for (final row in d['values'] ?? []) {
          if (row.length > 1 && row[0] != 'id') {
            try {
              extra['${row[0]}'] = Map<String, dynamic>.from(
                jsonDecode(row[1]),
              );
            } catch (_) {
              throw const FormatException(
                'متادیتای شیت قابل خواندن نیست؛ سینک متوقف شد.',
              );
            }
          }
        }
      }
    }
    result.entities.addAll(extra);
    for (final sheet in result.sheets) {
      final p = sheet['properties'], month = Month.parse(p['title']);
      if (month == null) continue;
      progress?.call('خواندن ${month.label}');
      final title = "'${(p['title'] as String).replaceAll("'", "''")}'";
      final cols = p['gridProperties']['columnCount'] as int;
      final range =
          '$title!A1:${column(cols - 1)}${p['gridProperties']['rowCount']}';
      final d = await request(
        '',
        query: {
          'ranges': range,
          'includeGridData': 'true',
          'fields':
              'sheets(data(rowData(values(userEnteredValue,effectiveValue,userEnteredFormat/backgroundColor,effectiveFormat/backgroundColor))))',
        },
      );
      final rows = d['sheets']?[0]?['data']?[0]?['rowData'] as List? ?? [];
      final parsed = SheetCodec(factor: factor).parse(
        sheetId: p['sheetId'],
        title: p['title'],
        rows: rows,
        namedRanges: result.names,
        metadata: extra,
      );
      final ids = {
        ...parsed.entries.map((e) => e.id),
        ...parsed.accounts.map((a) => a['id']),
      };
      // Entries in an existing tab are authoritative there; a deleted row must not
      // be resurrected from the metadata copy. Future occurrences have no tab yet.
      result.entities.removeWhere(
        (id, e) =>
            e['month'] == month.key &&
            (e['type'] == 'entry' || e['type'] == 'account') &&
            !ids.contains(id),
      );
      for (final e in parsed.entries) {
        result.entities[e.id] = {...e.toJson(), 'type': 'entry'};
      }
      for (final a in parsed.accounts) {
        result.entities[a['id']] = a;
      }
      result.entities['month_${month.key}'] = {
        ...?(extra['month_${month.key}']),
        'id': 'month_${month.key}',
        'type': 'month',
        'month': month.key,
      };
      result.bindings.addAll(parsed.bindings);
      result.blocks.addAll(parsed.blocks);
    }
    return result;
  }

  Future<bool> anchor(RemoteSnapshot snapshot) async {
    final requests = <Json>[];
    for (final pair in snapshot.bindings.entries) {
      if (snapshot.names.any((n) => n['name'] == 'hh_${pair.key}')) continue;
      final b = pair.value;
      requests.add({
        'addNamedRange': {
          'namedRange': {
            'name': 'hh_${pair.key}',
            'range': {
              'sheetId': b['sheetId'],
              'startRowIndex': b['row'],
              'endRowIndex': (b['row'] as int) + 1,
              'startColumnIndex': b['col'],
              'endColumnIndex': (b['col'] as int) + 1,
            },
          },
        },
      });
    }
    if (requests.isEmpty) return false;
    await batch(requests);
    return true;
  }

  static String column(int n) {
    var s = '';
    for (n++; n > 0; n = (n - 1) ~/ 26) {
      s = String.fromCharCode(65 + (n - 1) % 26) + s;
    }
    return s;
  }

  Json cellValue(dynamic v) => v == null
      ? {}
      : {
          'userEnteredValue': {
            if (v is bool)
              'boolValue': v
            else if (v is num)
              'numberValue': v
            else
              'stringValue': v,
          },
        };
  Json update(int sid, int row, int col, dynamic value) => {
    'updateCells': {
      'range': {
        'sheetId': sid,
        'startRowIndex': row,
        'endRowIndex': row + 1,
        'startColumnIndex': col,
        'endColumnIndex': col + 1,
      },
      'rows': [
        {
          'values': [cellValue(value)],
        },
      ],
      'fields': 'userEnteredValue',
    },
  };
  Json formula(int sid, int row, int col, String f) => {
    'updateCells': {
      'range': {
        'sheetId': sid,
        'startRowIndex': row,
        'endRowIndex': row + 1,
        'startColumnIndex': col,
        'endColumnIndex': col + 1,
      },
      'rows': [
        {
          'values': [
            {
              'userEnteredValue': {'formulaValue': f},
            },
          ],
        },
      ],
      'fields': 'userEnteredValue',
    },
  };
  List<Json> monthTemplate(int sid, String title) {
    final requests = <Json>[
      {
        'addSheet': {
          'properties': {
            'sheetId': sid,
            'title': title,
            'rightToLeft': true,
            'gridProperties': {'rowCount': 400, 'columnCount': 30},
          },
        },
      },
    ];
    for (final block in [
      (0, 0, 'درآمدها', true),
      (0, 5, 'هزینه های جاری', false),
      (0, 11, 'خرید های ماه', false),
      (105, 0, 'پس اندازها', false),
    ]) {
      final (r, c, label, income) = block;
      requests.add(update(sid, r, c, label));
      final headers = income
          ? ['عنوان', 'انتظار', 'واقعیت', '', 'درآمد مبنا']
          : ['عنوان', 'انتظار', 'واقعیت', 'انجام شده', 'مانده؟'];
      for (var i = 0; i < headers.length; i++) {
        requests.add(update(sid, r + 1, c + i, headers[i]));
      }
      final end = r == 0 && c > 0 ? 205 : r + 102;
      requests.add(update(sid, end, c, 'مجموع'));
      for (final offset in [1, 2, 4]) {
        requests.add(
          formula(
            sid,
            end,
            c + offset,
            '=SUM(${column(c + offset)}${r + 3}:${column(c + offset)}$end)',
          ),
        );
      }
    }
    requests.add(update(sid, 212, 0, 'عنوان حساب'));
    requests.add(update(sid, 212, 1, 'موجودی'));
    requests.add(update(sid, 312, 0, 'مجموع موجودی ها'));
    requests.add(formula(sid, 312, 1, '=SUM(B214:B312)'));
    return requests;
  }

  Future<void> write(Map<String, Json> desired, RemoteSnapshot remote) async {
    final requests = <Json>[];
    // Month creation uses deterministic IDs; re-reading after a lost response
    // discovers an already-created tab instead of creating a second one.
    final existing = {
      for (final s in remote.sheets)
        if (Month.parse(s['properties']['title']) != null)
          Month.parse(s['properties']['title'])!.key:
              s['properties']['sheetId'],
    };
    var created = false;
    for (final e in desired.values.where((e) => e['type'] == 'month')) {
      if (existing.containsKey(e['month'])) continue;
      final month = Month.key(e['month']),
          sid = 700000000 + int.parse(month.key.replaceAll('-', ''));
      requests.addAll(monthTemplate(sid, month.label));
      created = true;
    }
    if (created) {
      await batch(requests);
      requests.clear();
      remote = await read();
    }
    for (final block in remote.blocks.where(
      (b) => b['needsCompletion'] == true,
    )) {
      final sid = block['sheetId'] as int, header = block['header'] as int;
      requests.add(update(sid, header, block['done'], 'انجام شده'));
      requests.add(update(sid, header, block['remaining'], 'مانده؟'));
      for (var r = header + 1; r < (block['end'] as int); r++) {
        final ex = column(block['expected']),
            ac = column(block['actual']),
            done = column(block['done']);
        requests.add(
          formula(
            sid,
            r,
            block['remaining'],
            '=IF($done${r + 1},0,MAX($ex${r + 1}-$ac${r + 1},0))',
          ),
        );
      }
    }
    final occupied = <String>{
      for (final b in remote.bindings.values)
        '${b['sheetId']}_${b['row']}_${b['col']}',
      for (final block in remote.blocks)
        for (final r in block['occupied'] ?? [])
          '${block['sheetId']}_${r}_${block['col']}',
    };
    for (final id in {...remote.entities.keys, ...desired.keys}) {
      final old = remote.entities[id], e = desired[id];
      if (e != null && e['type'] != 'entry' && e['type'] != 'account') continue;
      if (e == null && old?['type'] != 'entry' && old?['type'] != 'account') {
        continue;
      }
      var b = remote.bindings[id];
      final moved =
          b != null &&
          e != null &&
          (e['month'] != old?['month'] || e['kind'] != old?['kind']);
      if (moved || e == null) {
        if (b != null) {
          for (final col in {
            b['col'],
            b['expected'],
            b['actual'],
            b['done'],
            b['balance'],
          }.whereType<int>()) {
            requests.add(update(b['sheetId'], b['row'], col, null));
          }
          for (final n in remote.names.where((n) => n['name'] == 'hh_$id')) {
            requests.add({
              'deleteNamedRange': {'namedRangeId': n['namedRangeId']},
            });
          }
          b = null;
        }
        if (e == null) continue;
      }
      if (b == null) {
        if (!existing.containsKey(e['month']) && !created) {
          continue; // future installment stays in metadata
        }
        final sid = remote.sheets
            .where(
              (s) => Month.parse(s['properties']['title'])?.key == e['month'],
            )
            .map((s) => s['properties']['sheetId'])
            .firstOrNull;
        if (sid == null) continue;
        if (e['type'] == 'entry') {
          final block = remote.blocks
              .where((b) => b['sheetId'] == sid && b['kind'] == e['kind'])
              .firstOrNull;
          if (block == null) {
            throw Exception(
              'بخش ${e['kind']} در این ماه پیدا نشد؛ برای حفظ ساختار شیت، نوشتن متوقف شد.',
            );
          }
          int? row;
          for (
            var r = (block['header'] as int) + 1;
            r < (block['end'] as int);
            r++
          ) {
            if (!occupied.contains('${sid}_${r}_${block['col']}')) {
              row = r;
              break;
            }
          }
          if (row == null) {
            throw Exception(
              'بخش این ماه جای خالی ندارد؛ یک سطر خالی داخل بخش شیت اضافه کنید.',
            );
          }
          b = {...block, 'row': row, 'formulas': <String, String>{}};
        } else {
          final block = remote.blocks
              .where((b) => b['sheetId'] == sid && b['kind'] == 'bank')
              .firstOrNull;
          if (block == null) {
            throw Exception(
              'بخش حساب‌ها در این ماه شناسایی نشد؛ نوشتن متوقف شد.',
            );
          }
          int? row;
          for (
            var r = (block['header'] as int) + 1;
            r < (block['end'] as int);
            r++
          ) {
            if (!occupied.contains('${sid}_${r}_${block['col']}')) {
              row = r;
              break;
            }
          }
          if (row == null) {
            throw Exception(
              'بخش حساب‌ها جای خالی ندارد. یک ردیف خالی پیش از جمع حساب‌ها اضافه کنید.',
            );
          }
          b = {...block, 'row': row, 'formulas': <String, String>{}};
          requests.add(update(sid, row, b['col'], e['title']));
        }
        occupied.add('${b['sheetId']}_${b['row']}_${b['col']}');
      }
      final sid = b['sheetId'] as int,
          row = b['row'] as int,
          col = b['col'] as int;
      if (!remote.names.any((n) => n['name'] == 'hh_$id') || moved) {
        requests.add({
          'addNamedRange': {
            'namedRange': {
              'name': 'hh_$id',
              'range': {
                'sheetId': sid,
                'startRowIndex': row,
                'endRowIndex': row + 1,
                'startColumnIndex': col,
                'endColumnIndex': col + 1,
              },
            },
          },
        });
      }
      if (e['type'] == 'entry') {
        final entry = Entry.fromJson(e);
        if (old == null ||
            moved ||
            ['title', 'day'].any((f) => !same(e[f], old[f]))) {
          requests.add(update(sid, row, col, sheetTitle(entry)));
        }
        for (final field in ['expected', 'actual', 'done']) {
          final target = b[field] as int?;
          if (target == null) continue;
          if (old != null &&
              !moved &&
              same(e[field], old[field]) &&
              same(e['${field}Expression'], old['${field}Expression'])) {
            continue;
          }
          if ((b['formulas'] as Map?)?.containsKey(field) == true) {
            if (entry.isDaily && field == 'actual') continue;
            if (scaleExpression(b['formulas'][field], 1) == null) {
              throw Exception(
                '«${entry.title}» فرمول ارجاعی دارد؛ فرمول را در شیت ویرایش کنید.',
              );
            }
          }
          final expression = e['${field}Expression'] as String?;
          if (expression != null &&
              scaleExpression(expression, 1 / factor) != null) {
            requests.add(
              formula(
                sid,
                row,
                target,
                '=${scaleExpression(expression, 1 / factor)}',
              ),
            );
          } else {
            requests.add(
              update(
                sid,
                row,
                target,
                e[field] is num ? (e[field] as num) / factor : e[field],
              ),
            );
          }
        }
        if (old == null || moved || !same(e['review'], old['review'])) {
          final failed = e['review'] == 'failed';
          requests.add({
            'repeatCell': {
              'range': {
                'sheetId': sid,
                'startRowIndex': row,
                'endRowIndex': row + 1,
                'startColumnIndex': col,
                'endColumnIndex': col + 1,
              },
              'cell': {
                'userEnteredFormat': {
                  'backgroundColor': failed
                      ? {'red': 1.0, 'green': 0.6, 'blue': 0.0}
                      : {'red': 1.0, 'green': 1.0, 'blue': 1.0},
                },
              },
              'fields': 'userEnteredFormat.backgroundColor',
            },
          });
        }
        if (old == null || moved) {
          final ex = column(b['expected']), ac = column(b['actual']);
          if (entry.kind == Kind.income) {
            requests.add(
              formula(
                sid,
                row,
                col + 4,
                '=IF(ISBLANK($ac${row + 1}),$ex${row + 1},$ac${row + 1})',
              ),
            );
          } else if (b['remaining'] != null) {
            final done = column(b['done']);
            requests.add(
              formula(
                sid,
                row,
                b['remaining'],
                '=IF($done${row + 1},0,MAX($ex${row + 1}-$ac${row + 1},0))',
              ),
            );
          }
        }
      } else if (old == null || !same(e['balance'], old['balance'])) {
        if ((b['formulas'] as Map?)?.containsKey('balance') == true) {
          throw Exception('موجودی این حساب فرمول دارد؛ در شیت ویرایش کنید.');
        }
        requests.add(
          update(sid, row, b['balance'], (e['balance'] as num) / factor),
        );
      }
    }
    // A separate generated service-total table avoids double-counting the
    // first installment or assigning legacy lump sums to invented purchases.
    final totals = installmentSummaries(
      desired.values.where((e) => e['type'] == 'entry').map(Entry.fromJson),
    );
    if (totals.isNotEmpty ||
        remote.sheets.any((s) => s['properties']['title'] == '_اقساط_حضرات')) {
      const title = '_اقساط_حضرات';
      final prior = remote.sheets
          .where((s) => s['properties']['title'] == title)
          .firstOrNull;
      final sid = prior?['properties']['sheetId'] as int? ?? 699999998;
      if (prior == null) {
        requests.add({
          'addSheet': {
            'properties': {
              'sheetId': sid,
              'title': title,
              'rightToLeft': true,
              'gridProperties': {
                'rowCount': totals.length + 100,
                'columnCount': 6,
              },
            },
          },
        });
      } else {
        final count = prior['properties']['gridProperties']['rowCount'] as int;
        if (count < totals.length + 1) {
          requests.add({
            'appendDimension': {
              'sheetId': sid,
              'dimension': 'ROWS',
              'length': totals.length + 100 - count,
            },
          });
        }
      }
      final rows = <Json>[
        {
          'values': [
            'ماه',
            'ارائه‌دهنده',
            'جمع انتظار (واحد شیت)',
            'جمع واقعیت',
            'باقی‌مانده',
            'خریدهای مرتبط؛ بدون قسط اول',
          ].map(cellValue).toList(),
        },
      ];
      for (final total in totals) {
        rows.add({
          'values': [
            Month.key(total['month']).label,
            total['provider'],
            (total['expected'] as num) / factor,
            (total['actual'] as num) / factor,
            (total['remaining'] as num) / factor,
            (total['items'] as List).join(' | '),
          ].map(cellValue).toList(),
        });
      }
      requests.add({
        'updateCells': {
          'range': {
            'sheetId': sid,
            'startRowIndex': 0,
            'startColumnIndex': 0,
            'endColumnIndex': 6,
          },
          'rows': rows,
          'fields': 'userEnteredValue',
        },
      });
    }
    final metaId = remote.metadataId ?? 699999999;
    if (remote.metadataId == null) {
      requests.add({
        'addSheet': {
          'properties': {
            'sheetId': metaId,
            'title': metadataTitle,
            'hidden': true,
            'gridProperties': {
              'rowCount': desired.length + 100,
              'columnCount': 2,
            },
          },
        },
      });
    } else {
      final size =
          remote.sheets.firstWhere(
                (s) => s['properties']['sheetId'] == metaId,
              )['properties']['gridProperties']['rowCount']
              as int;
      if (size < desired.length + 1) {
        requests.add({
          'appendDimension': {
            'sheetId': metaId,
            'dimension': 'ROWS',
            'length': desired.length + 100 - size,
          },
        });
      }
    }
    requests.add({
      'updateCells': {
        'range': {
          'sheetId': metaId,
          'startRowIndex': 0,
          'startColumnIndex': 0,
          'endColumnIndex': 2,
        },
        'rows': [
          {
            'values': [cellValue('id'), cellValue('json')],
          },
          ...desired.entries.map(
            (e) => {
              'values': [cellValue(e.key), cellValue(jsonEncode(e.value))],
            },
          ),
        ],
        'fields': 'userEnteredValue',
      },
    });
    await batch(requests);
  }
}
