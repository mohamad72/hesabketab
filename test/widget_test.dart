import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesab_hazrat/data/controller.dart';
import 'package:hesab_hazrat/data/demo.dart';
import 'package:hesab_hazrat/main.dart';
import 'package:hesab_hazrat/ui/entry_form.dart';
import 'package:hesab_hazrat/domain/finance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets(
    'four peer tabs, navigation and reports render at narrow Android width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = demoController();
      await tester.pumpWidget(HesabApp(controller: c, demo: true));
      await tester.pumpAndSettle();
      expect(find.text('درآمدها'), findsOneWidget);
      expect(find.text('پس‌انداز'), findsOneWidget);
      expect(find.text('هزینه‌های خاص'), findsOneWidget);
      await tester.tap(find.text('گزارش‌ها').last);
      await tester.pumpAndSettle();
      expect(find.text('آیندهٔ موجودی'), findsOneWidget);
      await tester.tap(find.text('حساب‌ها').last);
      await tester.pumpAndSettle();
      expect(find.text('موجودی حساب‌ها'), findsOneWidget);
      await tester.tap(find.text('تنظیمات').last);
      await tester.pumpAndSettle();
      expect(find.text('اتصال به گوگل‌شیت'), findsOneWidget);
    },
  );
  testWidgets('saving form persists explicit zero without any note input', (
    tester,
  ) async {
    final c = FinanceController(saveDocument: (_) async {});
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: EntryForm(controller: c, kind: Kind.saving),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'طلا');
    await tester.enterText(find.byType(TextFormField).at(1), '1000000');
    await tester.enterText(find.byType(TextFormField).at(2), '0');
    expect(find.textContaining('یادداشت'), findsNothing);
    await tester.ensureVisible(find.text('ذخیرهٔ تغییرات'));
    await tester.tap(find.text('ذخیرهٔ تغییرات'));
    await tester.pumpAndSettle();
    expect(c.entries.single.actual, 0);
    expect(c.entries.single.kind, Kind.saving);
  });
  testWidgets('capture Persian mobile preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final regular = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn.ttf'));
    await regular.load();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: HesabApp(controller: demoController(), demo: true),
      ),
    );
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('SCREENSHOT')) {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/screenshots').create(recursive: true);
        await File(
          'docs/screenshots/monthly.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }
  });
  testWidgets(
    'month creation is at top and installments are chosen inside add expense',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        HesabApp(controller: demoController(), demo: true),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('ساخت ماه جدید')).dy, lessThan(230));
      expect(find.text('ثبت خرید قسطی'), findsNothing);
      final previous = find.byTooltip('ماه قبل');
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: previous, matching: find.byType(Icon)),
            )
            .textDirection,
        TextDirection.ltr,
      );
      await tester.ensureVisible(find.text('افزودن'));
      await tester.tap(find.text('افزودن'));
      await tester.pumpAndSettle();
      expect(find.text('یک‌جا'), findsOneWidget);
      await tester.tap(find.text('قسطی'));
      await tester.pumpAndSettle();
      expect(find.text('بخش ثبت هر چهار قسط'), findsOneWidget);
    },
  );
  testWidgets('editing title keeps locked reference formulas untouched', (
    tester,
  ) async {
    final c = FinanceController(saveDocument: (_) async {});
    final e = Entry(
      id: 'formula',
      month: c.selectedMonth,
      kind: Kind.income,
      title: 'درآمد',
      expected: 100,
    );
    c.bindings[e.id] = {
      'formulas': {'expected': '=SUM(B1:B4)'},
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: EntryForm(controller: c, entry: e),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'درآمد اصلاح‌شده');
    await tester.ensureVisible(find.text('ذخیرهٔ تغییرات'));
    await tester.tap(find.text('ذخیرهٔ تغییرات'));
    await tester.pumpAndSettle();
    expect(c.entries.single.expectedExpression, null);
    expect(c.entries.single.expected, 100);
  });
}
