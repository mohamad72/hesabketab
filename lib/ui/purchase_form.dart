import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../domain/finance.dart';
import 'theme.dart';

class PurchaseForm extends StatefulWidget {
  final FinanceController controller;
  const PurchaseForm({super.key, required this.controller});
  @override
  State<PurchaseForm> createState() => _PurchaseFormState();
}

class _PurchaseFormState extends State<PurchaseForm> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      total = TextEditingController(),
      actual = TextEditingController();
  final amounts = List.generate(4, (_) => TextEditingController()),
      days = List.generate(4, (_) => TextEditingController());
  late List<String> months;
  Kind kind = Kind.special;
  String provider = '';
  bool saving = false;
  @override
  void initState() {
    super.initState();
    var m = Month.key(widget.controller.selectedMonth);
    months = List.generate(4, (_) {
      final key = m.key;
      m = m.next;
      return key;
    });
  }

  @override
  void dispose() {
    for (final c in [title, total, actual, ...amounts, ...days]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'خرید قسطی',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Text(
            'یک خرید، چهار سررسید روشن',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: title,
            decoration: const InputDecoration(labelText: 'عنوان کالا'),
            validator: (s) =>
                s!.trim().isEmpty ? 'عنوان کالا را وارد کنید' : null,
          ),
          const SizedBox(height: 16),
          Autocomplete<String>(
            optionsBuilder: (v) =>
                widget.controller.providers.where((p) => p.contains(v.text)),
            onSelected: (s) => provider = s,
            fieldViewBuilder: (context, c, f, submit) => TextFormField(
              controller: c,
              focusNode: f,
              decoration: const InputDecoration(
                labelText: 'ارائه‌دهندهٔ پرداخت',
                hintText: 'تایپ نام دلخواه، مثل اسنپ‌پی',
              ),
              onChanged: (s) => provider = s,
              validator: (s) =>
                  s!.trim().isEmpty ? 'نام ارائه‌دهنده را وارد کنید' : null,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: total,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'مبلغ کل کالا (تومان)',
            ),
            validator: (s) =>
                (parseMoney(s ?? '') ?? 0) <= 0 ? 'مبلغ مثبت وارد کنید' : null,
          ),
          TextButton(
            onPressed: () {
              final t = parseMoney(total.text);
              if (t != null) {
                for (final a in amounts) {
                  a.text = money(t / 4);
                }
                setState(() {});
              }
            },
            child: const Text('تقسیم مساوی مبلغ برای ویرایش اولیه'),
          ),
          DropdownButtonFormField<Kind>(
            initialValue: kind,
            decoration: const InputDecoration(labelText: 'محل ثبت قسط اول'),
            items: [Kind.fixed, Kind.special, Kind.saving]
                .map((k) => DropdownMenuItem(value: k, child: Text(k.label)))
                .toList(),
            onChanged: (v) => setState(() => kind = v!),
          ),
          const SizedBox(height: 12),
          const Text(
            'مبلغ و تاریخ هر قسط را جداگانه بررسی کن.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Panel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'قسط ${persian(i + 1)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Tag(i == 0 ? 'زیر خود کالا' : 'هزینه‌های ثابت'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: amounts[i],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'انتظار (تومان)',
                            ),
                            validator: (s) => (parseMoney(s ?? '') ?? -1) < 0
                                ? 'مبلغ معتبر وارد کنید'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 90,
                          child: TextFormField(
                            controller: days[i],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'روز'),
                            validator: (s) {
                              final d = int.tryParse(latin(s ?? ''));
                              return d == null || d < 1 || d > 31
                                  ? '۱ تا ۳۱'
                                  : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final m = await pickMonth(
                          context,
                          Month.key(months[i]),
                        );
                        if (m != null) setState(() => months[i] = m.key);
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(Month.key(months[i]).label),
                    ),
                    if (int.tryParse(latin(days[i].text)) == 31 &&
                        Month.key(months[i]).days < 31)
                      const Text(
                        'در این ماه به آخرین روز معتبر منتقل می‌شود.',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: actual,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'واقعیت قسط اول (تومان، اختیاری)',
            ),
            validator: (s) => s!.isNotEmpty && parseMoney(s) == null
                ? 'مبلغ معتبر وارد کنید'
                : null,
          ),
          const SizedBox(height: 24),
          GradientButton(
            'ثبت خرید و چهار قسط',
            icon: Icons.arrow_back_rounded,
            onPressed: saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final sum = amounts.fold<double>(
                      0,
                      (s, a) => s + parseMoney(a.text)!,
                    );
                    if ((sum - parseMoney(total.text)!).abs() > .001) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'جمع چهار قسط باید برابر مبلغ کل باشد.',
                          ),
                        ),
                      );
                      return;
                    }
                    for (var i = 1; i < 4; i++) {
                      if (months[i].compareTo(months[i - 1]) < 0 ||
                          (months[i] == months[i - 1] &&
                              int.parse(latin(days[i].text)) <
                                  int.parse(latin(days[i - 1].text)))) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('سررسید اقساط باید به ترتیب باشد.'),
                          ),
                        );
                        return;
                      }
                    }
                    setState(() => saving = true);
                    try {
                      await widget.controller.addPurchase(
                        title: title.text.trim(),
                        provider: provider.trim(),
                        kind: kind,
                        total: parseMoney(total.text)!,
                        firstActual: parseMoney(actual.text),
                        schedule: List.generate(
                          4,
                          (i) => {
                            'month': months[i],
                            'day': int.parse(latin(days[i].text)),
                            'amount': parseMoney(amounts[i].text)!,
                          },
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) setState(() => saving = false);
                    }
                  },
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}
