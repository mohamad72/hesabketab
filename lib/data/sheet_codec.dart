import '../domain/finance.dart';

class ParsedSheet {
  final List<Entry> entries = [];
  final List<Json> accounts = [];
  final Map<String, Json> bindings = {};
  final List<Json> blocks = [];
}

class SheetCodec {
  final double factor;
  SheetCodec({this.factor = 1000});
  dynamic value(Json c) {
    final v = (c['effectiveValue'] ?? c['userEnteredValue'] ?? {}) as Map;
    return v['stringValue'] ?? v['numberValue'] ?? v['boolValue'];
  }

  ParsedSheet parse({
    required int sheetId,
    required String title,
    required List<dynamic> rows,
    required List<dynamic> namedRanges,
    Map<String, Json> metadata = const {},
  }) {
    final parsed = ParsedSheet(), month = Month.parse(title);
    if (month == null) return parsed;
    Json cell(int r, int c) {
      if (r >= rows.length || c < 0) return {};
      final vs = rows[r]['values'] as List? ?? [];
      return c < vs.length ? Map<String, dynamic>.from(vs[c]) : {};
    }

    String text(int r, int c) => '${value(cell(r, c)) ?? ''}';
    String idAt(int r, int c, String fallback) {
      for (final n in namedRanges) {
        final range = n['range'];
        if (range != null &&
            range['sheetId'] == sheetId &&
            range['startRowIndex'] == r &&
            range['startColumnIndex'] == c &&
            '${n['name']}'.startsWith('hh_')) {
          return '${n['name']}'.substring(3);
        }
      }
      return fallback;
    }

    for (var row = 0; row < rows.length; row++) {
      final vs = rows[row]['values'] as List? ?? [];
      for (var col = 0; col < vs.length; col++) {
        final heading = normal(text(row, col));
        Kind? kind;
        if (heading == 'درآمدها' || heading == 'دریافتیماه') kind = Kind.income;
        if (heading == 'هزینههایجاری' || heading == 'هزینههایثابت') {
          kind = Kind.fixed;
        }
        if (heading == 'خریدهایماه' || heading == 'هزینههایخاص') {
          kind = Kind.special;
        }
        if (heading == 'پس اندازها'.replaceAll(' ', '') ||
            heading == 'پسانداز') {
          kind = Kind.saving;
        }
        if (kind == null) continue;
        int header = row + 1;
        int? ex, ac, dn, rem;
        for (var c = col + 1; c < col + 6; c++) {
          final h = normal(text(header, c));
          if (h == 'عنوان') break;
          if (h == 'انتظار') ex = c;
          if (h == 'واقعیت') ac = c;
          if (h == 'انجامشده' || h == 'تمامشد') dn = c;
          if (h.contains('مانده')) rem = c;
        }
        if (ex == null || ac == null) continue;
        final needsCompletion =
            kind == Kind.saving &&
            dn == null &&
            rem == null &&
            text(header, col + 3).isEmpty &&
            text(header, col + 4).isEmpty;
        if (needsCompletion) {
          dn = col + 3;
          rem = col + 4;
        }
        var end = header + 1;
        for (; end < rows.length; end++) {
          final t = text(end, col).trim(), n = normal(t);
          if (n.startsWith('مجموع') ||
              n.startsWith('جمع') ||
              n.contains('پساندازها') ||
              normal(text(end, ex)) == 'موجودی' ||
              n == 'عنوان') {
            break;
          }
          final formula =
              (cell(end, ex)['userEnteredValue'] as Map?)?['formulaValue'];
          if (t.isEmpty &&
              formula != null &&
              '$formula'.toUpperCase().contains('SUM(')) {
            break;
          }
          if (t.isEmpty) continue;

          final id = idAt(end, col, 's${sheetId}_${kind.name}_$end'),
              prior = metadata[id];
          final split = prior != null && t == sheetTitle(Entry.fromJson(prior))
              ? (prior['title'] as String, prior['day'] as int?)
              : splitTitleDay(t);
          final bg =
              cell(end, col)['effectiveFormat']?['backgroundColor'] ??
              cell(end, col)['userEnteredFormat']?['backgroundColor'] ??
              {};
          final failed =
              (bg['red'] ?? 0) > 0.9 &&
              (bg['green'] ?? 0) > 0.3 &&
              (bg['green'] ?? 0) < 0.8 &&
              (bg['blue'] ?? 0) < 0.4;
          final e = prior != null
              ? Entry.fromJson(prior)
              : Entry(id: id, month: month.key, kind: kind, title: split.$1);
          e.month = month.key;
          e.kind = kind;
          e.title = split.$1;
          e.day = split.$2;
          e.expected =
              (value(cell(end, ex)) is num ? value(cell(end, ex)) as num : 0)
                  .toDouble() *
              factor;
          e.actual =
              (value(cell(end, ac)) is num ? value(cell(end, ac)) as num : null)
                  ?.toDouble();
          if (e.actual != null) e.actual = e.actual! * factor;
          if (dn != null) e.done = value(cell(end, dn)) == true;
          if (failed) {
            e.review = Review.failed;
          } else if (e.review == Review.failed) {
            e.review = Review.planned;
          }
          parsed.entries.add(e);
          final formulas = <String, String>{};
          for (final field in {'expected': ex, 'actual': ac}.entries) {
            final f = cell(
              end,
              field.value,
            )['userEnteredValue']?['formulaValue'];
            if (f != null) formulas[field.key] = f;
          }
          parsed.bindings[id] = {
            'sheetId': sheetId,
            'row': end,
            'col': col,
            'expected': ex,
            'actual': ac,
            'done': dn,
            'remaining': rem,
            'kind': kind.name,
            'formulas': formulas,
            'color': bg,
          };
        }
        parsed.blocks.add({
          'sheetId': sheetId,
          'kind': kind.name,
          'needsCompletion': needsCompletion,
          'occupied': [
            for (var r = header + 1; r < end; r++)
              if ([
                col,
                ex,
                ac,
              ].any((c) => cell(r, c)['userEnteredValue'] != null))
                r,
          ],
          'col': col,
          'header': header,
          'end': end,
          'expected': ex,
          'actual': ac,
          'done': dn,
          'remaining': rem,
        });
      }
    }
    // Bank block is detected by its own amount header, never by a fixed row.
    for (var r = 0; r < rows.length; r++) {
      final vs = rows[r]['values'] as List? ?? [];
      for (var c = 1; c < vs.length; c++) {
        if (normal(text(r, c)) != 'موجودی') continue;
        var bankEnd = rows.length;
        for (var rr = r + 1; rr < rows.length; rr++) {
          final t = text(rr, c - 1).trim();
          if (normal(t).startsWith('مجموع') || normal(t).startsWith('جمع')) {
            bankEnd = rr;
            break;
          }
          if (t.isEmpty) continue;
          final v = value(cell(rr, c));
          if (v is! num) continue;
          final id = idAt(rr, c - 1, 's${sheetId}_bank_$rr');
          parsed.accounts.add({
            ...?metadata[id],
            'id': id,
            'type': 'account',
            'month': month.key,
            'title': t,
            'owner': t.contains('سارا')
                ? 'سارا'
                : t.contains('محمد')
                ? 'محمد'
                : metadata[id]?['owner'] ?? 'سایر',
            'balance': v.toDouble() * factor,
          });
          parsed.bindings[id] = {
            'sheetId': sheetId,
            'row': rr,
            'col': c - 1,
            'balance': c,
            'formulas': {
              if (cell(rr, c)['userEnteredValue']?['formulaValue'] != null)
                'balance': cell(rr, c)['userEnteredValue']['formulaValue'],
            },
          };
        }
        parsed.blocks.add({
          'sheetId': sheetId,
          'kind': 'bank',
          'occupied': [
            for (var rr = r + 1; rr < bankEnd; rr++)
              if (cell(rr, c - 1)['userEnteredValue'] != null ||
                  cell(rr, c)['userEnteredValue'] != null)
                rr,
          ],
          'header': r,
          'end': bankEnd,
          'col': c - 1,
          'balance': c,
        });
      }
    }
    return parsed;
  }
}
