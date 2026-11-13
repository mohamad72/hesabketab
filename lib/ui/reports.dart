import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../data/controller.dart';
import '../domain/finance.dart';
import 'theme.dart';
import 'entry_form.dart';

class ReportsPage extends StatefulWidget {
  final FinanceController controller;
  const ReportsPage({super.key, required this.controller});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int? selectedPoint;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller,
        m = Month.key(c.selectedMonth),
        now = Jalali.now(),
        isCurrent = now.year == m.year && now.month == m.number;
    final day = isCurrent ? now.day : 1;
    final daily = c.entries.where((e) => e.isDaily).firstOrNull;
    final points = forecast(
      c.entities.values
          .where((e) => e['type'] == 'entry')
          .map(Entry.fromJson)
          .where((e) => !e.isDaily),
      month: m.key,
      startDay: day,
      balance: c.summary.current,
      dailyEstimate: daily == null ? 0 : daily.remaining / max(1, m.days - day),
    );
    final low = points.reduce((a, b) => a.balance < b.balance ? a : b),
        selected = points[(selectedPoint ?? 0).clamp(0, points.length - 1)];
    final monthKeys = c.months
        .where((k) => k.compareTo(c.selectedMonth) <= 0)
        .toList();
    final shown = monthKeys.skip(max(0, monthKeys.length - 6)).toList();
    final savings = shown.map((key) {
      final es = c.entriesFor(key).where((e) => e.kind == Kind.saving);
      return (
        Month.key(key),
        es.fold<double>(0, (s, e) => s + e.expected),
        es.fold<double>(0, (s, e) => s + (e.actual ?? 0)),
      );
    }).toList();
    final unscheduled = c.entries
        .where(
          (e) =>
              e.effectiveDay == null &&
              (e.kind == Kind.income ? e.actual == null : e.remaining > 0) &&
              !e.isDaily,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'پول تو، در یک نگاه',
          caption: 'گزارش‌ها با آخرین اطلاعات روی دستگاه محاسبه می‌شوند.',
        ),
        Row(
          children: [
            Expanded(
              child: Panel(
                color: lavender,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'پس‌انداز ثبت‌شده',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    Amount(
                      c.entries
                          .where((e) => e.kind == Kind.saving)
                          .fold<double>(0, (s, e) => s + (e.actual ?? 0)),
                      compact: true,
                      color: purple,
                      size: 23,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Panel(
                color: const Color(0xffffe9f0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'پایان ماه، برآورد',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    Amount(
                      c.summary.end,
                      compact: true,
                      color: const Color(0xffcd619c),
                      size: 23,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'آیندهٔ موجودی',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
              ),
              const SizedBox(height: 4),
              Text(
                'مبنا: موجودی محاسباتی ${money(c.summary.current)} تومان · روز ${persian(day)}',
                style: const TextStyle(fontSize: 10, color: muted),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, box) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => setState(
                    () => selectedPoint =
                        ((d.localPosition.dx - 42) /
                                (box.maxWidth - 54) *
                                (points.length - 1))
                            .round()
                            .clamp(0, points.length - 1),
                  ),
                  child: Semantics(
                    label:
                        'نمودار پیش‌بینی موجودی؛ کمترین مقدار ${money(low.balance)} تومان در روز ${persian(low.day)}',
                    child: SizedBox(
                      height: 205,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: ForecastPainter(points, selectedPoint),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'روز ${persian(selected.day)} · ${money(selected.balance)} تومان${selected.events.isEmpty ? '' : ' · ${selected.events.join('، ')}'}',
                style: const TextStyle(fontSize: 11, color: purple),
              ),
              const SizedBox(height: 10),
              Tag(
                'کمترین موجودی: ${money(low.balance, compact: true)} · ${persian(low.day)} ${monthNames[m.number - 1]}',
                color: const Color(0xffffe7f1),
              ),
              if (unscheduled.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${persian(unscheduled.length)} مورد بدون روز وقوع در نمودار زمان‌بندی نشده‌اند؛ در خلاصهٔ ماه لحاظ می‌شوند.',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'پس‌انداز ماهانه',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Tag('انتظار'),
                  const SizedBox(width: 6),
                  const Tag('واقعیت', color: Color(0xffffd9ed)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 170,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: savings.map((s) {
                    final maxValue = max(
                      1.0,
                      savings.fold<double>(
                        0,
                        (v, s) => max(v, max(s.$2, s.$3)),
                      ),
                    );
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message:
                                'انتظار: ${money(s.$2)}، واقعیت: ${money(s.$3)} تومان',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 14,
                                  height: max(2, s.$2 / maxValue * 115),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffc5a1f6),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 14,
                                  height: max(2, s.$3 / maxValue * 115),
                                  decoration: BoxDecoration(
                                    color: const Color(0xfff4a2cb),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            monthNames[s.$1.number - 1],
                            style: const TextStyle(fontSize: 10, color: muted),
                          ),
                          Text(
                            s.$1.key == Month.now().key ? 'تا امروز' : '',
                            style: const TextStyle(fontSize: 9, color: purple),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
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
                'فشار اقساط آینده',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              ...List.generate(3, (i) {
                var next = m;
                for (var n = 0; n <= i; n++) {
                  next = next.next;
                }
                final es = c
                    .entriesFor(next.key)
                    .where((e) => e.purchaseId != null);
                final sum = es.fold<double>(0, (s, e) => s + e.remaining);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          next.label,
                          style: const TextStyle(color: muted),
                        ),
                      ),
                      Amount(sum, compact: true, color: purple),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => showForm(context, SummarySheet(controller: c)),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('خلاصهٔ مالی ماه و جزئیات محاسبه'),
        ),
        const SizedBox(height: 12),
        if (c.entities.values.any((e) => e['type'] == 'purchase')) ...[
          const SectionTitle('خریدها و اقساط مرتبط'),
          ...c.entities.values.where((e) => e['type'] == 'purchase').map((p) {
            final es =
                c.entities.values
                    .where(
                      (e) => e['type'] == 'entry' && e['purchaseId'] == p['id'],
                    )
                    .map(Entry.fromJson)
                    .toList()
                  ..sort((a, b) => a.month.compareTo(b.month));
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p['title']} · ${p['provider']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    ...es.map(
                      (e) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          '${Month.key(e.month).label} · روز ${persian(Month.key(e.month).validDay(e.effectiveDay ?? 1))}',
                        ),
                        subtitle: Text(
                          '${money(e.actual)} پرداخت‌شده · ${money(e.remaining)} مانده',
                        ),
                        trailing: Icon(
                          e.done || e.remaining == 0
                              ? Icons.check_circle_outline
                              : Icons.chevron_left,
                          color: purple,
                        ),
                        onTap: () => showForm(
                          context,
                          EntryForm(controller: c, entry: e),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class SummarySheet extends StatelessWidget {
  final FinanceController controller;
  const SummarySheet({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'خلاصهٔ مالی ماه',
          caption: Month.key(controller.selectedMonth).label,
        ),
        const Text(
          'همان محاسبات شیت، یک‌جا · همهٔ مبالغ به تومان',
          style: TextStyle(color: muted, fontSize: 11),
        ),
        const SizedBox(height: 16),
        ...controller.summary.metrics.entries.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              color: m.key == 'ماندهٔ پایان ماه' ? lavender : null,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(m.key, style: const TextStyle(fontSize: 12)),
                  ),
                  Amount(
                    m.value,
                    compact: true,
                    color: m.key == 'ماندهٔ پایان ماه' ? purple : ink,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'درآمد مبنا − خروجی واقعی − پرداخت‌های باقی‌مانده = ماندهٔ پایان ماه',
          style: TextStyle(fontSize: 12, color: purple),
        ),
        const SizedBox(height: 16),
        ...controller.entries
            .where((e) => e.remaining > 0 || e.kind == Kind.income)
            .map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.title, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  e.kind == Kind.income
                      ? 'درآمد مبنا: ${money(e.actual ?? e.expected)} تومان'
                      : 'تعهد باقی‌مانده: ${money(e.remaining)} تومان',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => showForm(
                  context,
                  EntryForm(controller: controller, entry: e),
                ),
              ),
            ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('بستن'),
        ),
      ],
    ),
  );
}

class ForecastPainter extends CustomPainter {
  final List<ForecastPoint> points;
  final int? selected;
  ForecastPainter(this.points, this.selected);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const left = 46.0, right = 10.0, top = 14.0, bottom = 28.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    var minY = points.map((p) => p.balance).reduce(min),
        maxY = points.map((p) => p.balance).reduce(max);
    final pad = max(1000000.0, (maxY - minY) * .2);
    minY -= pad;
    maxY += pad;
    double x(int i) =>
        plot.left +
        (points.length == 1 ? 0 : i / (points.length - 1) * plot.width);
    double y(double value) =>
        plot.bottom - (value - minY) / (maxY - minY) * plot.height;
    void label(String text, Offset offset, {Color color = muted}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 9, color: color),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      painter.paint(canvas, offset);
    }

    for (var i = 0; i <= 4; i++) {
      final yy = plot.top + plot.height / 4 * i;
      canvas.drawLine(
        Offset(plot.left, yy),
        Offset(plot.right, yy),
        Paint()
          ..color = lavender
          ..strokeWidth = 1,
      );
      label(
        persian(((maxY - (maxY - minY) / 4 * i) / 1000000).toStringAsFixed(0)),
        Offset(0, yy - 6),
      );
    }
    label('میلیون', const Offset(0, 0));
    final path = Path()..moveTo(x(0), y(points.first.balance));
    for (var i = 1; i < points.length; i++) {
      path.lineTo(x(i), y(points[i].balance));
    }
    final fill = Path.from(path)
      ..lineTo(x(points.length - 1), plot.bottom)
      ..lineTo(x(0), plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x44873cff), Color(0x03873cff)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(plot),
    );
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(
          metric.extractPath(d, min(d + 6, metric.length)),
          Paint()
            ..color = purple
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.drawLine(
      Offset(x(0), plot.top),
      Offset(x(0), plot.bottom),
      Paint()
        ..color = purple.withValues(alpha: .4)
        ..strokeWidth = 1,
    );
    label('مبنا', Offset(x(0) + 4, plot.top), color: purple);
    final indices = {
      0,
      points.length ~/ 3,
      points.length * 2 ~/ 3,
      points.length - 1,
    };
    for (final i in indices) {
      label(persian(points[i].day), Offset(x(i) - 5, plot.bottom + 10));
    }
    final chosen = (selected ?? 0).clamp(0, points.length - 1);
    canvas.drawCircle(
      Offset(x(chosen), y(points[chosen].balance)),
      5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(x(chosen), y(points[chosen].balance)),
      3.5,
      Paint()..color = purple,
    );
  }

  @override
  bool shouldRepaint(covariant ForecastPainter oldDelegate) => true;
}
