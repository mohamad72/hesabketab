import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../domain/finance.dart';
import 'theme.dart';

class AccountsPage extends StatefulWidget {
  final FinanceController controller;
  const AccountsPage({super.key, required this.controller});
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final inputs = <String, TextEditingController>{};
  FinanceController get c => widget.controller;
  @override
  void dispose() {
    for (final input in inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = c.accounts;
    final total = rows.fold<double>(
      0,
      (s, a) =>
          s +
          (parseMoney(inputs[a['id']]?.text ?? '') ??
              (a['balance'] as num).toDouble()),
    );
    final daily = c.entries.where((e) => e.isDaily).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'موجودی حساب‌ها',
          caption: 'همهٔ حساب‌ها، یک تصویر روشن',
        ),
        Panel(
          gradient: const LinearGradient(
            colors: [Color(0xffeae0fc), Color(0xffffe9f0)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('جمع موجودی بانکی', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Amount(total, compact: true, size: 31, color: purple),
                  const Text('تومان', style: TextStyle(color: purple)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'این عدد مستقل از موجودی محاسباتی ماه است.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        ...rows.map((a) {
          final id = a['id'] as String;
          final input = inputs.putIfAbsent(id, () => TextEditingController());
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a['title'],
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Tag(
                        a['owner'],
                        color: a['owner'] == 'محمد' ? peach : lavender,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey(id),
                    controller: input,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'موجودی جدید (تومان)',
                      hintText: money(a['balance']),
                      helperText: 'موجودی فعلی: ${money(a['balance'])} تومان',
                      suffixIcon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    validator: (v) => v!.isNotEmpty && parseMoney(v) == null
                        ? 'مبلغ معتبر وارد کنید'
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
        if (rows.isEmpty)
          const Panel(
            child: Text('حساب‌ها را از شیت دریافت کن یا حساب جدید اضافه کن.'),
          ),
        const SizedBox(height: 14),
        Panel(
          color: peach,
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 19,
                color: Color(0xffc78253),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختلاف ثبت‌نشده، خودکار خوردوخوراک می‌شود.',
                      style: TextStyle(fontSize: 12),
                    ),
                    if (daily?.actual != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${money(daily!.actual)} تومان${daily.actual! < 0 ? ' · اختلاف منفی است؛ نیاز به بررسی دارد.' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: daily.actual! < 0 ? Colors.red : muted,
                        ),
                      ),
                    ],
                    if (daily == null)
                      const Text(
                        'برای محاسبه، ردیف «غذا و حمل و نقل و امور جاری» را در هزینه‌های ثابت ثبت کن.',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GradientButton(
          'ذخیرهٔ موجودی‌ها',
          icon: Icons.check_rounded,
          onPressed: rows.isEmpty
              ? null
              : () async {
                  if (inputs.values.any(
                    (i) =>
                        i.text.trim().isNotEmpty && parseMoney(i.text) == null,
                  )) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('مبالغ نامعتبر را اصلاح کنید.'),
                      ),
                    );
                    return;
                  }
                  await runAction(
                    context,
                    () => c.saveBalances({
                      for (final a in rows)
                        a['id']: parseMoney(inputs[a['id']]?.text ?? ''),
                    }),
                    success: 'موجودی‌ها روی دستگاه ذخیره شدند.',
                  );
                  for (final i in inputs.values) {
                    i.clear();
                  }
                  if (mounted) setState(() {});
                },
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => showForm(context, _AddAccount(controller: c)),
          icon: const Icon(Icons.add),
          label: const Text('افزودن حساب'),
        ),
      ],
    );
  }
}

class _AddAccount extends StatefulWidget {
  final FinanceController controller;
  const _AddAccount({required this.controller});
  @override
  State<_AddAccount> createState() => _AddAccountState();
}

class _AddAccountState extends State<_AddAccount> {
  final title = TextEditingController(), amount = TextEditingController();
  String owner = 'سارا';
  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('افزودن حساب'),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'نام حساب'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: owner,
          items: [
            'سارا',
            'محمد',
            'سایر',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => owner = v!,
          decoration: const InputDecoration(labelText: 'مالک'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'موجودی (تومان)'),
        ),
        const SizedBox(height: 20),
        GradientButton(
          'افزودن حساب',
          onPressed: () async {
            if (title.text.trim().isEmpty || parseMoney(amount.text) == null) {
              return;
            }
            await runAction(
              context,
              () => widget.controller.addAccount(
                title.text.trim(),
                owner,
                parseMoney(amount.text)!,
              ),
            );
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}
