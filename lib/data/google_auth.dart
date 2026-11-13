import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class GoogleAuth {
  static const channel = MethodChannel('ir.hazrat.hesab_hazrat/google');
  Future<Map<String, String>> headers({bool interactive = false}) async {
    if (kIsWeb) {
      throw Exception(
        'اتصال گوگل در نسخهٔ اندروید فعال است. مرورگر پیش‌نمایش رابط و کار آفلاین است.',
      );
    }
    final token = await channel.invokeMethod<String>('authorize', {
      'interactive': interactive,
    });
    if (token == null) {
      throw Exception('برای همگام‌سازی، حساب گوگل را متصل کنید.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<void> signOut() async {
    if (!kIsWeb) await channel.invokeMethod<void>('signOut');
  }
}
