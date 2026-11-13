import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/controller.dart';
import '../data/google_auth.dart';
import '../domain/finance.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  final FinanceController controller;
  final bool demo;
  const SettingsPage({super.key, required this.controller, this.demo = false});
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'تنظیمات',
          caption: 'اطلاعاتت روی دستگاه؛ نسخهٔ پشتیبان در شیت خودت',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_outlined, color: purple),
                  SizedBox(width: 10),
                  Text(
                    'اتصال به گوگل‌شیت',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                c.syncMessage,
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 8),
              Text(
                '${persian(c.pending)} تغییر در انتظار ارسال',
                style: const TextStyle(color: purple, fontSize: 12),
              ),
              if (c.lastSync != null)
                Text(
                  'آخرین سینک موفق: ${persian(c.lastSync!.toLocal().toString().substring(0, 16))}',
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  c.syncing
                      ? 'در حال همگام‌سازی…'
                      : 'ورود با گوگل و همگام‌سازی',
                  icon: Icons.sync,
                  onPressed: c.syncing || demo
                      ? null
                      : () =>
                            runAction(context, () => c.sync(interactive: true)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: demo
                    ? null
                    : () => runAction(
                        context,
                        () => GoogleAuth().signOut(),
                        success:
                            'مجوز گوگل لغو شد؛ اطلاعات محلی همچنان در دسترس است.',
                      ),
                child: const Text('قطع اتصال گوگل'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'واحد مبلغ در شیت',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'ورودی و نمایش اپ همیشه تومان است. تغییر واحد فقط پیش از نخستین دریافت مجاز است تا مبلغ‌ها اشتباه تبدیل نشوند.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                isExpanded: true,
                initialValue: c.sheetFactor,
                decoration: const InputDecoration(
                  labelText: 'هر واحد شیت برابر است با',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 1000,
                    child: Text('۱٬۰۰۰ تومان (هزار تومان)'),
                  ),
                  DropdownMenuItem(value: 1, child: Text('۱ تومان')),
                ],
                onChanged: c.base.isNotEmpty || demo
                    ? null
                    : (v) => runAction(
                        context,
                        () => c.change(() => c.sheetFactor = v!),
                      ),
              ),
              const SizedBox(height: 16),
              const Text(
                'شیت متصل',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 4),
              _SpreadsheetSetup(controller: c),
            ],
          ),
        ),
        if (c.conflicts.isNotEmpty) ...[
          const SectionTitle(
            'اختلاف‌های همگام‌سازی',
            caption: 'هر دو نسخه حفظ شده‌اند؛ برای هر مورد انتخاب کن.',
          ),
          ...c.conflicts.map(
            (conflict) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                color: peach,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${c.entities[conflict['id']]?['title'] ?? conflict['id']} · ${_field(conflict['field'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'گوشی: ${_display(conflict['local'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'شیت: ${_display(conflict['remote'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: [
                        FilledButton(
                          onPressed: () => runAction(
                            context,
                            () => c.resolve(conflict, true),
                          ),
                          child: const Text('نسخهٔ گوشی'),
                        ),
                        OutlinedButton(
                          onPressed: () => runAction(
                            context,
                            () => c.resolve(conflict, false),
                          ),
                          child: const Text('نسخهٔ شیت'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'پشتیبان محلی',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'خروجی شامل اطلاعات مالی است. آن را در محل شخصی خودت نگه دار.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: const JsonEncoder.withIndent(
                        '  ',
                      ).convert(c.document()),
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('پشتیبان در کلیپ‌بورد کپی شد.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('کپی خروجی JSON'),
              ),
              TextButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) {
                    final input = TextEditingController();
                    return AlertDialog(
                      title: const Text('بازیابی پشتیبان محلی'),
                      content: TextField(
                        controller: input,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'محتوای JSON را اینجا قرار بده',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('انصراف'),
                        ),
                        FilledButton(
                          onPressed: () async {
                            try {
                              final doc = jsonDecode(input.text) as Json;
                              if (doc['version'] != 1 ||
                                  doc['entities'] is! Map) {
                                throw const FormatException(
                                  'ساختار پشتیبان معتبر نیست',
                                );
                              }
                              await c.change(() => c.restore(doc));
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('بازیابی انجام نشد: $e'),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('جایگزینی اطلاعات محلی'),
                        ),
                      ],
                    );
                  },
                ),
                icon: const Icon(Icons.restore_rounded),
                label: const Text('بازیابی از JSON'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'حساب حضرات\nنسخهٔ ۱.۰.۰ · ساخته‌شده برای روزهای روشن‌تر',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }

  String _field(String field) =>
      {
        'expected': 'انتظار',
        'actual': 'واقعیت',
        'done': 'تمام شد',
        'day': 'روز',
        'review': 'وضعیت',
        r'$record': 'حذف یا ویرایش',
      }[field] ??
      field;
  String _display(dynamic value) =>
      value is Map && value.containsKey('expression')
      ? '${money(value['value'])}${value['expression'] == null ? '' : ' ← ${value['expression']}'}'
      : value == null
      ? 'خالی / حذف‌شده'
      : value is num
      ? money(value)
      : value is bool
      ? (value ? 'بله' : 'خیر')
      : value is Map
      ? '${value['title'] ?? ''} · ${money(value['actual'])}'
      : '$value';
}

class _SpreadsheetSetup extends StatefulWidget {
  final FinanceController controller;
  const _SpreadsheetSetup({required this.controller});
  @override
  State<_SpreadsheetSetup> createState() => _SpreadsheetSetupState();
}

class _SpreadsheetSetupState extends State<_SpreadsheetSetup> {
  late final input = TextEditingController(
    text: widget.controller.spreadsheetId,
  );
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        controller: input,
        textDirection: TextDirection.ltr,
        readOnly: widget.controller.base.isNotEmpty,
        decoration: const InputDecoration(
          labelText: 'شناسه یا لینک شیت شخصی',
          hintText: 'docs.google.com/spreadsheets/d/…',
        ),
        style: const TextStyle(fontSize: 11),
      ),
      const SizedBox(height: 8),
      const Text(
        'این شناسه فقط روی دستگاهت ذخیره می‌شود.',
        style: TextStyle(fontSize: 11, color: muted),
      ),
      if (widget.controller.base.isEmpty)
        TextButton.icon(
          onPressed: () async {
            final text = input.text.trim();
            final id =
                RegExp(
                  r'/spreadsheets/d/([a-zA-Z0-9_-]+)',
                ).firstMatch(text)?.group(1) ??
                text;
            if (!RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(id)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('شناسه یا لینک معتبر شیت وارد کنید.'),
                ),
              );
              return;
            }
            await runAction(
              context,
              () => widget.controller.change(
                () => widget.controller.spreadsheetId = id,
              ),
              success: 'شناسهٔ شیت روی دستگاه ذخیره شد.',
            );
          },
          icon: const Icon(Icons.check, size: 18),
          label: const Text('ذخیرهٔ شناسه'),
        ),
    ],
  );
}
