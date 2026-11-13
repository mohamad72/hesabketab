import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../domain/finance.dart';
import 'theme.dart';

class EntryForm extends StatefulWidget {
  final FinanceController controller;
  final Entry? entry;
  final Kind kind;
  const EntryForm({
    super.key,
    required this.controller,
    this.entry,
    this.kind = Kind.fixed,
  });
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final form = GlobalKey<FormState>();
  late Entry entry;
  late TextEditingController title, expected, actual, day;
  bool saving = false, endChosen = false;
  @override
  void initState() {
    super.initState();
    entry =
        widget.entry?.copy() ??
        Entry(
          id: newId(),
          month: widget.controller.selectedMonth,
          kind: widget.kind,
          title: '',
        );
    title = TextEditingController(text: entry.title);
    expected = TextEditingController(text: money(entry.expected));
    actual = TextEditingController(
      text: entry.actual == null ? '' : money(entry.actual),
    );
    day = TextEditingController(
      text: entry.effectiveDay == null ? '' : persian(entry.effectiveDay!),
    );
    endChosen = entry.repeat;
  }

  @override
  void dispose() {
    for (final c in [title, expected, actual, day]) {
      c.dispose();
    }
    super.dispose();
  }

  bool locked(String field) =>
      widget.controller.bindings[entry.id]?['formulas']?[field] != null;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.entry == null ? 'ثبت مورد جدید' : 'ویرایش مورد',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final m = await pickMonth(context, Month.key(entry.month));
              if (m != null) setState(() => entry.month = m.key);
            },
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(Month.key(entry.month).label),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: Kind.values
                .map(
                  (k) => ChoiceChip(
                    label: Text(k.singular),
                    selected: entry.kind == k,
                    onSelected: (_) => setState(() => entry.kind = k),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: title,
            decoration: const InputDecoration(labelText: 'عنوان'),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'عنوان را وارد کنید' : null,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _amount(
                  expected,
                  'انتظار (تومان)',
                  locked('expected'),
                  required: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _amount(
                  actual,
                  'واقعیت (تومان)',
                  locked('actual') || entry.isDaily,
                ),
              ),
            ],
          ),
          if (locked('actual') || locked('expected'))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'مبلغ فرمول‌دار در شیت ویرایش می‌شود؛ فرمول حفظ می‌شود.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: day,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'روز ماه',
              hintText: 'برای حقوق، در صورت خالی‌بودن: ۱۰',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final n = int.tryParse(latin(v));
              return n == null || n < 1 || n > 31
                  ? 'روزی از ۱ تا ۳۱ وارد کنید'
                  : null;
            },
          ),
          if (entry.kind != Kind.income) ...[
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: entry.done,
              onChanged: (v) => setState(() => entry.done = v!),
              title: const Text(
                'تمام شد؛ دیگر برای این مورد خرج نمی‌کنم',
                style: TextStyle(fontSize: 12),
              ),
            ),
            Panel(
              color: lavender,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(child: Text('باقی‌ماندهٔ این مورد')),
                  Amount(
                    entry.done
                        ? 0
                        : ((parseMoney(expected.text) ?? 0) -
                                  (parseMoney(actual.text) ?? 0))
                              .clamp(0, double.infinity),
                    color: purple,
                  ),
                ],
              ),
            ),
          ],
          if (entry.purchaseId == null) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تکرار در ماه‌های بعد'),
              subtitle: const Text(
                'مبلغ انتظار منتقل می‌شود، واقعیت منتقل نمی‌شود',
                style: TextStyle(fontSize: 11),
              ),
              value: entry.repeat,
              onChanged: (v) => setState(() {
                entry.repeat = v;
                if (v) endChosen = false;
              }),
            ),
            if (entry.repeat) ...[
              Text(
                'شروع: ${Month.key(entry.month).label}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final m = await pickMonth(
                    context,
                    Month.key(entry.repeatEnd ?? entry.month),
                  );
                  if (m != null) {
                    setState(() {
                      entry.repeatEnd = m.key;
                      endChosen = true;
                    });
                  }
                },
                icon: const Icon(Icons.event_repeat),
                label: Text(
                  endChosen && entry.repeatEnd != null
                      ? 'پایان: ${Month.key(entry.repeatEnd!).label}'
                      : 'انتخاب ماه پایان تکرار',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('بدون پایان', style: TextStyle(fontSize: 13)),
                value: endChosen && entry.repeatEnd == null,
                onChanged: (v) => setState(() {
                  endChosen = v!;
                  entry.repeatEnd = null;
                }),
              ),
            ],
          ],
          const SizedBox(height: 20),
          GradientButton(
            saving ? 'در حال ذخیره…' : 'ذخیرهٔ تغییرات',
            icon: Icons.check_rounded,
            onPressed: saving ? null : save,
          ),
          if (widget.entry != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                await runAction(
                  context,
                  () => widget.controller.deleteEntry(entry),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text(
                'حذف این مورد',
                style: TextStyle(color: Color(0xffc15a77)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'روی دستگاه ذخیره می‌شود؛ ارسال به شیت هنگام همگام‌سازی',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    ),
  );
  Widget _amount(
    TextEditingController c,
    String label,
    bool readOnly, {
    bool required = false,
  }) => TextFormField(
    controller: c,
    readOnly: readOnly,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      labelText: label,
      hintText: required ? null : 'خالی با صفر متفاوت است',
    ),
    onChanged: (_) => setState(() {}),
    validator: (v) {
      if ((v ?? '').isEmpty && !required) return null;
      return parseMoney(v ?? '') == null ? 'مبلغ معتبر وارد کنید' : null;
    },
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (entry.repeat &&
        (!endChosen ||
            day.text.trim().isEmpty && !title.text.contains('حقوق'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'روز وقوع و ماه پایان تکرار یا «بدون پایان» را مشخص کنید.',
          ),
        ),
      );
      return;
    }
    if (entry.repeat &&
        entry.repeatEnd != null &&
        entry.repeatEnd!.compareTo(entry.month) < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ماه پایان نباید پیش از ماه شروع باشد.')),
      );
      return;
    }
    entry.title = title.text.trim();
    entry.expected = parseMoney(expected.text)!;
    entry.actual = parseMoney(actual.text);
    entry.day = int.tryParse(latin(day.text));
    if (entry.kind == Kind.income) entry.done = false;
    if (entry.title == 'مانده از ماه قبل') entry.carryManual = true;
    setState(() => saving = true);
    try {
      await widget.controller.saveEntry(entry);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
