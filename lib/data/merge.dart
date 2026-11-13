import 'dart:convert';
import '../domain/finance.dart';

bool same(dynamic a, dynamic b) => jsonEncode(a) == jsonEncode(b);

class MergeResult {
  final Map<String, Json> entities;
  final List<Json> conflicts;
  MergeResult(this.entities, this.conflicts);
}

MergeResult mergeDocuments(
  Map<String, Json> base,
  Map<String, Json> local,
  Map<String, Json> remote,
) {
  final result = <String, Json>{}, conflicts = <Json>[];
  for (final id in {...base.keys, ...local.keys, ...remote.keys}) {
    final b = base[id], l = local[id], r = remote[id];
    if (same(l, r)) {
      if (l != null) result[id] = Map.of(l);
      continue;
    }
    if (same(l, b)) {
      if (r != null) result[id] = Map.of(r);
      continue;
    }
    if (same(r, b)) {
      if (l != null) result[id] = Map.of(l);
      continue;
    }
    if (l == null || r == null) {
      conflicts.add({
        'id': id,
        'field': r'$record',
        'base': b,
        'local': l,
        'remote': r,
      });
      if (l != null) result[id] = Map.of(l);
      continue;
    }
    final merged = <String, dynamic>{};
    bool monetary(String field) =>
        ['expected', 'actual'].contains(field) &&
        [b, l, r].any((m) => m?.containsKey('${field}Expression') == true);
    for (final field in {...?b?.keys, ...l.keys, ...r.keys}) {
      if (field.endsWith('Expression') &&
          monetary(field.replaceFirst('Expression', ''))) {
        continue;
      }
      final money = monetary(field);
      dynamic read(Json? m) => money
          ? {'value': m?[field], 'expression': m?['${field}Expression']}
          : m?[field];
      final bv = read(b), lv = read(l), rv = read(r);
      dynamic chosen;
      if (same(lv, rv) || same(rv, bv)) {
        chosen = lv;
      } else if (same(lv, bv)) {
        chosen = rv;
      } else {
        chosen = lv;
        conflicts.add({
          'id': id,
          'field': field,
          if (money) 'money': true,
          'base': bv,
          'local': lv,
          'remote': rv,
        });
      }
      if (money) {
        merged[field] = chosen['value'];
        merged['${field}Expression'] = chosen['expression'];
      } else {
        merged[field] = chosen;
      }
    }
    result[id] = merged;
  }
  return MergeResult(result, conflicts);
}
