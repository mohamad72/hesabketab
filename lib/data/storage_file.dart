import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../domain/finance.dart';

class LocalStore {
  Future<File> get file async =>
      File('${(await getApplicationSupportDirectory()).path}/finance-v1.json');
  Future<Json?> read() async {
    final f = await file;
    for (final path in [f.path, '${f.path}.bak']) {
      final candidate = File(path);
      if (!await candidate.exists()) continue;
      try {
        return Map<String, dynamic>.from(
          jsonDecode(await candidate.readAsString()),
        );
      } catch (_) {
        continue;
      }
    }
    if (await f.exists()) {
      throw const FormatException(
        'فایل ذخیره خراب است؛ برای جلوگیری از حذف اطلاعات، بازنشانی انجام نشد.',
      );
    }
    return null;
  }

  Future<void> write(Json document) async {
    final f = await file;
    await f.parent.create(recursive: true);
    final temp = File('${f.path}.tmp');
    await temp.writeAsString(jsonEncode(document), flush: true);
    if (await f.exists()) await f.copy('${f.path}.bak');
    await temp.rename(f.path);
  }
}
