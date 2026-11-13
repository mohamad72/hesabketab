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
    for (final field in {...?b?.keys, ...l.keys, ...r.keys}) {
      final bv = b?[field], lv = l[field], rv = r[field];
      if (same(lv, rv) || same(rv, bv)) {
        merged[field] = lv;
      } else if (same(lv, bv)) {
        merged[field] = rv;
      } else {
        merged[field] = lv;
        conflicts.add({
          'id': id,
          'field': field,
          'base': bv,
          'local': lv,
          'remote': rv,
        });
      }
    }
    result[id] = merged;
  }
  return MergeResult(result, conflicts);
}
