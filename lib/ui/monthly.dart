import 'package:flutter/material.dart';
import '../data/controller.dart';
import '../domain/finance.dart';
import 'theme.dart';
import 'entry_form.dart';
import 'reports.dart';

class MonthlyPage extends StatefulWidget {
  final FinanceController controller;
  const MonthlyPage({super.key, required this.controller});
  @override
  State<MonthlyPage> createState() => _MonthlyPageState();
}

class _MonthlyPageState extends State<MonthlyPage> {
  Kind selected = Kind.fixed;
  FinanceController get c => widget.controller;
  @override
  Widget build(BuildContext context) {
    final s = c.summary,
        rows = openFirst(c.entries.where((e) => e.kind == selected)),
        summary = FinancialSummary(rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'یک ماه، با خیال جمع',
          caption: 'برنامهٔ پولت را بنویس؛ باقی‌اش روشن می‌شود.',
          trailing: IconButton(
            tooltip: 'مرور پایان ماه',
            onPressed: () => showForm(context, ReviewPage(controller: c)),
            icon: const Icon(Icons.fact_check_outlined, color: muted),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => showForm(context, SummarySheet(controller: c)),
          child: Panel(
            gradient: const LinearGradient(
              colors: [Color(0xffeee1ff), Color(0xffffe7f0), Color(0xfffff2e8)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            padding: const EdgeInsets.all(26),
            child: Stack(
              children: [
                Positioned(
                  left: -10,
                  top: -26,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 125,
                    color: Colors.white.withValues(alpha: .4),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'ماندهٔ پایان ماه',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.north_west_rounded,
                          size: 19,
                          color: purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Amount(s.end, compact: true, color: purple, size: 34),
                        const Text(
                          'تومان',
                          style: TextStyle(
                            color: purple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'موجودی محاسباتی فعلی',
                                style: TextStyle(color: muted, fontSize: 10),
                              ),
                              const SizedBox(height: 5),
                              Amount(s.current, compact: true, size: 14),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 32, color: Colors.white),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'پرداخت‌های باقی‌مانده',
                                style: TextStyle(color: muted, fontSize: 10),
                              ),
                              const SizedBox(height: 5),
                              Amount(s.remaining, compact: true, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, box) => Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: lavender.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: Kind.values
                  .map(
                    (k) => Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () => setState(() => selected = k),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            vertical: 13,
                            horizontal: 2,
                          ),
                          decoration: BoxDecoration(
                            color: selected == k ? Colors.white : null,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: selected == k
                                ? [
                                    BoxShadow(
                                      color: purple.withValues(alpha: .07),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            k.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: box.maxWidth < 380 ? 10 : 12,
                              fontWeight: FontWeight.w700,
                              color: selected == k ? purple : muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                selected.label,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tag('${persian(rows.length)} مورد'),
            TextButton.icon(
              onPressed: () =>
                  showForm(context, EntryForm(controller: c, kind: selected)),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('افزودن'),
            ),
          ],
        ),
        Panel(
          color: const Color(0xfff2ebfb),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _total(
                'انتظار',
                selected == Kind.income
                    ? summary.expectedIncome
                    : summary.expectedOut,
              ),
              _total(
                'واقعیت',
                selected == Kind.income
                    ? summary.actualIncome
                    : summary.actualOut,
              ),
              if (selected != Kind.income)
                _total('باقی‌مانده', summary.remaining),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Panel(
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Icon(
                  Icons.edit_calendar_outlined,
                  size: 40,
                  color: purple,
                ),
                const SizedBox(height: 12),
                Text(
                  'هنوز ${selected.singular}ی ثبت نشده',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'اولین مورد را ثبت کن یا اطلاعات شیت را دریافت کن.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => showForm(
                    context,
                    EntryForm(controller: c, kind: selected),
                  ),
                  child: const Text('ثبت اولین مورد'),
                ),
              ],
            ),
          )
        else
          ...rows.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: InkWell(
                onTap: () =>
                    showForm(context, EntryForm(controller: c, entry: e)),
                borderRadius: BorderRadius.circular(20),
                child: Panel(
                  key: ValueKey('entry-${e.id}'),
                  color: e.done ? const Color(0xfff2eef7) : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 5,
                                  children: [
                                    Container(
                                      padding: e.review == Review.failed
                                          ? const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            )
                                          : EdgeInsets.zero,
                                      decoration: BoxDecoration(
                                        color: e.review == Review.failed
                                            ? peach
                                            : null,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        e.title,
                                        style: TextStyle(
                                          color: e.done ? muted : ink,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (e.done)
                                      const Tag(
                                        'تمام شد',
                                        color: Color(0xffe7dff1),
                                      ),
                                    if (e.repeat)
                                      const Icon(
                                        Icons.repeat_rounded,
                                        color: muted,
                                        size: 14,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    if (e.effectiveDay != null)
                                      'روز ${persian(Month.key(e.month).validDay(e.effectiveDay!))}',
                                    if (e.effectiveDay != null &&
                                        e.effectiveDay! >
                                            Month.key(e.month).days)
                                      'منتقل از روز ${persian(e.effectiveDay!)}',
                                    if (e.review != Review.planned)
                                      [
                                        '',
                                        'شکست خورد',
                                        'منصرف شدیم',
                                        'ماه بعد',
                                      ][e.review.index],
                                    if (e.carryProvisional)
                                      'ماندهٔ موقت؛ قابل ویرایش',
                                    if (e.purchaseId != null)
                                      'قسط مرتبط با خرید',
                                  ].join(' · '),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (e.kind != Kind.income)
                            Checkbox(
                              value: e.done,
                              onChanged: (v) => runAction(
                                context,
                                () => c.saveEntry(e.copy()..done = v!),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _metric('انتظار', e.expected)),
                          Expanded(child: _metric('واقعیت', e.actual)),
                          if (e.kind != Kind.income)
                            Expanded(
                              child: _metric(
                                'باقی‌مانده',
                                e.remaining,
                                accent: true,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        GradientButton(
          'افزودن ${selected.singular}',
          icon: Icons.add_rounded,
          onPressed: () =>
              showForm(context, EntryForm(controller: c, kind: selected)),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _total(String label, double value) => Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 10)),
        const SizedBox(height: 4),
        Amount(
          value,
          compact: true,
          size: 13,
          color: label == 'باقی‌مانده' ? purple : ink,
        ),
      ],
    ),
  );
  Widget _metric(String label, double? value, {bool accent = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: muted, fontSize: 10)),
      const SizedBox(height: 3),
      Amount(value, compact: true, size: 13, color: accent ? purple : ink),
    ],
  );
}

class ReviewPage extends StatelessWidget {
  final FinanceController controller;
  const ReviewPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final rows = controller.entries
        .where((e) => e.kind != Kind.income && !e.done && e.remaining > 0)
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'مرور پایان ماه',
            caption: Month.key(controller.selectedMonth).label,
          ),
          const Text(
            'وضعیت موارد باز را مشخص کن. مبالغ آزادشده خودکار پس‌انداز نمی‌شوند.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 20),
          if (rows.isEmpty)
            const Panel(child: Text('همهٔ موارد تعیین تکلیف شده‌اند.')),
          ...rows.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('باقی‌مانده: ${money(e.remaining)} تومان'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final status in Review.values)
                          ActionChip(
                            label: Text(
                              [
                                'هنوز در برنامه است',
                                'شکست خورد',
                                'منصرف شدیم',
                                'ماه بعد',
                              ][status.index],
                            ),
                            backgroundColor: status == Review.failed
                                ? peach
                                : lavender,
                            onPressed: () async {
                              await runAction(
                                context,
                                () => controller.reviewEntry(e, status),
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                showForm(
                                  context,
                                  ReviewPage(controller: controller),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن مرور'),
          ),
        ],
      ),
    );
  }
}
