import 'dart:convert';
import 'package:web/web.dart' as web;
import '../domain/finance.dart';

class LocalStore {
  Future<Json?> read() async {
    final value = web.window.localStorage.getItem('hesab-hazrat-v1');
    return value == null ? null : Map<String, dynamic>.from(jsonDecode(value));
  }

  Future<void> write(Json document) async {
    web.window.localStorage.setItem('hesab-hazrat-v1', jsonEncode(document));
  }
}
